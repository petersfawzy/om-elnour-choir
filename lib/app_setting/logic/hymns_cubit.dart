import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymn_repository.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_state.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:om_elnour_choir/services/cache_service.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class HymnsCubit extends Cubit<List<HymnsModel>> {
  final HymnsRepository _hymnsRepository;
  final MyAudioService _audioService;
  final CacheService _cacheService = CacheService();
  MyAudioService get audioService => _audioService;

  // إضافة متغيرات جديدة للفلترة
  String _sortBy = 'dateAdded';
  bool _descending = true;
  String? _filterCategory;
  String? _filterAlbum;

  // إضافة getters للوصول إلى حالة الفلتر الحالية
  String get sortBy => _sortBy;
  bool get descending => _descending;
  String? get filterCategory => _filterCategory;
  String? get filterAlbum => _filterAlbum;

  HymnsModel? _currentHymn;
  List<HymnsModel> _favorites = [];
  List<HymnsModel> _allHymns = []; // قائمة الترانيم الأصلية
  List<HymnsModel> _filteredHymns = []; // قائمة الترانيم بعد التصفية

  // Add a flag to prevent duplicate view increments
  bool _isViewIncrementInProgress = false;

  // إضافة استدعاء لتحميل الترانيم الشائعة عند بدء التطبيق
  HymnsCubit(this._hymnsRepository, this._audioService) : super([]) {
    fetchHymns();
    _loadFilterPreferences();

    // تسجيل callback لزيادة عدد المشاهدات عند تغيير الترنيمة
    _audioService.registerHymnChangedCallback((index, title) {
      // البحث عن الترنيمة في القائمة المفلترة
      if (index >= 0 && index < _filteredHymns.length) {
        final hymn = _filteredHymns[index];
        // زيادة عدد المشاهدات
        _hymnsRepository.incrementViews(hymn.id);
        print('📊 تم زيادة عدد مشاهدات الترنيمة: ${hymn.songName}');
      }
    });

    // تحميل الترانيم الشائعة مسبقًا فور بدء التطبيق
    _audioService.preloadPopularHymns();
  }

  // حفظ تفضيلات الفلتر
  Future<void> _saveFilterPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

      await prefs.setString('filter_sortBy_$userId', _sortBy);
      await prefs.setBool('filter_descending_$userId', _descending);
      await prefs.setString('filter_category_$userId', _filterCategory ?? '');
      await prefs.setString('filter_album_$userId', _filterAlbum ?? '');
      print('✅ تم حفظ تفضيلات الفلتر للمستخدم: $userId');
    } catch (e) {
      print('❌ خطأ في حفظ تفضيلات الفلتر: $e');
    }
  }

  // استعادة تفضيلات الفلتر
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
          '✅ تم استعادة تفضيلات الفلتر للمستخدم $userId: $_sortBy, $_descending, $_filterCategory, $_filterAlbum');
    } catch (e) {
      print('❌ خطأ في استعادة تفضيلات الفلتر: $e');
    }
  }

  /// ✅ تحميل الترانيم من Firestore
  Future<void> fetchHymns() async {
    try {
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
            views: data['views'] ?? 0,
            dateAdded: (data['dateAdded'] as Timestamp).toDate(),
            youtubeUrl: data['youtubeUrl'],
          );
        }).toList();

        // تطبيق الفلتر الحالي على القائمة الجديدة
        _applyFilters();

        // بعد تحميل الترانيم، نحاول استعادة آخر ت��نيمة
        _restoreLastHymnFromPrefs();
      });
    } catch (e) {
      print('❌ خطأ في جلب الترانيم: $e');
      emit([]);
    }
  }

  // تطبيق الفلاتر على القائمة
  void _applyFilters() {
    try {
      // نسخة من القائمة الأصلية
      _filteredHymns = List.from(_allHymns);

      // تطبيق فلتر التصنيف
      if (_filterCategory != null && _filterCategory!.isNotEmpty) {
        _filteredHymns = _filteredHymns
            .where((hymn) => hymn.songCategory == _filterCategory)
            .toList();
      }

      // تطبيق فلتر الألبوم
      if (_filterAlbum != null && _filterAlbum!.isNotEmpty) {
        _filteredHymns = _filteredHymns
            .where((hymn) => hymn.songAlbum == _filterAlbum)
            .toList();
      }

      // تطبيق الترتيب
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

        // عكس النتيجة إذا كان الترتيب تنازليًا
        return _descending ? -result : result;
      });

      emit(_filteredHymns);
    } catch (e) {
      print('❌ خطأ في تطبيق الفلاتر: $e');
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

  // تعديل دالة playHymn لإضافة تسجيلات إضافية
  // تعديل دالة playHymn لإزالة الإطار من الترنيمة السابقة عند تشغيل ترنيمة جديدة
  Future<void> playHymn(HymnsModel hymn, {bool incrementViews = true}) async {
    try {
      print('🎵 جاري تشغيل الترنيمة: ${hymn.songName} (ID: ${hymn.id})');

      // تحديث الترنيمة الحالية مباشرة
      _currentHymn = hymn;

      // تحديث واجهة المستخدم فورًا لإظهار الترنيمة المحددة داخل إطار
      emit(List.from(state));

      // البحث عن الترنيمة في القائمة
      final index = state.indexWhere((h) => h.id == hymn.id);
      if (index == -1) {
        print('⚠️ لم يتم العثور على الترنيمة في القائمة الحالية');
        return;
      }

      // تشغيل الترنيمة فورًا - هذا سيبدأ التشغيل بينما تستمر العمليات الأخرى
      _audioService.playFromBeginning(index, hymn.songName);

      // تحديث قائمة التشغيل في الخلفية
      Future.microtask(() async {
        final urls = state.map((h) => h.songUrl).toList();
        final titles = state.map((h) => h.songName).toList();
        await _audioService.setPlaylist(urls, titles);
      });

      // زيادة عدد المشاهدات في الخلفية
      if (incrementViews && !_isViewIncrementInProgress) {
        _isViewIncrementInProgress = true;
        Future.microtask(() async {
          try {
            await _hymnsRepository.incrementViews(hymn.id);
            _isViewIncrementInProgress = false;
          } catch (e) {
            print('❌ خطأ في تحديث عدد المشاهدات: $e');
            _isViewIncrementInProgress = false;
          }
        });
      }

      // تحديث صورة الألبوم في الخلفية
      Future.microtask(() async {
        await _updateCurrentHymnWithAlbumImage(hymn, incrementViews: false);
        // حفظ الترنيمة الأخيرة بعد اكتمال التحديث
        saveLastHymnState();
      });
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
      await saveLastHymnState();
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

  // تعديل دالة changeSort لتدعم الفلترة
  Future<void> changeSort(String sortBy, bool descending) async {
    _sortBy = sortBy;
    _descending = descending;

    // إعادة تعيين فلترة التصنيف والألبوم
    _filterCategory = null;
    _filterAlbum = null;

    // حفظ تفضيلات الفلتر
    await _saveFilterPreferences();

    // تطبيق الفلاتر
    _applyFilters();

    print('✅ تم تطبيق الترتيب: $_sortBy، ${_descending ? "تنازلي" : "تصاعدي"}');
  }

  // إضافة دالة لحفظ حالة التشغيل عند إغلاق التطبيق
  Future<void> saveStateOnAppClose() async {
    try {
      print('📱 جاري حفظ حالة التشغيل عند إغلاق التطبيق...');

      // حفظ حالة الترنيمة الحالية
      if (_currentHymn != null) {
        await saveLastHymnState();
      }

      // حفظ حالة مشغل الصوت بشكل صريح
      await _audioService.saveStateOnAppClose();

      print('✅ تم حفظ حالة التشغيل عند إغلاق التطبيق بنجاح');
    } catch (e) {
      print('❌ خطأ في حفظ حالة التشغيل عند إغلاق التطبيق: $e');
    }
  }

  // تعديل دالة saveLastHymnState لتحفظ الموضع بشكل أكثر دقة
  Future<void> saveLastHymnState() async {
    if (_currentHymn == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

      // مسح أي بيانات سابقة للترانيم
      await prefs.remove('lastHymnBasic_$userId');

      // تحويل الترنيمة إلى JSON
      final hymnJson = _currentHymn!.toJson();

      // حفظ معلومات الترنيمة
      await prefs.setString('lastHymn_$userId', jsonEncode(hymnJson));

      // حفظ الموضع الحالي بشكل صريح
      final currentPosition = _audioService.positionNotifier.value.inSeconds;
      await prefs.setInt('lastPosition_$userId', currentPosition);

      // حفظ حالة التشغيل
      await prefs.setBool(
          'wasPlaying_$userId', _audioService.isPlayingNotifier.value);

      print(
          '💾 تم حفظ حالة آخر ترنيمة للمستخدم: $userId، الموضع: $currentPosition ثانية');
    } catch (e) {
      print('❌ خطأ في حفظ حالة آخر ترنيمة: $e');

      // محاولة حفظ المعلومات الأساسية فقط في حالة فشل حفظ الترنيمة كاملة
      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

        // حفظ معرف الترنيمة واسمها فقط
        final basicInfo = {
          'id': _currentHymn!.id,
          'songName': _currentHymn!.songName,
          'songUrl': _currentHymn!.songUrl,
        };

        await prefs.setString('lastHymnBasic_$userId', jsonEncode(basicInfo));

        // حفظ الموضع الحالي
        final currentPosition = _audioService.positionNotifier.value.inSeconds;
        await prefs.setInt('lastPosition_$userId', currentPosition);

        print('💾 تم حفظ المعلومات الأساسية للترنيمة بنجاح');
      } catch (e2) {
        print('❌ فشل حفظ المعلومات الأساسية أيضًا: $e2');
      }
    }
  }

  // تعديل دالة restoreLastHymn لتحسين استعادة حالة التشغيل
  // تعديل دالة restoreLastHymn لمنع التشغيل التلقائي
  Future<void> restoreLastHymn() async {
    try {
      print('🔄 استعادة آخر ترنيمة من HymnsCubit...');

      // لا نقوم باستدعاء audioService.restorePlaybackState() هنا
      // لأنها تُستدعى بالفعل في منشئ MyAudioService

      // بدلاً من ذلك، نقوم فقط بتحديث واجهة المستخدم بناءً على حالة audioService الحالية
      final currentTitle = _audioService.currentTitleNotifier.value;
      final currentIndex = _audioService.currentIndexNotifier.value;

      if (currentTitle != null) {
        print('✅ تم العثور على آخر ترنيمة: $currentTitle');

        // البحث عن الترنيمة في القائمة
        final hymnIndex =
            _filteredHymns.indexWhere((h) => h.songName == currentTitle);
        if (hymnIndex != -1) {
          // تحديث الترنيمة الحالية بدون تشغيلها
          _currentHymn = _filteredHymns[hymnIndex];

          // تحديث واجهة المستخدم
          emit(List.from(_filteredHymns));
        }
      } else {
        print('⚠️ لم يتم العثور على آخر ترنيمة');
      }
    } catch (e) {
      print('❌ خطأ في استعادة آخر ترنيمة: $e');
    }
  }

  /// ✅ استعادة آخر ترنيمة من التخزين المؤقت
  Future<void> _restoreLastHymnFromPrefs() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      final prefs = await SharedPreferences.getInstance();
      final lastHymnJson = prefs.getString('lastHymn_$userId');

      if (lastHymnJson != null) {
        final lastHymn = HymnsModel.fromJson(jsonDecode(lastHymnJson));

        // البحث عن الترنيمة في القائمة الحالية
        final hymnInState = state.firstWhere(
          (h) => h.id == lastHymn.id,
          orElse: () => lastHymn,
        );

        // تحديث الترنيمة الحالية بدون زيادة عدد المشاهدات
        await _updateCurrentHymnWithAlbumImage(hymnInState,
            incrementViews: false);

        // تحديث واجهة المستخدم
        emit(List.from(state));

        print('✅ تم استعادة آخر ترنيمة من التخزين المؤقت للمستخدم: $userId');
      }
    } catch (e) {
      print('❌ خطأ في استعادة آخر ترنيمة من التخزين المؤقت: $e');
    }
  }

  // تعديل دالة toggleFavorite لتعمل مع Firestore
  Future<void> toggleFavorite(HymnsModel hymn) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ يجب تسجيل الدخول لإضافة ترنيمة إلى المفضلة');
        return;
      }

      // التحقق مما إذا كانت الترنيمة موجودة بالفعل في المفضلة
      final favoriteRef = FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: user.uid)
          .where('hymnId', isEqualTo: hymn.id)
          .limit(1);

      final snapshot = await favoriteRef.get();

      if (snapshot.docs.isEmpty) {
        // إضافة إلى المفضلة
        await FirebaseFirestore.instance.collection('favorites').add({
          'userId': user.uid,
          'hymnId': hymn.id,
          'songName': hymn.songName,
          'songUrl': hymn.songUrl,
          'views': hymn.views,
          'dateAdded': FieldValue.serverTimestamp(),
        });
        print('✅ تمت إضافة الترنيمة إلى المفضلة');
      } else {
        // إزالة من المفضلة
        await FirebaseFirestore.instance
            .collection('favorites')
            .doc(snapshot.docs.first.id)
            .delete();
        print('✅ تمت إزالة الترنيمة من المفضلة');
      }

      // تحديث القائمة المحلية
      await loadFavorites();

      // تحديث واجهة المستخدم
      emit(List.from(state));
    } catch (e) {
      print('❌ خطأ في تبديل حالة المفضلة: $e');
    }
  }

  // تحديث دالة loadFavorites لتحميل المفضلة من Firestore
  Future<void> loadFavorites() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _favorites = [];
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: user.uid)
          .get();

      _favorites = snapshot.docs.map((doc) {
        final data = doc.data();
        return HymnsModel(
          id: data['hymnId'] ?? '',
          songName: data['songName'] ?? '',
          songUrl: data['songUrl'] ?? '',
          songCategory: data['songCategory'] ?? '',
          songAlbum: data['songAlbum'] ?? '',
          views: data['views'] ?? 0,
          dateAdded:
              (data['dateAdded'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      print('❌ خطأ في تحميل المفضلة: $e');
      _favorites = [];
    }
  }

  // إضافة دالة للتحقق مما إذا كانت الترنيمة في المفضلة
  Future<bool> isHymnFavorite(String hymnId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final snapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: user.uid)
          .where('hymnId', isEqualTo: hymnId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ خطأ في التحقق من حالة المفضلة: $e');
      return false;
    }
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
          .collection('albums') // Corrected line
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

  // إضافة دالة للحصول على قائمة التصنيفات
  Future<List<String>> getAllCategories() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('categories').get();
      return snapshot.docs.map((doc) => doc['name'] as String).toList();
    } catch (e) {
      print('❌ خطأ في جلب التصنيفات: $e');
      return [];
    }
  }

  // إضافة دالة للحصول على قائمة الألبومات
  Future<List<String>> getAllAlbums() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('albums').get();
      return snapshot.docs.map((doc) => doc['name'] as String).toList();
    } catch (e) {
      print('❌ خطأ في جلب الألبومات: $e');
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
    // تحديث الترنيمة في القائمة الحالية فورًا
    final updatedState = state.map((h) {
      if (h.id == hymn.id) {
        return HymnsModel(
          id: h.id,
          songName: h.songName,
          songUrl: h.songUrl,
          songCategory: h.songCategory,
          songAlbum: h.songAlbum,
          albumImageUrl: h.albumImageUrl,
          views: incrementViews ? h.views + 1 : h.views, // تحديث العدد محليًا
          dateAdded: h.dateAdded,
          youtubeUrl: h.youtubeUrl,
        );
      }
      return h;
    }).toList();
    emit(updatedState);

    // تنفيذ العمليات الثقيلة في الخلفية
    Future.microtask(() async {
      try {
        // تحديث عدد المشاهدات إذا كان مطلوبًا
        if (incrementViews && !_isViewIncrementInProgress) {
          _isViewIncrementInProgress = true;
          _hymnsRepository.incrementViews(hymn.id).then((_) {
            _isViewIncrementInProgress = false;
          }).catchError((e) {
            _isViewIncrementInProgress = false;
          });
        }

        // جلب رابط صورة الألبوم من Firestore
        try {
          final albumDoc = await FirebaseFirestore.instance
              .collection('albums')
              .where('name', isEqualTo: hymn.songAlbum)
              .get();

          if (albumDoc.docs.isNotEmpty) {
            var albumData = albumDoc.docs.first.data();
            String? albumImageUrl = albumData['image'] as String?;

            // تحديث الترنيمة الحالية فقط إذا كانت لا تزال هي نفسها
            if (_currentHymn?.id == hymn.id) {
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

              // تحديث واجهة المستخدم
              emit(List.from(state));
            }
          }
        } catch (e) {
          // تجاهل أخطاء جلب صورة الألبوم
        }
      } catch (e) {
        // تجاهل الأخطاء في العمليات الخلفية
      }
    });
  }

  /// ✅ تحديث نتائج البحث
  void searchHymns(String query) {
    if (query.isEmpty) {
      _filteredHymns = _allHymns; // إذا كان النص فارغًا، أعد القائمة الأصلية
    } else {
      _filteredHymns = _allHymns
          .where((hymn) =>
              hymn.songName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    emit(_filteredHymns); // تحديث الحالة بالنتائج
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

      _allHymns = loadedHymns;
      _filteredHymns = _allHymns;
      emit(_filteredHymns);
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

  // إضافة دالة لمسح بيانات المستخدم عند تسجيل الخروج
  Future<void> clearUserData() async {
    try {
      print('🧹 جاري مسح بيانات المستخدم في HymnsCubit...');

      // مسح بيانات المشغل
      await _audioService.clearUserData();

      // مسح الترنيمة الحالية
      _currentHymn = null;

      // إعادة تعيين القوائم
      _favorites = [];

      // مسح البيانات من SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

      // مسح بيانات الترنيمة الأخيرة
      await prefs.remove('lastHymn_$userId');
      await prefs.remove('lastPosition_$userId');
      await prefs.remove('wasPlaying_$userId');

      // مسح تفضيلات الفلتر
      await prefs.remove('filter_sortBy_$userId');
      await prefs.remove('filter_descending_$userId');
      await prefs.remove('filter_category_$userId');
      await prefs.remove('filter_album_$userId');

      // إعادة تعيين متغيرات الفلتر
      _filterCategory = null;
      _filterAlbum = null;
      _sortBy = 'dateAdded';
      _descending = true;

      // تطبيق الفلاتر بعد إعادة التعيين
      _applyFilters();

      print('✅ تم مسح بيانات المستخدم في HymnsCubit بنجاح');
    } catch (e) {
      print('❌ خطأ في مسح بيانات المستخدم في HymnsCubit: $e');
    }
  }

  @override
  Future<void> close() async {
    await saveLastHymnState();
    await _audioService.dispose();
    super.close();
  }
}
