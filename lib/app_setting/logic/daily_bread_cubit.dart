import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_states.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DailyBreadCubit extends Cubit<DailyBreadStates> {
  DailyBreadCubit() : super(InitDailyBreadStates()) {
    // Load cached data when the cubit is created
    _loadCachedDailyBread();
  }

  List<Map<String, dynamic>> _cachedDailyItems = []; // ✅ **كاش للبيانات**
  final String _cacheKey = 'cached_daily_bread'; // مفتاح التخزين المؤقت
  final String _lastUpdateDateKey =
      'last_daily_bread_update'; // مفتاح تاريخ آخر تحديث

  /// ✅ **تحميل البيانات المخزنة مؤقتًا**
  Future<void> _loadCachedDailyBread() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);
      final lastUpdateDateStr = prefs.getString(_lastUpdateDateKey);

      // التحقق مما إذا كان اليوم جديدًا
      bool isNewDay = true;
      if (lastUpdateDateStr != null) {
        final lastUpdateDate = DateTime.parse(lastUpdateDateStr);
        final today = DateTime.now();
        isNewDay = lastUpdateDate.year != today.year ||
            lastUpdateDate.month != today.month ||
            lastUpdateDate.day != today.day;
      }

      if (cachedData != null && cachedData.isNotEmpty) {
        print('✅ تم تحميل البيانات من التخزين المؤقت');
        final List<dynamic> decodedData = jsonDecode(cachedData);
        _cachedDailyItems =
            decodedData.map((item) => Map<String, dynamic>.from(item)).toList();

        // إرسال البيانات المخزنة مؤقتًا إلى واجهة المستخدم
        if (_cachedDailyItems.isNotEmpty) {
          emit(DailyBreadLoaded(_cachedDailyItems));
        }

        // تحديث البيانات من الخادم إذا كان يوم جديد أو في الخلفية
        if (isNewDay) {
          print('📅 يوم جديد، جاري تحديث الخبز اليومي...');
          fetchDailyBread(useCache: false);
        } else {
          // تحديث البيانات في الخلفية
          fetchDailyBread(useCache: true);
        }
      } else {
        // لا توجد بيانات مخزنة، تحميل من الخادم
        fetchDailyBread();
      }
    } catch (e) {
      print('❌ خطأ في تحميل البيانات المخزنة مؤقتًا: $e');
      // في حالة الخطأ، تحميل من الخادم
      fetchDailyBread();
    }
  }

  /// ✅ **حفظ البيانات في التخزين المؤقت**
  Future<void> _saveToCacheAsync(List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = jsonEncode(data);
      await prefs.setString(_cacheKey, jsonData);

      // حفظ تاريخ آخر تحديث
      final now = DateTime.now();
      await prefs.setString(_lastUpdateDateKey, now.toIso8601String());

      print('✅ تم حفظ البيانات في التخزين المؤقت');
    } catch (e) {
      print('❌ خطأ في حفظ البيانات في التخزين المؤقت: $e');
    }
  }

  /// ✅ **التحقق مما إذا كان اليوم جديدًا**
  Future<bool> _isNewDay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdateDateStr = prefs.getString(_lastUpdateDateKey);

      if (lastUpdateDateStr == null) {
        return true;
      }

      final lastUpdateDate = DateTime.parse(lastUpdateDateStr);
      final today = DateTime.now();

      return lastUpdateDate.year != today.year ||
          lastUpdateDate.month != today.month ||
          lastUpdateDate.day != today.day;
    } catch (e) {
      print('❌ خطأ في التحقق من التاريخ: $e');
      return true; // في حالة الخطأ، نفترض أنه يوم جديد
    }
  }

  /// ✅ **إضافة عنصر جديد إلى Firestore وقائمة التطبيق**
  Future<void> createDaily({
    required String content,
    required DateTime date,
  }) async {
    try {
      DateTime startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
      DateTime endOfDay = startOfDay
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));

      await FirebaseFirestore.instance.collection('ourDailyBread').add({
        'content': content,
        'date': Timestamp.fromDate(startOfDay.toUtc()), // ✅ تخزين بالتوقيت UTC
        'endDate': Timestamp.fromDate(endOfDay.toUtc()), // ✅ تخزين بالتوقيت UTC
        'imageUrl': '',
        'voiceUrl': '',
        'voiceViews': 0,
      });

      fetchDailyBread(); // ✅ إعادة تحميل البيانات بعد الإضافة
      emit(CreateDailyBreadSuccessState());
    } catch (e) {
      emit(DailyBreadError("❌ حدث خطأ أثناء إضافة البيانات"));
    }
  }

  /// ✅ **تعديل البيانات في Firestore**
  Future<void> editDailyBread(String docId, String newContent) async {
    try {
      await FirebaseFirestore.instance
          .collection('ourDailyBread')
          .doc(docId)
          .update({'content': newContent});
      fetchDailyBread(); // ✅ إعادة تحميل البيانات بعد التعديل
    } catch (e) {
      emit(DailyBreadError("❌ حدث خطأ أثناء تعديل البيانات"));
    }
  }

  /// ✅ **حذف عنصر من Firestore**
  Future<void> deleteDailyBread(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('ourDailyBread')
          .doc(docId)
          .delete();
      fetchDailyBread(); // ✅ إعادة تحميل البيانات بعد الحذف
    } catch (e) {
      emit(DailyBreadError("❌ حدث خطأ أثناء حذف البيانات"));
    }
  }

  /// ✅ **جلب البيانات من Firestore**
  Future<void> fetchDailyBread({bool useCache = true}) async {
    try {
      // إذا كان هناك بيانات مخزنة مؤقتًا وطلب استخدام الكاش، نستخدمها أولاً
      if (useCache && _cachedDailyItems.isNotEmpty) {
        emit(DailyBreadLoaded(_cachedDailyItems));
      } else {
        emit(DailyBreadLoading());
      }

      DateTime now = DateTime.now();
      DateTime todayStartLocal =
          DateTime(now.year, now.month, now.day, 0, 0, 0);
      DateTime todayEndLocal =
          DateTime(now.year, now.month, now.day, 23, 59, 59);

      // ✅ تحويل إلى UTC لأن Firestore يخزن التوقيت بـ UTC
      DateTime todayStartUTC = todayStartLocal.toUtc();
      DateTime todayEndUTC = todayEndLocal.toUtc();

      var snapshot = await FirebaseFirestore.instance
          .collection('ourDailyBread')
          .where("date", isLessThanOrEqualTo: Timestamp.fromDate(todayEndUTC))
          .where("endDate",
              isGreaterThanOrEqualTo: Timestamp.fromDate(todayStartUTC))
          .orderBy('date', descending: true)
          .limit(1) // ✅ تعديل: جلب أحدث عنصر واحد فقط
          .get();

      List<Map<String, dynamic>> dailyItems = [];

      for (var doc in snapshot.docs) {
        var data = doc.data();
        if (!data.containsKey('date') || !data.containsKey('endDate')) continue;

        DateTime startDate = (data['date'] as Timestamp).toDate().toUtc();
        DateTime endDate = (data['endDate'] as Timestamp).toDate().toUtc();

        if (startDate.isBefore(todayEndUTC) && endDate.isAfter(todayStartUTC)) {
          dailyItems.add({
            'id': doc.id,
            'content': data['content'] ?? "",
            'imageUrl': data['imageUrl'] ?? "",
            'voiceUrl': data['voiceUrl'] ?? "",
            'voiceViews': data['voiceViews'] ?? 0,
          });
          break; // ✅ تعديل: الخروج من الحلقة بعد إضافة أول عنصر
        }
      }

      if (dailyItems.isNotEmpty) {
        _cachedDailyItems = dailyItems;
        // حفظ البيانات في التخزين المؤقت
        _saveToCacheAsync(dailyItems);
        emit(DailyBreadLoaded(dailyItems));
      } else if (_cachedDailyItems.isNotEmpty) {
        // إذا لم تكن هناك بيانات جديدة ولكن لدينا بيانات مخزنة، نستخدمها
        emit(DailyBreadLoaded(_cachedDailyItems));
      } else {
        emit(DailyBreadEmptyState());
      }
    } catch (e) {
      print('❌ خطأ في جلب البيانات من Firestore: $e');
      // في حالة الخطأ، إذا كان لدينا بيانات مخزنة، نستخدمها
      if (_cachedDailyItems.isNotEmpty) {
        emit(DailyBreadLoaded(_cachedDailyItems));
      } else {
        emit(DailyBreadError("❌ حدث خطأ أثناء تحميل البيانات"));
      }
    }
  }

  /// ✅ **التحقق من وجود تحديثات للبيانات**
  Future<void> checkForUpdates() async {
    try {
      // التحقق مما إذا كان اليوم جديدًا
      bool isNewDay = await _isNewDay();

      if (isNewDay) {
        print('📅 يوم جديد، جاري تحديث الخبز اليومي...');
        // تحميل البيانات من الخادم بدون استخدام الكاش
        await fetchDailyBread(useCache: false);
      } else {
        // تحديث البيانات في الخلفية
        await fetchDailyBread(useCache: true);
      }
    } catch (e) {
      print('❌ خطأ في التحقق من التحديثات: $e');
    }
  }
}
