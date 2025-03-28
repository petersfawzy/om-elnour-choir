import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/services/cache_service.dart';

class HymnsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CacheService _cacheService = CacheService();

  /// 🟢 **جلب جميع الترانيم مع التحديثات الفورية**
  Stream<List<HymnsModel>> getHymnsStream({String? sortBy, bool descending = false}) {
    try {
      // محاولة جلب البيانات من التخزين المؤقت أولاً
      _cacheService.getFromDatabase('hymns', 'all').then((cachedData) {
        if (cachedData != null && cachedData['hymns'] != null) {
          final List<dynamic> hymnsList = List.from(cachedData['hymns']);
          final hymns = hymnsList.map((hymn) {
            if (hymn is Map) {
              final Map<String, dynamic> hymnData = Map<String, dynamic>.from(hymn);
              return HymnsModel.fromFirestore(hymnData, hymnData['id'] as String);
            }
            throw Exception('Invalid hymn data format');
          }).toList();
          // يمكن استخدام البيانات المخزنة مؤقتاً
        }
      });

      Query query = _firestore.collection('hymns');

      if (sortBy != null) {
        query = query.orderBy(sortBy, descending: descending);
      }

      return query.snapshots().map((snapshot) {
        final hymns = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return HymnsModel.fromFirestore(data, doc.id);
        }).toList();

        // حفظ البيانات في التخزين المؤقت
        _cacheService.saveToDatabase('hymns', 'all', {
          'hymns': hymns.map((h) => h.toJson()).toList(),
        });

        return hymns;
      });
    } catch (e) {
      print('❌ خطأ في جلب الترانيم: $e');
      return Stream.empty();
    }
  }

  /// 🔵 **إضافة ترنيمة جديدة**
  Future<void> addHymn({
    required String songName,
    required String songUrl,
    required String songCategory,
    required String songAlbum,
    String? youtubeUrl,
  }) async {
    try {
      await _firestore.collection('hymns').add({
        'songName': songName,
        'songUrl': songUrl,
        'songCategory': songCategory,
        'songAlbum': songAlbum,
        'views': 0,
        'dateAdded': FieldValue.serverTimestamp(),
        if (youtubeUrl != null) 'youtubeUrl': youtubeUrl,
      });
    } catch (e) {
      print("❌ خطأ أثناء حفظ الترنيمة في Firestore: $e");
    }
  }

  /// 🔵 **تحديث عدد المشاهدات عند تشغيل الترنيمة**
  Future<void> updateViews(String hymnId, int currentViews) async {
    final docRef = _firestore.collection('hymns').doc(hymnId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final newViews = (snapshot.data()?['views'] ?? 0) + 1;
      transaction.update(docRef, {'views': newViews});
    });
  }

  /// 🔴 **حذف ترنيمة**
  Future<void> deleteHymn(String hymnId) async {
    try {
      await _firestore.collection('hymns').doc(hymnId).delete();

      // تحديث التخزين المؤقت
      final cachedData = await _cacheService.getFromDatabase('hymns', 'all');
      if (cachedData != null && cachedData['hymns'] != null) {
        final List<dynamic> hymnsList = List.from(cachedData['hymns']);
        final hymns = hymnsList.map((hymn) {
          if (hymn is Map) {
            final Map<String, dynamic> hymnData = Map<String, dynamic>.from(hymn);
            return HymnsModel.fromFirestore(hymnData, hymnData['id'] as String);
          }
          throw Exception('Invalid hymn data format');
        }).toList();
        final updatedHymns = hymns.where((hymn) => hymn.id != hymnId).toList();

        await _cacheService.saveToDatabase('hymns', 'all', {
          'hymns': updatedHymns.map((h) => h.toJson()).toList(),
        });
      }
    } catch (e) {
      print('❌ خطأ في حذف الترنيمة: $e');
    }
  }

  /// 🟡 **تحديث معلومات الترنيمة**
  Future<void> updateHymn(String hymnId, Map<String, dynamic> data) async {
    await _firestore.collection('hymns').doc(hymnId).update(data);
  }

  /// ✅ **تحديث عدد المشاهدات**
  Future<void> incrementViews(String hymnId) async {
    try {
      await _firestore.collection('hymns').doc(hymnId).update({'views': FieldValue.increment(1)});

      // تحديث التخزين المؤقت
      final cachedData = await _cacheService.getFromDatabase('hymns', 'all');
      if (cachedData != null && cachedData['hymns'] != null) {
        final List<dynamic> hymnsList = List.from(cachedData['hymns']);
        final hymns = hymnsList.map((hymn) {
          if (hymn is Map) {
            final Map<String, dynamic> hymnData = Map<String, dynamic>.from(hymn);
            return HymnsModel.fromFirestore(hymnData, hymnData['id'] as String);
          }
          throw Exception('Invalid hymn data format');
        }).toList();
        final updatedHymns = hymns.map((hymn) {
          if (hymn.id == hymnId) {
            return HymnsModel(
              id: hymn.id,
              songName: hymn.songName,
              songUrl: hymn.songUrl,
              songCategory: hymn.songCategory,
              songAlbum: hymn.songAlbum,
              views: hymn.views + 1,
              dateAdded: hymn.dateAdded,
              youtubeUrl: hymn.youtubeUrl,
            );
          }
          return hymn;
        }).toList();

        await _cacheService.saveToDatabase('hymns', 'all', {
          'hymns': updatedHymns.map((h) => h.toJson()).toList(),
        });
      }
    } catch (e) {
      print('❌ خطأ في تحديث عدد المشاهدات: $e');
    }
  }

  /// ✅ **جلب قائمة التصنيفات من Firestore**
  Stream<QuerySnapshot> getCategoriesStream() {
    try {
      // محاولة جلب البيانات من التخزين المؤقت أولاً
      _cacheService.getFromDatabase('categories', 'all').then((cachedData) {
        if (cachedData != null && cachedData['categories'] != null) {
          // يمكن استخدام البيانات المخزنة مؤقتاً
        }
      });

      return _firestore.collection('categories').snapshots().map((snapshot) {
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
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      print("🔄 جاري تحميل التصنيفات...");
      
      // التحقق من حالة الاتصال بـ Firebase
      print("🔍 التحقق من حالة Firebase...");
      var firestore = FirebaseFirestore.instance;
      print("✅ تم الوصول إلى Firebase Firestore");
      
      // محاولة جلب البيانات
      print("📥 جاري جلب البيانات من مجموعة 'categories'...");
      QuerySnapshot snapshot = await firestore.collection('categories').get();
      print("✅ تم جلب البيانات بنجاح");
      
      print("📊 عدد التصنيفات المستردة: ${snapshot.docs.length}");
      
      // تحويل البيانات إلى قائمة
      List<Map<String, dynamic>> categories = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'description': data['description'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'hymnCount': data['hymnCount'] ?? 0,
        };
      }).toList();
      
      print("✅ تم تحويل البيانات بنجاح");
      return categories;
    } catch (e) {
      print("❌ خطأ أثناء جلب التصنيفات: $e");
      return [];
    }
  }
}
