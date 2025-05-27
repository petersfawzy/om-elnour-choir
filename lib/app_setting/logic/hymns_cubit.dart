// [V0_FILE]typescriptreact:file="lib/app_setting/logic/hymns_cubit.dart" isEdit isQuickEdit
import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:om_elnour_choir/app_setting/logic/hymn_repository.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:om_elnour_choir/services/cache_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as Math;

class HymnsCubit extends Cubit<List<HymnsModel>> {
  final HymnsRepository _hymnsRepository;
  final MyAudioService _audioService;
  final CacheService _cacheService = CacheService();
  MyAudioService get audioService => _audioService;

  // Filter variables
  String _sortBy = 'dateAdded';
  bool _descending = true;
  String? _filterCategory;
  String? _filterAlbum;

  // Getters for current filter state
  String get sortBy => _sortBy;
  bool get descending => _descending;
  String? get filterCategory => _filterCategory;
  String? get filterAlbum => _filterAlbum;

  HymnsModel? _currentHymn;
  List<HymnsModel> _favorites = [];
  List<HymnsModel> _allHymns = []; // Original hymns list
  List<HymnsModel> _filteredHymns = []; // Filtered hymns list

  // إضافة متغيرات لتتبع آخر ترنيمة تم زيادة عدد مشاهداتها
  String? _lastIncrementedHymnId;
  DateTime? _lastIncrementTime;
  bool _isIncrementingView = false;

  // Flag to prevent repeated playback of same hymn
  bool _isPlaybackInProgress = false;

  // Debounce timer for controlling delayed operations
  Timer? _debounceTimer;

  // Counter for recovery attempts
  int _recoveryAttempts = 0;

  // Timestamp of last error
  DateTime? _lastErrorTime;

  // Flag to track if favorites loading is in progress
  bool _isLoadingFavorites = false;

  // Map to temporarily store favorites locally
  final Map<String, bool> _favoriteCache = {};

  // Add playlist type tracking
  String _currentPlaylistType =
      'general'; // 'general', 'album', 'category', 'favorites'
  String? _currentPlaylistId; // ID of the album or category

  // دالات للحصول على والتحكم في سياق قائمة التشغيل
  String get currentPlaylistType => _currentPlaylistType;
  String? get currentPlaylistId => _currentPlaylistId;

  // دالة لتعيين نوع قائمة التشغيل الحالية
  void setCurrentPlaylistType(String type) {
    if (_currentPlaylistType != type) {
      print('📋 تغيير نوع قائمة التشغيل من $_currentPlaylistType إلى $type');
      _currentPlaylistType = type;
    }
  }

  // دالة لتعيين معرف قائمة التشغيل الحالية
  void setCurrentPlaylistId(String? id) {
    if (_currentPlaylistId != id) {
      print(
          '📋 تغيير معرف قائمة التشغيل من ${_currentPlaylistId ?? "null"} إلى ${id ?? "null"}');
      _currentPlaylistId = id;
    }
  }

  // تم إزالة دالة _handlePlaylistContext لأنها غير مطلوبة حالياً

  // Add call to preload popular hymns at app startup
  HymnsCubit(this._hymnsRepository, this._audioService) : super([]) {
    fetchHymns();
    _loadFilterPreferences();

    // Add listener for current title change
    _audioService.currentTitleNotifier.addListener(_onCurrentTitleChanged);

    // Load favorites at app startup
    loadFavorites();

    // Register callback for hymn changes in audio service
    // This is critical - we'll use this to control view increments
    _audioService.registerHymnChangedCallback(_onHymnChangedFromAudioService);

    // تم إزالة تسجيل callback سياق قائمة التشغيل لأنه غير مطلوب حالياً
    print('📋 تم تهيئة HymnsCubit بنجاح');
  }

  // تعديل دالة _onHymnChangedFromAudioService لتحسين تتبع زيادة عدد المشاهدات
  void _onHymnChangedFromAudioService(int index, String title) {
    print('🎵 تغيرت الترنيمة من خدمة الصوت: $title (فهرس: $index)');

    // منع زيادة عدد المشاهدات المتكررة في فترة زمنية قصيرة
    final now = DateTime.now();
    if (_lastIncrementedHymnId != null && _lastIncrementTime != null) {
      final difference = now.difference(_lastIncrementTime!);
      // منع زيادة عدد المشاهدات لنفس الترنيمة خلال 60 ثانية
      if (_lastIncrementedHymnId == title && difference.inSeconds < 60) {
        print(
            '⚠️ تم زيادة عدد المشاهدات لهذه الترنيمة مؤخرًا (قبل ${difference.inSeconds} ثانية)، تجاهل الطلب');
        return;
      }
    }

    // تحديث متغيرات التتبع قبل زيادة عدد المشاهدات
    _lastIncrementedHymnId = title;
    _lastIncrementTime = now;

    // البحث عن الترنيمة في القائمة
    final hymnIndex = _allHymns.indexWhere((h) => h.songName == title);

    if (hymnIndex >= 0) {
      final hymn = _allHymns[hymnIndex];
      // زيادة عدد المشاهدات
      incrementHymnViews(hymn.id);
      print('📊 تم زيادة عدد مشاهدات الترنيمة: ${hymn.songName}');
    }
  }

  // Function called when current title changes
  void _onCurrentTitleChanged() {
    if (_audioService.currentTitleNotifier.value != null) {
      // Find hymn in list
      final hymnTitle = _audioService.currentTitleNotifier.value!;
      final hymnIndex = _allHymns.indexWhere((h) => h.songName == hymnTitle);

      if (hymnIndex >= 0) {
        final hymn = _allHymns[hymnIndex];
        print('🔄 Current hymn changed to: ${hymn.songName}');
      }
    }
  }

  // تعديل دالة playHymn لتحسين التشغيل
  Future<void> playHymn(HymnsModel hymn, {bool incrementViews = true}) async {
    if (_isPlaybackInProgress) {
      print('⚠️ Playback operation already in progress, ignoring request');
      return;
    }

    _isPlaybackInProgress = true;

    try {
      print('🎵 Playing hymn: ${hymn.songName} (ID: ${hymn.id})');

      // Find hymn in list
      final index = state.indexWhere((h) => h.id == hymn.id);
      if (index == -1) {
        print('⚠️ Hymn not found in current list');
        _isPlaybackInProgress = false;
        return;
      }

      // Increment view count only if requested (default is true)
      if (incrementViews) {
        await incrementHymnViews(hymn.id);
        print('👁️ View count incremented for hymn: ${hymn.id}');
      } else {
        print('👁️ View count increment skipped as requested');
      }

      // إيقاف التشغيل الحالي تلقائيًا قبل بدء تشغيل الترنيمة الجديدة
      await _audioService.stop();

      // إضافة تأخير قصير للتأكد من توقف التشغيل تمامًا
      await Future.delayed(Duration(milliseconds: 200));

      // Set up playlist if needed
      List<String> urls = [];
      List<String> titles = [];
      List<String?> artworkUrls = [];

      // Use the current filtered hymns as the playlist
      final playlist = _filteredHymns;

      urls = playlist.map((h) => h.songUrl).toList();
      titles = playlist.map((h) => h.songName).toList();

      // جلب صور الألبومات بشكل محسن
      print('🖼️ جاري جلب صور الألبومات للترانيم...');
      artworkUrls = await _getArtworkUrlsForHymns(playlist);
      print('🖼️ تم جلب ${artworkUrls.length} صورة ألبوم');

      // طباعة تفاصيل الصور لكل ترنيمة
      for (int i = 0; i < playlist.length; i++) {
        final hymn = playlist[i];
        final artworkUrl = i < artworkUrls.length ? artworkUrls[i] : null;
        print(
            '🎵 [$i] ${hymn.songName} (ألبوم: ${hymn.songAlbum}) -> صورة: ${artworkUrl ?? "لا توجد"}');
      }

      // Set the playlist in the audio service
      await _audioService.setPlaylist(urls, titles, artworkUrls);

      // تحقق من أن الصور تم تمريرها بشكل صحيح
      print('🔍 التحقق من تمرير الصور إلى AudioService:');
      print('   - عدد URLs: ${urls.length}');
      print('   - عدد Titles: ${titles.length}');
      print('   - عدد ArtworkUrls: ${artworkUrls.length}');
      for (int i = 0; i < Math.min(3, artworkUrls.length); i++) {
        print('   [$i] ${titles[i]} -> ${artworkUrls[i] ?? "لا توجد صورة"}');
      }

      // Play the hymn directly
      await _audioService.play(index, hymn.songName);

      print('✅ Hymn playback started successfully');
    } catch (e) {
      print('❌ General error playing hymn: $e');
    } finally {
      // Reset the flag after a delay to prevent rapid repeated calls
      Future.delayed(Duration(milliseconds: 500), () {
        _isPlaybackInProgress = false;
      });
    }
  }

  // تعديل دالة incrementHymnViews لتحسين تتبع زيادة عدد المشاهدات
  Future<void> incrementHymnViews(String hymnId) async {
    // Prevent incrementing twice for same hymn in a short time period (30 seconds)
    final now = DateTime.now();
    if (_lastIncrementedHymnId == hymnId && _lastIncrementTime != null) {
      final difference = now.difference(_lastIncrementTime!);
      if (difference.inSeconds < 30) {
        print(
            '⚠️ Views already incremented for this hymn recently (${difference.inSeconds}s ago), ignoring request');
        return;
      }
    }

    // Prevent incrementing twice simultaneously
    if (_isIncrementingView) {
      print('⚠️ Already incrementing views, ignoring request');
      return;
    }

    _isIncrementingView = true;

    try {
      print('🔄 Incrementing views for hymn: $hymnId');

      // إضافة تأخير صغير لتجنب التزامن مع عمليات أخرى
      await Future.delayed(Duration(milliseconds: 100));

      // Increment views directly in Firestore
      await FirebaseFirestore.instance
          .collection('hymns')
          .doc(hymnId)
          .update({'views': FieldValue.increment(1)});

      // Update last incremented hymn ID and timestamp
      _lastIncrementedHymnId = hymnId;
      _lastIncrementTime = now;

      print('✅ Views incremented for hymn: $hymnId');
    } catch (e) {
      print('❌ Error incrementing views: $e');
    } finally {
      // إضافة تأخير قبل إعادة تعيين علامة المعالجة
      await Future.delayed(Duration(milliseconds: 100));
      _isIncrementingView = false;
    }
  }

  // Public function to increment view count
  //Future<void> incrementHymnViews(String hymnId) async {
  //  await _incrementHymnViews(hymnId);
  //}

  // New function to update view count locally
  void _updateLocalViewCount(String hymnId) {
    // Update in original hymns list
    for (int i = 0; i < _allHymns.length; i++) {
      if (_allHymns[i].id == hymnId) {
        _allHymns[i] = HymnsModel(
          id: _allHymns[i].id,
          songName: _allHymns[i].songName,
          songUrl: _allHymns[i].songUrl,
          songCategory: _allHymns[i].songCategory,
          songAlbum: _allHymns[i].songAlbum,
          albumImageUrl: _allHymns[i].albumImageUrl,
          views: _allHymns[i].views + 1,
          dateAdded: _allHymns[i].dateAdded,
          youtubeUrl: _allHymns[i].youtubeUrl,
        );
        break;
      }
    }

    // Update in filtered hymns list
    for (int i = 0; i < _filteredHymns.length; i++) {
      if (_filteredHymns[i].id == hymnId) {
        _filteredHymns[i] = HymnsModel(
          id: _filteredHymns[i].id,
          songName: _filteredHymns[i].songName,
          songUrl: _filteredHymns[i].songUrl,
          songCategory: _filteredHymns[i].songCategory,
          songAlbum: _filteredHymns[i].songAlbum,
          albumImageUrl: _filteredHymns[i].albumImageUrl,
          views: _filteredHymns[i].views + 1,
          dateAdded: _filteredHymns[i].dateAdded,
          youtubeUrl: _filteredHymns[i].youtubeUrl,
        );
        break;
      }
    }

    // Update in favorites list
    for (int i = 0; i < _favorites.length; i++) {
      if (_favorites[i].id == hymnId) {
        _favorites[i] = HymnsModel(
          id: _favorites[i].id,
          songName: _favorites[i].songName,
          songUrl: _favorites[i].songUrl,
          songCategory: _favorites[i].songCategory,
          songAlbum: _favorites[i].songAlbum,
          albumImageUrl: _favorites[i].albumImageUrl,
          views: _favorites[i].views + 1,
          dateAdded: _favorites[i].dateAdded,
          youtubeUrl: _favorites[i].youtubeUrl,
        );
        break;
      }
    }

    // Update current hymn if it's the same
    if (_currentHymn?.id == hymnId) {
      _currentHymn = HymnsModel(
        id: _currentHymn!.id,
        songName: _currentHymn!.songName,
        songUrl: _currentHymn!.songUrl,
        songCategory: _currentHymn!.songCategory,
        songAlbum: _currentHymn!.songAlbum,
        albumImageUrl: _currentHymn!.albumImageUrl,
        views: _currentHymn!.views + 1,
        dateAdded: _currentHymn!.dateAdded,
        youtubeUrl: _currentHymn!.youtubeUrl,
      );
    }

    // Update UI
    emit(List.from(_filteredHymns));
  }

  // Save filter preferences
  Future<void> _saveFilterPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

      await prefs.setString('filter_sortBy_$userId', _sortBy);
      await prefs.setBool('filter_descending_$userId', _descending);
      await prefs.setString('filter_category_$userId', _filterCategory ?? '');
      await prefs.setString('filter_album_$userId', _filterAlbum ?? '');
      print('✅ Filter preferences saved for user: $userId');
    } catch (e) {
      print('❌ Error saving filter preferences: $e');
    }
  }

  // Restore filter preferences
  Future<void> _loadFilterPreferences() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      final prefs = await SharedPreferences.getInstance();

      _sortBy = prefs.getString('filter_sortBy_$userId') ?? 'dateAdded';
      _descending = prefs.getBool('filter_descending_$userId') ?? true;

      String categoryStr = prefs.getString('filter_category_$userId') ?? '';
      _filterCategory = categoryStr.isEmpty ? null : categoryStr;

      String albumStr = prefs.getString('filter_album_$userId') ?? '';
      _filterAlbum = albumStr.isEmpty ? null : albumStr;

      print(
          '✅ Filter preferences restored for user $userId: $_sortBy, $_descending, $_filterCategory, $_filterAlbum');
    } catch (e) {
      print('❌ Error restoring filter preferences: $e');
    }
  }

  // Fetch hymns from Firestore
  Future<void> fetchHymns() async {
    try {
      print('🔄 Loading hymns from Firestore...');

      FirebaseFirestore.instance
          .collection('hymns')
          .orderBy('dateAdded', descending: true)
          .snapshots()
          .listen((snapshot) {
        _allHymns = snapshot.docs.map((doc) {
          final data = doc.data();
          return HymnsModel(
            id: doc.id,
            songName: data['songName'] ?? '',
            songUrl: data['songUrl'] ?? '',
            songCategory: data['songCategory'] ?? '',
            songAlbum: data['songAlbum'] ?? '',
            albumImageUrl: data['albumImageUrl'],
            views: data['views'] ?? 0,
            dateAdded: (data['dateAdded'] as Timestamp).toDate(),
            youtubeUrl: data['youtubeUrl'],
          );
        }).toList();

        print('✅ Loaded ${_allHymns.length} hymns from Firestore');

        // Apply current filter to new list
        _applyFilters();

        // After loading hymns, try to restore last hymn
        _restoreLastHymnFromPrefs();

        // Update favorites list after loading hymns
        loadFavorites();
      });
    } catch (e) {
      print('❌ Error fetching hymns: $e');
      emit([]);
    }
  }

  // Apply filters to list
  void _applyFilters() {
    try {
      // Copy of original list
      _filteredHymns = List.from(_allHymns);

      // Apply category filter
      if (_filterCategory != null && _filterCategory!.isNotEmpty) {
        _filteredHymns = _filteredHymns
            .where((hymn) => hymn.songCategory == _filterCategory)
            .toList();
      }

      // Apply album filter
      if (_filterAlbum != null && _filterAlbum!.isNotEmpty) {
        _filteredHymns = _filteredHymns
            .where((hymn) => hymn.songAlbum == _filterAlbum)
            .toList();
      }

      // Apply sorting
      _filteredHymns.sort((a, b) {
        int result;
        switch (_sortBy) {
          case 'songName':
            result = a.songName.compareTo(b.songName);
            break;
          case 'views':
            result = a.views.compareTo(b.views);
            break;
          case 'dateAdded':
          default:
            result = a.dateAdded.compareTo(b.dateAdded);
            break;
        }

        // Reverse result if descending
        return _descending ? -result : result;
      });

      emit(_filteredHymns);
      print(
          '✅ Filters applied, hymn count after filtering: ${_filteredHymns.length}');
    } catch (e) {
      print('❌ Error applying filters: $e');
    }
  }

  /// ✅ **Create new hymn**
  Future<void> createHymn({
    required String songName,
    required String songUrl,
    required String songCategory,
    required String songAlbum,
    String? youtubeUrl,
  }) async {
    try {
      await _hymnsRepository.addHymn(
        songName: songName,
        songUrl: songUrl,
        songCategory: songCategory,
        songAlbum: songAlbum,
        youtubeUrl: youtubeUrl,
      );

      fetchHymns();
      print('✅ New hymn created: $songName');
    } catch (e) {
      print("❌ Error adding hymn: $e");
    }
  }

  /// ✅ **Delete hymn**
  Future<void> deleteHymn(String hymnId) async {
    try {
      await _hymnsRepository.deleteHymn(hymnId);

      // Update local data
      final updatedHymns = state.where((hymn) => hymn.id != hymnId).toList();
      emit(updatedHymns);

      // Update cache
      await _cacheService.saveToDatabase('hymns', 'all', {
        'hymns': updatedHymns.map((h) => h.toJson()).toList(),
      });

      // Update favorites list
      _favorites.removeWhere((hymn) => hymn.id == hymnId);

      print('✅ Hymn deleted: $hymnId');
    } catch (e) {
      print('❌ Error deleting hymn: $e');
    }
  }

  // Modified changeSort to support filtering
  Future<void> changeSort(String sortBy, bool descending) async {
    _sortBy = sortBy;
    _descending = descending;

    // Reset category and album filters
    _filterCategory = null;
    _filterAlbum = null;

    // Save filter preferences
    await _saveFilterPreferences();

    // Apply filters
    _applyFilters();

    print(
        '✅ Sorting applied: $_sortBy, ${_descending ? "descending" : "ascending"}');
  }

  // Add function to save state on app close
  Future<void> saveStateOnAppClose() async {
    try {
      print('📱 Saving playback state on app close...');

      // Save current hymn state
      if (_currentHymn != null) {
        await saveLastHymnState();
      }

      // Explicitly save audio service state
      await _audioService.saveStateOnAppClose();

      // حفظ سياق قائمة التشغيل
      final prefs = await SharedPreferences.getInstance();
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

      await prefs.setString(
          'currentPlaylistType_$userId', _currentPlaylistType);
      await prefs.setString(
          'currentPlaylistId_$userId', _currentPlaylistId ?? '');

      print(
          '💾 تم حفظ سياق قائمة التشغيل: $_currentPlaylistType, ${_currentPlaylistId ?? "null"}');

      print('✅ Playback state saved on app close');
    } catch (e) {
      print('❌ Error saving playback state on app close: $e');
    }
  }

  // Modified saveLastHymnState to save position more accurately
  Future<void> saveLastHymnState() async {
    if (_currentHymn == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

      // Clear any previous hymn data
      await prefs.remove('lastHymnBasic_$userId');

      // Convert hymn to JSON
      final hymnJson = _currentHymn!.toJson();

      // Save hymn information
      await prefs.setString('lastHymn_$userId', jsonEncode(hymnJson));

      // Explicitly save current position
      final currentPosition = _audioService.positionNotifier.value.inSeconds;
      await prefs.setInt('lastPosition_$userId', currentPosition);

      // Save playback state
      await prefs.setBool(
          'wasPlaying_$userId', _audioService.isPlayingNotifier.value);

      // Save current playlist type and ID
      await prefs.setString(
          'currentPlaylistType_$userId', _currentPlaylistType);
      await prefs.setString(
          'currentPlaylistId_$userId', _currentPlaylistId ?? '');

      print(
          '💾 Last hymn state saved for user: $userId, position: $currentPosition seconds');
      print(
          '💾 Playlist context saved: $_currentPlaylistType, ${_currentPlaylistId ?? "null"}');
    } catch (e) {
      print('❌ Error saving last hymn state: $e');

      // Try to save basic information only if saving full hymn fails
      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

        // Save only hymn ID and name
        final basicInfo = {
          'id': _currentHymn!.id,
          'songName': _currentHymn!.songName,
          'songUrl': _currentHymn!.songUrl,
        };

        await prefs.setString('lastHymnBasic_$userId', jsonEncode(basicInfo));

        // Save current position
        final currentPosition = _audioService.positionNotifier.value.inSeconds;
        await prefs.setInt('lastPosition_$userId', currentPosition);

        print('💾 Basic hymn information saved successfully');
      } catch (e2) {
        print('❌ Basic information save failed too: $e2');
      }
    }
  }

  // Modified restoreLastHymn to improve playback state restoration
  Future<void> restoreLastHymn() async {
    try {
      print('🔄 Restoring last hymn from HymnsCubit...');

      // Don't call audioService.restorePlaybackState() here
      // as it's already called in MyAudioService constructor

      // Just update UI based on current audioService state
      final currentTitle = _audioService.currentTitleNotifier.value;
      final currentIndex = _audioService.currentIndexNotifier.value;

      if (currentTitle != null) {
        print('✅ Last hymn found: $currentTitle');

        // Find hymn in list
        final hymnIndex =
            _filteredHymns.indexWhere((h) => h.songName == currentTitle);
        if (hymnIndex != -1) {
          // Update current hymn without playing it
          _currentHymn = _filteredHymns[hymnIndex];

          // Update UI
          emit(List.from(_filteredHymns));

          print('✅ UI updated with last hymn');
        }
      } else {
        print('⚠️ No last hymn found');
      }

      // استعادة سياق قائمة التشغيل
      final prefs = await SharedPreferences.getInstance();
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

      _currentPlaylistType =
          prefs.getString('currentPlaylistType_$userId') ?? 'general';
      String savedId = prefs.getString('currentPlaylistId_$userId') ?? '';
      _currentPlaylistId = savedId.isEmpty ? null : savedId;

      print(
          '🔄 تم استعادة سياق قائمة التشغيل: $_currentPlaylistType, ${_currentPlaylistId ?? "null"}');
    } catch (e) {
      print('❌ Error restoring last hymn: $e');
    }
  }

  /// ✅ Restore last hymn from preferences
  Future<void> _restoreLastHymnFromPrefs() async {
    try {
      final userId = _getCurrentUserId();
      final prefs = await SharedPreferences.getInstance();
      final lastHymnJson = prefs.getString('lastHymn_$userId');

      if (lastHymnJson != null) {
        final lastHymn = HymnsModel.fromJson(jsonDecode(lastHymnJson));

        // Find hymn in current list
        final hymnInState = state.firstWhere(
          (h) => h.id == lastHymn.id,
          orElse: () => lastHymn,
        );

        // Update current hymn without incrementing views
        await _updateCurrentHymnWithAlbumImage(hymnInState,
            incrementViews: false);

        // Restore playlist type and ID
        _currentPlaylistType =
            prefs.getString('currentPlaylistType_$userId') ?? 'general';
        _currentPlaylistId = prefs.getString('currentPlaylistId_$userId');
        if (_currentPlaylistId?.isEmpty == true) _currentPlaylistId = null;

        // Update UI
        emit(List.from(state));

        print('✅ Last hymn restored from cache for user: $userId');
        print(
            '✅ Playlist context restored: $_currentPlaylistType, ${_currentPlaylistId ?? "null"}');
      }
    } catch (e) {
      print('❌ Error restoring last hymn from cache: $e');
    }
  }

  // Add variable to store favorite hymn IDs only
  List<String> _favoriteHymnIds = [];

  // Modified toggleFavorite to work with Firestore and update local list immediately
  Future<bool> toggleFavorite(HymnsModel hymn) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ Must be logged in to add hymn to favorites');
        return false;
      }

      print(
          '🔄 Toggling favorite status for hymn: ${hymn.songName} (ID: ${hymn.id})');

      // Check if hymn is already in favorites
      final favoriteRef = FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: user.uid)
          .where('hymnId', isEqualTo: hymn.id)
          .limit(1);

      final snapshot = await favoriteRef.get();
      final wasInFavorites = snapshot.docs.isNotEmpty;

      print(
          '📊 Current favorite status: ${wasInFavorites ? "in favorites" : "not in favorites"}');

      // Update database
      if (!wasInFavorites) {
        // Add to favorites
        await FirebaseFirestore.instance.collection('favorites').add({
          'userId': user.uid,
          'hymnId': hymn.id,
          'songName': hymn.songName,
          'songUrl': hymn.songUrl,
          'songCategory': hymn.songCategory,
          'songAlbum': hymn.songAlbum,
          'views': hymn.views,
          'dateAdded': FieldValue.serverTimestamp(),
        });

        // Update cache
        _favoriteCache[hymn.id] = true;
        if (!_favoriteHymnIds.contains(hymn.id)) {
          _favoriteHymnIds.add(hymn.id);
        }

        print('✅ Hymn added to favorites in Firestore');
      } else {
        // Get document ID to delete
        final docId = snapshot.docs.first.id;
        await FirebaseFirestore.instance
            .collection('favorites')
            .doc(docId)
            .delete();

        // Update cache
        _favoriteCache[hymn.id] = false;
        _favoriteHymnIds.remove(hymn.id);

        print('✅ Hymn removed from favorites in Firestore (ID: $docId)');
      }

      // Reload favorites after change
      await loadFavorites();

      // Update UI
      emit(List.from(_filteredHymns));

      print(
          '✅ Favorite status updated locally: ${!wasInFavorites ? "added" : "removed"}');

      return !wasInFavorites; // Return new state (true if added, false if removed)
    } catch (e) {
      print('❌ Error toggling favorite status: $e');
      throw e; // Rethrow error to be caught in UI
    }
  }

  // Modified loadFavorites to use ID-first approach
  Future<void> loadFavorites() async {
    if (_isLoadingFavorites) {
      print('⚠️ Already loading favorites, ignoring new request');
      return;
    }

    _isLoadingFavorites = true;
    print('🔄 Starting favorites loading...');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _favorites = [];
        _favoriteHymnIds = [];
        _favoriteCache.clear();
        emit(List.from(_filteredHymns));
        _isLoadingFavorites = false;
        print('⚠️ No logged in user, favorites cleared');
        return;
      }

      print('🔄 Loading favorites for user: ${user.uid}');

      // Get favorites from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: user.uid)
          .get();

      print(
          '📋 Data received from Firestore: ${snapshot.docs.length} documents');

      // Convert documents to HymnsModel list
      List<HymnsModel> loadedFavorites = [];
      _favoriteHymnIds = []; // Reset IDs list

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Check for required data
        if (data['hymnId'] != null &&
            data['songName'] != null &&
            data['songUrl'] != null) {
          final hymnId = data['hymnId'] as String;

          // Add ID to IDs list
          _favoriteHymnIds.add(hymnId);

          // Update cache
          _favoriteCache[hymnId] = true;

          loadedFavorites.add(HymnsModel(
            id: hymnId,
            songName: data['songName'] ?? '',
            songUrl: data['songUrl'] ?? '',
            songCategory: data['songCategory'] ?? '',
            songAlbum: data['songAlbum'] ?? '',
            albumImageUrl: data['albumImageUrl'],
            views: data['views'] ?? 0,
            dateAdded:
                (data['dateAdded'] as Timestamp?)?.toDate() ?? DateTime.now(),
            youtubeUrl: data['youtubeUrl'],
          ));
        }
      }

      // Update favorites list
      _favorites = loadedFavorites;
      print('✅ Loaded ${_favorites.length} favorites successfully');

      // Update UI
      emit(List.from(_filteredHymns));
      print('✅ UI updated after loading favorites');
    } catch (e) {
      print('❌ Error loading favorites: $e');
    } finally {
      _isLoadingFavorites = false;
    }
  }

  // Simplified isHymnFavorite for more reliability
  Future<bool> isHymnFavorite(String hymnId) async {
    try {
      // Check cache first
      if (_favoriteCache.containsKey(hymnId)) {
        return _favoriteCache[hymnId]!;
      }

      // Check local IDs list
      if (_favoriteHymnIds.contains(hymnId)) {
        _favoriteCache[hymnId] = true;
        return true;
      }

      // Check local favorites list
      if (_favorites.any((hymn) => hymn.id == hymnId)) {
        _favoriteCache[hymnId] = true;
        return true;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _favoriteCache[hymnId] = false;
        return false;
      }

      // Check Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: user.uid)
          .where('hymnId', isEqualTo: hymnId)
          .limit(1)
          .get();

      final isFavorite = snapshot.docs.isNotEmpty;
      _favoriteCache[hymnId] = isFavorite;

      if (isFavorite && !_favoriteHymnIds.contains(hymnId)) {
        _favoriteHymnIds.add(hymnId);
      }

      return isFavorite;
    } catch (e) {
      print('❌ Error checking favorite status: $e');
      return false;
    }
  }

  /// ✅ **Get favorites list**
  List<HymnsModel> getFavorites() => _favorites;

  /// ✅ **Get albums stream from Firestore**
  Stream<QuerySnapshot> fetchAlbumsStream() {
    try {
      // Try to get data from cache first
      _cacheService.getFromDatabase('albums', 'all').then((cachedAlbums) {
        if (cachedAlbums != null) {
          // Can use cached data
          print('✅ Albums data retrieved from cache');
        }
      });

      return FirebaseFirestore.instance
          .collection('albums')
          .snapshots()
          .map((snapshot) {
        // Save data to cache
        _cacheService.saveToDatabase('albums', 'all', {
          'albums': snapshot.docs.map((doc) => doc.data()).toList(),
        });
        return snapshot;
      });
    } catch (e) {
      print('❌ Error fetching albums: $e');
      return Stream.empty();
    }
  }

  /// ✅ **Get categories stream from Firestore**
  Stream<QuerySnapshot> fetchCategoriesStream() {
    try {
      // Try to get data from cache first
      _cacheService
          .getFromDatabase('categories', 'all')
          .then((cachedCategories) {
        if (cachedCategories != null) {
          // Can use cached data
          print('✅ Categories data retrieved from cache');
        }
      });

      return FirebaseFirestore.instance
          .collection('categories')
          .snapshots()
          .map((snapshot) {
        // Save data to cache
        _cacheService.saveToDatabase('categories', 'all', {
          'categories': snapshot.docs.map((doc) => doc.data()).toList(),
        });
        return snapshot;
      });
    } catch (e) {
      print('❌ Error fetching categories: $e');
      return Stream.empty();
    }
  }

  /// ✅ **Search hymns by name**
  void searchHymns(String query) {
    if (query.isEmpty) {
      _applyFilters(); // Reset to filtered list
      return;
    }

    final searchResults = _allHymns.where((hymn) {
      return hymn.songName.toLowerCase().contains(query.toLowerCase());
    }).toList();

    emit(searchResults);
  }

  /// ✅ **Update hymn with album image**
  Future<void> _updateCurrentHymnWithAlbumImage(HymnsModel hymn,
      {bool incrementViews = true}) async {
    try {
      if (hymn.albumImageUrl != null && hymn.albumImageUrl!.isNotEmpty) {
        // Already has album image
        _currentHymn = hymn;
        return;
      }

      // Try to find album image
      if (hymn.songAlbum.isNotEmpty) {
        final albumSnapshot = await FirebaseFirestore.instance
            .collection('albums')
            .where('name', isEqualTo: hymn.songAlbum)
            .limit(1)
            .get();

        if (albumSnapshot.docs.isNotEmpty) {
          final albumData = albumSnapshot.docs.first.data();
          final albumImageUrl = albumData['image'] as String?;

          if (albumImageUrl != null && albumImageUrl.isNotEmpty) {
            // Create new hymn with album image
            _currentHymn = HymnsModel(
              id: hymn.id,
              songName: hymn.songName,
              songUrl: hymn.songUrl,
              songCategory: hymn.songCategory,
              songAlbum: hymn.songAlbum,
              albumImageUrl: albumImageUrl,
              views: hymn.views,
              dateAdded: hymn.dateAdded,
              youtubeUrl: hymn.youtubeUrl,
            );

            print('✅ Updated current hymn with album image');
            return;
          }
        }
      }

      // No album image found, just use the hymn as is
      _currentHymn = hymn;
    } catch (e) {
      print('❌ Error updating hymn with album image: $e');
      _currentHymn = hymn; // Use original hymn as fallback
    }
  }

  String _getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  }

  /// ✅ **مسح بيانات المستخدم**
  Future<void> clearUserData() async {
    try {
      print('🧹 جاري مسح بيانات المستخدم في HymnsCubit...');

      // مسح قائمة المفضلة
      _favorites = [];
      _favoriteHymnIds = [];
      _favoriteCache.clear();

      // إعادة تعيين المتغيرات
      _currentHymn = null;
      _lastIncrementedHymnId = null;
      _lastIncrementTime = null;

      // إعادة تعيين المرشحات
      _filterCategory = null;
      _filterAlbum = null;

      // مسح البيانات من SharedPreferences
      final userId = _getCurrentUserId();
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('lastHymn_$userId');
      await prefs.remove('lastHymnBasic_$userId');
      await prefs.remove('lastPosition_$userId');
      await prefs.remove('wasPlaying_$userId');
      await prefs.remove('lastPlayedTitle_$userId');
      await prefs.remove('lastPlayedIndex_$userId');
      await prefs.remove('lastPlaylist_$userId');
      await prefs.remove('lastTitles_$userId');
      await prefs.remove('lastArtworkUrls_$userId');
      await prefs.remove('repeatMode_$userId');
      await prefs.remove('isShuffling_$userId');
      await prefs.remove('currentPlaylistType_$userId');
      await prefs.remove('currentPlaylistId_$userId');

      // مسح بيانات المستخدم في خدمة الصوت
      await _audioService.clearUserData();

      // تحديث واجهة المستخدم
      emit(List.from(_filteredHymns));

      print('✅ تم مسح بيانات المستخدم بنجاح');
    } catch (e) {
      print('❌ خطأ في مسح بيانات المستخدم: $e');
    }
  }

  // دالة جلب صور الألبومات للترانيم مع تشخيص مفصل جداً
  Future<List<String?>> _getArtworkUrlsForHymns(List<HymnsModel> hymns) async {
    try {
      print('🔍 بدء جلب صور الألبومات...');
      print('📊 عدد الترانيم المطلوب جلب صورها: ${hymns.length}');

      // طباعة تفاصيل أول 5 ترانيم للتشخيص
      print('🎵 تفاصيل أول 5 ترانيم:');
      for (int i = 0; i < Math.min(5, hymns.length); i++) {
        final hymn = hymns[i];
        print('   [$i] اسم الترنيمة: "${hymn.songName}"');
        print('       اسم الألبوم: "${hymn.songAlbum}"');
        print(
            '       صورة الترنيمة المحفوظة: "${hymn.albumImageUrl ?? "null"}"');
        print('       رابط الترنيمة: "${hymn.songUrl}"');
        print('       معرف الترنيمة: "${hymn.id}"');
      }

      // جمع أسماء الألبومات الفريدة
      final Set<String> uniqueAlbums = hymns
          .where((hymn) => hymn.songAlbum.isNotEmpty)
          .map((hymn) => hymn.songAlbum)
          .toSet();

      print('📋 الألبومات الفريدة المطلوبة: ${uniqueAlbums.toList()}');
      print('📊 عدد الألبومات الفريدة: ${uniqueAlbums.length}');

      // جلب بيانات الألبومات من Firestore
      final Map<String, String> albumImages = {};

      if (uniqueAlbums.isNotEmpty) {
        try {
          print('🔄 جاري الاستعلام من Firestore للألبومات...');

          // تقسيم الاستعلام إذا كان عدد الألبومات أكبر من 10 (حد Firestore)
          final List<String> albumsList = uniqueAlbums.toList();
          final List<List<String>> chunks = [];

          for (int i = 0; i < albumsList.length; i += 10) {
            chunks.add(
                albumsList.sublist(i, Math.min(i + 10, albumsList.length)));
          }

          print('📦 تم تقسيم الاستعلام إلى ${chunks.length} مجموعة');

          for (int chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
            final chunk = chunks[chunkIndex];
            print('🔍 معالجة المجموعة ${chunkIndex + 1}: ${chunk}');

            final albumsSnapshot = await FirebaseFirestore.instance
                .collection('albums')
                .where('name', whereIn: chunk)
                .get();

            print(
                '📊 تم العثور على ${albumsSnapshot.docs.length} ألبوم في المجموعة ${chunkIndex + 1}');

            for (final doc in albumsSnapshot.docs) {
              final data = doc.data();
              final albumName = data['name'] as String?;
              final albumImage = data['image'] as String?;

              print('   📁 ألبوم: "$albumName"');
              print('      🖼️ صورة: ${albumImage ?? "لا توجد"}');
              print('      📝 البيانات الكاملة: $data');
              print('      📄 معرف المستند: ${doc.id}');

              if (albumName != null &&
                  albumImage != null &&
                  albumImage.isNotEmpty &&
                  albumImage != 'null') {
                albumImages[albumName] = albumImage;
                print('   ✅ تم حفظ صورة الألبوم "$albumName": $albumImage');
              } else {
                print('   ❌ ألبوم "$albumName": لا توجد صورة صالحة');
                if (albumName != null &&
                    (albumImage == null || albumImage.isEmpty)) {
                  print('      🔍 السبب: الصورة فارغة أو null');
                }
                if (albumImage == 'null') {
                  print('      🔍 السبب: الصورة تحتوي على نص "null"');
                }
              }
            }
          }

          print('📊 إجمالي الصور المحفوظة: ${albumImages.length}');
          print('📋 قائمة الصور المحفوظة:');
          albumImages.forEach((albumName, imageUrl) {
            print('   "$albumName" -> "$imageUrl"');
          });

          // إضافة استعلام إضافي للتحقق من جميع الألبومات في قاعدة البيانات
          print('🔍 جاري فحص جميع الألبومات في قاعدة البيانات...');
          final allAlbumsSnapshot =
              await FirebaseFirestore.instance.collection('albums').get();

          print(
              '📊 إجمالي الألبومات في قاعدة البيانات: ${allAlbumsSnapshot.docs.length}');
          for (final doc in allAlbumsSnapshot.docs) {
            final data = doc.data();
            final albumName = data['name'] as String?;
            final albumImage = data['image'] as String?;
            print('   📁 "$albumName" -> 🖼️ "${albumImage ?? "null"}"');
          }
        } catch (e) {
          print('❌ خطأ في جلب بيانات الألبومات من Firestore: $e');
          print('📋 تفاصيل الخطأ: ${e.toString()}');
          print('📋 Stack trace: ${StackTrace.current}');
        }
      } else {
        print('⚠️ لا توجد ألبومات للبحث عنها');
      }

      // ربط كل ترنيمة بصورة الألبوم الخاص بها
      final List<String?> artworkUrls = [];
      print('🔗 بدء ربط الترانيم بصور الألبومات:');

      for (int i = 0; i < hymns.length; i++) {
        final hymn = hymns[i];
        String? artworkUrl;

        print('🎵 [$i] معالجة الترنيمة: "${hymn.songName}"');
        print('   📁 الألبوم: "${hymn.songAlbum}"');
        print(
            '   🖼️ صورة الترنيمة المحفوظة: ${hymn.albumImageUrl ?? "لا توجد"}');

        // أولاً: محاولة استخدام صورة الألبوم المحفوظة مع الترنيمة
        if (hymn.albumImageUrl != null &&
            hymn.albumImageUrl!.isNotEmpty &&
            hymn.albumImageUrl != 'null') {
          artworkUrl = hymn.albumImageUrl;
          print('   ✅ استخدام الصورة المحفوظة مع الترنيمة: $artworkUrl');
        }
        // ثانياً: البحث عن صورة الألبوم من قاعدة البيانات
        else if (hymn.songAlbum.isNotEmpty) {
          print(
              '   🔍 البحث عن صورة الألبوم "${hymn.songAlbum}" في قاعدة البيانات...');

          if (albumImages.containsKey(hymn.songAlbum)) {
            artworkUrl = albumImages[hymn.songAlbum];
            print('   ✅ تم العثور على صورة الألبوم: $artworkUrl');
          } else {
            print('   ❌ لم يتم العثور على صورة للألبوم "${hymn.songAlbum}"');
            print('   📋 الألبومات المتاحة: ${albumImages.keys.toList()}');

            // محاولة البحث بطريقة مختلفة (case insensitive)
            final albumKey = albumImages.keys.firstWhere(
              (key) => key.toLowerCase() == hymn.songAlbum.toLowerCase(),
              orElse: () => '',
            );

            if (albumKey.isNotEmpty) {
              artworkUrl = albumImages[albumKey];
              print(
                  '   ✅ تم العثور على صورة الألبوم بالبحث المرن: $artworkUrl');
            } else {
              print('   ❌ لم يتم العثور على صورة حتى بالبحث المرن');

              // محاولة البحث الجزئي
              final partialMatch = albumImages.keys.firstWhere(
                (key) =>
                    key.contains(hymn.songAlbum) ||
                    hymn.songAlbum.contains(key),
                orElse: () => '',
              );

              if (partialMatch.isNotEmpty) {
                artworkUrl = albumImages[partialMatch];
                print(
                    '   ✅ تم العثور على صورة بالبحث الجزئي: "$partialMatch" -> $artworkUrl');
              } else {
                print('   ❌ لم يتم العثور على أي تطابق جزئي');
              }
            }
          }
        }
        // ثالثاً: لا توجد صورة
        else {
          print('   ⚠️ لا يوجد اسم ألبوم للترنيمة');
        }

        // التحقق النهائي من صحة الرابط
        if (artworkUrl != null &&
            artworkUrl.isNotEmpty &&
            artworkUrl != 'null') {
          if (artworkUrl.startsWith('http')) {
            print('   🎯 النتيجة النهائية: رابط صالح -> $artworkUrl');
          } else {
            print('   ⚠️ رابط غير صالح (لا يبدأ بـ http): $artworkUrl');
            artworkUrl = null;
          }
        } else {
          print('   🎯 النتيجة النهائية: null');
        }

        artworkUrls.add(artworkUrl);
        print('');
      }

      print('✅ تم إنشاء قائمة صور الألبومات: ${artworkUrls.length} عنصر');
      print('📊 إحصائيات النتائج:');

      int validUrls = artworkUrls
          .where((url) => url != null && url.isNotEmpty && url != 'null')
          .length;
      int nullUrls = artworkUrls
          .where((url) => url == null || url.isEmpty || url == 'null')
          .length;

      print('   ✅ صور صالحة: $validUrls');
      print('   ❌ صور فارغة: $nullUrls');

      print('📋 قائمة النتائج النهائية (جميع الترانيم):');
      for (int i = 0; i < artworkUrls.length; i++) {
        final url = artworkUrls[i];
        final status =
            (url != null && url.isNotEmpty && url != 'null') ? '✅' : '❌';
        print(
            '   [$i] ${hymns[i].songName} (${hymns[i].songAlbum}) -> $status ${url ?? "null"}');
      }

      return artworkUrls;
    } catch (e) {
      print('❌ خطأ عام في جلب صور الألبومات: $e');
      print('📋 تفاصيل الخطأ: ${e.toString()}');
      print('📋 Stack trace: ${StackTrace.current}');
      // إرجاع قائمة فارغة في حالة الخطأ
      return List.filled(hymns.length, null);
    }
  }
}
