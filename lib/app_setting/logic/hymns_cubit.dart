import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymn_repository.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_state.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:om_elnour_choir/services/cache_service.dart';
import 'dart:convert';

class HymnsCubit extends Cubit<List<HymnsModel>> {
  final HymnsRepository _hymnsRepository;
  final MyAudioService _audioService;
  final CacheService _cacheService = CacheService();
  MyAudioService get audioService => _audioService;

  String _sortBy = 'dateAdded';
  bool _descending = true;
  HymnsModel? _currentHymn;
  List<HymnsModel> _favorites = [];
  List<HymnsModel> hymns = [];

  HymnsCubit(this._hymnsRepository, this._audioService) : super([]) {
    fetchHymns();
    loadFavorites();
    _restorePlaybackState();
  }

  /// ✅ **تحميل الترانيم من Firestore**
  Future<void> fetchHymns() async {
    try {
      // محاولة جلب البيانات من التخزين المؤقت أولاً
      final cachedHymns = await _cacheService.getFromDatabase('hymns', 'all');
      if (cachedHymns != null) {
        final List<dynamic> hymnsList = cachedHymns['hymns'];
        final hymns =
            hymnsList.map((hymn) => HymnsModel.fromJson(hymn)).toList();
        // ترتيب الترانيم من الأحدث إلى الأقدم
        hymns.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        emit(hymns);
      }

      // جلب البيانات من Firestore
      FirebaseFirestore.instance
          .collection('hymns')
          .orderBy('dateAdded', descending: true) // ترتيب من الأحدث إلى الأقدم
          .snapshots()
          .listen((snapshot) {
        final hymns = snapshot.docs.map((doc) {
          final data = doc.data();
          return HymnsModel(
            id: doc.id,
            songName: data['songName'] ?? '',
            songUrl: data['songUrl'] ?? '',
            songCategory: data['songCategory'] ?? '',
            songAlbum: data['songAlbum'] ?? '',
            views: data['views'] ?? 0,
            dateAdded: (data['dateAdded'] as Timestamp).toDate(),
            youtubeUrl: data['youtubeUrl'],
          );
        }).toList();

        // حفظ البيانات في التخزين المؤقت
        _cacheService.saveToDatabase('hymns', 'all', {
          'hymns': hymns.map((h) => h.toJson()).toList(),
        });

        emit(hymns);
      });
    } catch (e) {
      print('❌ خطأ في جلب الترانيم: $e');
    }
  }

  /// ✅ **إنشاء ترنيمة جديدة**
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
    } catch (e) {
      print("❌ خطأ أثناء إضافة الترنيمة: $e");
    }
  }

  /// ✅ **تشغيل ترنيمة مع تحديث المشاهدات**
  Future<void> playHymn(HymnsModel hymn, {bool incrementViews = true}) async {
    try {
      print('🎵 جاري تشغيل الترنيمة: ${hymn.songName}');

      // تحديث الترنيمة الحالية مع صورة الألبوم وزيادة عدد المشاهدات
      await _updateCurrentHymnWithAlbumImage(hymn,
          incrementViews: incrementViews);

      // تحديث قائمة التشغيل
      final urls = state.map((h) => h.songUrl).toList();
      final titles = state.map((h) => h.songName).toList();
      await _audioService.setPlaylist(urls, titles);
      print('✅ تم تحديث قائمة التشغيل');

      // تشغيل الترنيمة المحددة
      final index = state.indexWhere((h) => h.id == hymn.id);
      print('🔍 تم العثور على الترنيمة في القائمة: $index');

      if (index != -1) {
        // تحديث عنوان الترنيمة الحالية
        _audioService.currentTitleNotifier.value = hymn.songName;
        print('✅ تم تحديث عنوان الترنيمة الحالية');

        // تشغيل الترنيمة
        await _audioService.stop(); // إيقاف الترنيمة الحالية
        await Future.delayed(Duration(milliseconds: 100)); // انتظار قليلاً
        await _audioService.play(index, hymn.songName);
        print('▶️ تم تشغيل الترنيمة');

        // حفظ الترنيمة الأخيرة
        await _cacheService.saveToPrefs(
            'lastPlayedHymn', _currentHymn!.toJson());
        print('💾 تم حفظ الترنيمة الأخيرة');
      }
    } catch (e) {
      print('❌ خطأ في تشغيل الترنيمة: $e');
    }
  }

  /// ✅ **تشغيل ترنيمة داخل ألبوم معين**
  Future<void> playHymnFromAlbum(List<HymnsModel> albumHymns, int index) async {
    if (index < 0 || index >= albumHymns.length) return;

    try {
      print('🎵 جاري تشغيل الترنيمة من الألبوم: ${albumHymns[index].songName}');

      // تحديث الترنيمة الحالية مع صورة الألبوم وزيادة عدد المشاهدات
      await _updateCurrentHymnWithAlbumImage(albumHymns[index],
          incrementViews: true);

      // تحديث قائمة التشغيل
      _audioService.setPlaylist(
        albumHymns.map((e) => e.songUrl).toList(),
        albumHymns.map((e) => e.songName).toList(),
      );
      print('✅ تم تحديث قائمة التشغيل');

      // تحديث عنوان الترنيمة الحالية
      _audioService.currentTitleNotifier.value = _currentHymn!.songName;
      print('✅ تم تحديث عنوان الترنيمة الحالية');

      // تشغيل الترنيمة
      await _audioService.play(index, _currentHymn!.songName);
      print('▶️ تم تشغيل الترنيمة');

      // حفظ الترنيمة الأخيرة
      await _cacheService.saveToPrefs('lastPlayedHymn', _currentHymn!.toJson());
      print('💾 تم حفظ الترنيمة الأخيرة');
    } catch (e) {
      print('❌ خطأ في تشغيل الترنيمة من الألبوم: $e');
    }
  }

  /// ✅ **حذف ترنيمة**
  Future<void> deleteHymn(String hymnId) async {
    try {
      await _hymnsRepository.deleteHymn(hymnId);

      // تحديث البيانات المحلية
      final updatedHymns = state.where((hymn) => hymn.id != hymnId).toList();
      emit(updatedHymns);

      // تحديث التخزين المؤقت
      await _cacheService.saveToDatabase('hymns', 'all', {
        'hymns': updatedHymns.map((h) => h.toJson()).toList(),
      });
    } catch (e) {
      print('❌ خطأ في حذف الترنيمة: $e');
    }
  }

  /// ✅ **تغيير الفرز وإعادة تحميل البيانات**
  void changeSort(String sortBy, bool descending) {
    _sortBy = sortBy;
    _descending = descending;
    fetchHymns();
  }

  /// ✅ **حفظ آخر ترنيمة مشغلة**
  Future<void> saveLastHymnState() async {
    if (_currentHymn == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastHymn', jsonEncode(_currentHymn!.toJson()));
    await prefs.setInt(
        'lastPosition', _audioService.positionNotifier.value.inSeconds);
    await prefs.setBool('wasPlaying', _audioService.isPlayingNotifier.value);
  }

  /// ✅ **استعادة آخر ترنيمة بدون تشغيلها تلقائيًا**
  Future<void> restoreLastHymn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastHymnJson = prefs.getString('lastHymn');
      final lastPosition = prefs.getInt('lastPosition') ?? 0;
      final wasPlaying = prefs.getBool('wasPlaying') ?? false;

      if (lastHymnJson != null) {
        final lastHymn = HymnsModel.fromJson(jsonDecode(lastHymnJson));
        _currentHymn = lastHymn;
        emit(List.from(state));

        // استعادة موضع التشغيل
        await _audioService.seek(Duration(seconds: lastPosition));
        if (wasPlaying) {
          await _audioService.play(
              _audioService.currentIndexNotifier.value, lastHymn.songName);
        }
      }
    } catch (e) {
      print('❌ خطأ في استعادة آخر ترنيمة: $e');
    }
  }

  /// ✅ **إضافة ترنيمة إلى المفضلة**
  Future<void> toggleFavorite(HymnsModel hymn) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favoriteIds = prefs.getStringList('favoriteHymns') ?? [];

    if (favoriteIds.contains(hymn.id)) {
      favoriteIds.remove(hymn.id);
      _favorites.removeWhere((h) => h.id == hymn.id);
    } else {
      favoriteIds.add(hymn.id);
      _favorites.add(hymn);
    }

    await prefs.setStringList('favoriteHymns', favoriteIds);
    emit(List.from(state)); // تحديث الواجهة
  }

  /// ✅ **تحميل قائمة المفضلة**
  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favoriteIds = prefs.getStringList('favoriteHymns') ?? [];

    _favorites = state.where((hymn) => favoriteIds.contains(hymn.id)).toList();
  }

  /// ✅ **استرجاع قائمة الترانيم المفضلة**
  List<HymnsModel> getFavorites() => _favorites;

  /// ✅ **جلب قائمة الألبومات من Firestore كـ Stream**
  Stream<QuerySnapshot> fetchAlbumsStream() {
    try {
      // محاولة جلب البيانات من التخزين المؤقت أولاً
      _cacheService.getFromDatabase('albums', 'all').then((cachedAlbums) {
        if (cachedAlbums != null) {
          // يمكن استخدام البيانات المخزنة مؤقتاً
        }
      });

      return FirebaseFirestore.instance
          .collection('albums')
          .snapshots()
          .map((snapshot) {
        // حفظ البيانات في التخزين المؤقت
        _cacheService.saveToDatabase('albums', 'all', {
          'albums': snapshot.docs.map((doc) => doc.data()).toList(),
        });
        return snapshot;
      });
    } catch (e) {
      print('❌ خطأ في جلب الألبومات: $e');
      return Stream.empty();
    }
  }

  /// ✅ **جلب قائمة الألبومات من Firestore كقائمة عادية**
  Future<List<Map<String, dynamic>>> fetchAlbums() async {
    try {
      print("🔄 جاري تحميل الألبومات...");

      // التحقق من حالة الاتصال بـ Firebase
      print("🔍 التحقق من حالة Firebase...");
      var firestore = FirebaseFirestore.instance;
      print("✅ تم الوصول إلى Firebase Firestore");

      // محاولة جلب البيانات
      print("📥 جاري جلب البيانات من مجموعة 'albums'...");
      QuerySnapshot snapshot = await firestore.collection('albums').get();
      print("✅ تم جلب البيانات بنجاح");

      print("📊 عدد الألبومات المستردة: ${snapshot.docs.length}");

      // طباعة محتوى كل وثيقة
      for (var doc in snapshot.docs) {
        print("📄 محتوى الوثيقة: ${doc.data()}");
      }

      var albums = snapshot.docs.map((doc) {
        var album = {
          'name': (doc['name'] ?? 'بدون اسم').toString(),
          'image': (doc['image'] ?? '').toString(),
        };
        print("🎵 الألبوم: ${album['name']}");
        return album;
      }).toList();

      print("✅ تم تحميل الألبومات بنجاح");
      print("📦 عدد الألبومات في القائمة النهائية: ${albums.length}");
      return albums;
    } catch (e) {
      print("❌ خطأ أثناء تحميل الألبومات: $e");
      print("❌ نوع الخطأ: ${e.runtimeType}");
      print("❌ Stack trace: ${StackTrace.current}");
      return [];
    }
  }

  /// ✅ استعادة حالة التشغيل
  Future<void> _restorePlaybackState() async {
    await _audioService.restorePlaybackState();
    String? lastTitle = _audioService.currentTitleNotifier.value;
    if (lastTitle != null && lastTitle.isNotEmpty) {
      var lastHymn = state.firstWhere(
        (hymn) => hymn.songName == lastTitle,
        orElse: () => HymnsModel(
          id: '',
          songName: '',
          songUrl: '',
          songCategory: '',
          songAlbum: '',
          views: 0,
          dateAdded: DateTime.now(),
        ),
      );
      if (lastHymn.id.isNotEmpty) {
        // تحديث الترنيمة الحالية مع صورة الألبوم بدون زيادة عدد المشاهدات
        await _updateCurrentHymnWithAlbumImage(lastHymn, incrementViews: false);
      }
    }
  }

  HymnsModel? get currentHymn => _currentHymn;

  /// ✅ مسح الترنيمة الحالية
  void clearCurrentHymn() {
    _currentHymn = null;
    emit(List.from(state));
  }

  /// ✅ **جلب قائمة التصنيفات من Firestore كـ Stream**
  Stream<QuerySnapshot> fetchCategoriesStream() {
    try {
      // محاولة جلب البيانات من التخزين المؤقت أولاً
      _cacheService
          .getFromDatabase('categories', 'all')
          .then((cachedCategories) {
        if (cachedCategories != null) {
          // يمكن استخدام البيانات المخزنة مؤقتاً
        }
      });

      return FirebaseFirestore.instance
          .collection('categories')
          .snapshots()
          .map((snapshot) {
        // حفظ البيانات في التخزين المؤقت
        _cacheService.saveToDatabase('categories', 'all', {
          'categories': snapshot.docs.map((doc) => doc.data()).toList(),
        });
        return snapshot;
      });
    } catch (e) {
      print('❌ خطأ في جلب التصنيفات: $e');
      return Stream.empty();
    }
  }

  /// ✅ **جلب قائمة التصنيفات من Firestore كقائمة عادية**
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    return await _hymnsRepository.getCategories();
  }

  /// ✅ **تحديث الترنيمة الحالية مع صورة الألبوم**
  Future<void> _updateCurrentHymnWithAlbumImage(HymnsModel hymn,
      {bool incrementViews = false}) async {
    try {
      // جلب رابط صورة الألبوم من Firestore
      String? albumImageUrl;
      try {
        print('🔍 جاري البحث عن صورة الألبوم: ${hymn.songAlbum}');
        var albumDoc = await FirebaseFirestore.instance
            .collection('albums')
            .where('name', isEqualTo: hymn.songAlbum)
            .get();

        if (albumDoc.docs.isNotEmpty) {
          var albumData = albumDoc.docs.first.data();
          albumImageUrl = albumData['image'] as String?;
          print('✅ تم العثور على صورة الألبوم: $albumImageUrl');
        } else {
          print('⚠️ لم يتم العثور على الألبوم في Firestore');
        }
      } catch (e) {
        print('⚠️ خطأ في جلب صورة الألبوم: $e');
      }

      // تحديث عدد المشاهدات إذا كان مطلوباً
      if (incrementViews) {
        try {
          await _hymnsRepository.incrementViews(hymn.id);
          print('👁️ تم تحديث عدد المشاهدات بنجاح');
        } catch (e) {
          print('❌ خطأ في تحديث عدد المشاهدات: $e');
        }
      }

      // تحديث الترنيمة في القائمة الحالية
      final updatedState = state.map((h) {
        if (h.id == hymn.id) {
          return HymnsModel(
            id: h.id,
            songName: h.songName,
            songUrl: h.songUrl,
            songCategory: h.songCategory,
            songAlbum: h.songAlbum,
            albumImageUrl: albumImageUrl,
            views: incrementViews ? h.views + 1 : h.views,
            dateAdded: h.dateAdded,
            youtubeUrl: h.youtubeUrl,
          );
        }
        return h;
      }).toList();
      emit(updatedState);

      // تحديث الترنيمة الحالية
      _currentHymn = HymnsModel(
        id: hymn.id,
        songName: hymn.songName,
        songUrl: hymn.songUrl,
        songCategory: hymn.songCategory,
        songAlbum: hymn.songAlbum,
        albumImageUrl: albumImageUrl,
        views: incrementViews ? hymn.views + 1 : hymn.views,
        dateAdded: hymn.dateAdded,
        youtubeUrl: hymn.youtubeUrl,
      );
    } catch (e) {
      print('❌ خطأ في تحديث الترنيمة الحالية: $e');
    }
  }

  Future<void> loadHymns() async {
    try {
      var snapshot = await FirebaseFirestore.instance.collection('hymns').get();

      List<HymnsModel> loadedHymns = [];

      for (var doc in snapshot.docs) {
        var data = doc.data();
        String? albumImageUrl = await getAlbumImage(data['songAlbum']);

        loadedHymns.add(HymnsModel(
          id: doc.id,
          songName: data['songName'] ?? 'بدون اسم',
          songUrl: data['songUrl'] ?? '',
          songCategory: data['songCategory'] ?? 'غير محدد',
          songAlbum: data['songAlbum'] ?? 'غير محدد',
          albumImageUrl: albumImageUrl, // ✅ حفظ صورة الألبوم في النموذج
          views: data['views'] ?? 0,
          dateAdded: (data['dateAdded'] as Timestamp).toDate(),
          youtubeUrl: data['youtubeUrl'],
        ));
      }

      hymns = loadedHymns;
      emit(hymns);
    } catch (e) {
      print('حدث خطأ أثناء تحميل الترانيم: $e');
      emit([]);
    }
  }

  Future<String?> getAlbumImage(String albumName) async {
    var albumSnapshot = await FirebaseFirestore.instance
        .collection('albums')
        .where('name', isEqualTo: albumName)
        .get();

    if (albumSnapshot.docs.isNotEmpty) {
      return albumSnapshot.docs.first.data()['image']; // ✅ استرجاع الصورة
    }
    return null;
  }

  @override
  Future<void> close() async {
    await saveLastHymnState();
    await _audioService.dispose();
    super.close();
  }
}
