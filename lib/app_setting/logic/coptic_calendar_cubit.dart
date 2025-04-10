import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_states.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_model.dart';

class CopticCalendarCubit extends Cubit<CopticCalendarStates> {
  CopticCalendarCubit() : super(InitCopticCalendarStates());

  List<CopticCalendarModel> _copticCal = [];

  // مفاتيح التخزين المؤقت
  static const String _cacheKey = 'coptic_calendar_cache';
  static const String _cacheDateKey = 'coptic_calendar_cache_date';
  static const String _lastUpdateKey = 'coptic_calendar_last_update';

  List<CopticCalendarModel> get copticCal => _copticCal;

  /// ✅ **إضافة حدث جديد إلى Firestore**
  Future<void> createCal(
      {required String content, required DateTime date}) async {
    try {
      String formattedDate = DateFormat('d/M/yyyy').format(date);
      Timestamp timestamp = Timestamp.now();

      var docRef =
          await FirebaseFirestore.instance.collection('copticCalendar').add({
        'content': content,
        'date': formattedDate, // ✅ تخزين التاريخ كنص بنفس تنسيق Firestore
        'dateAdded': timestamp,
      });

      print("✅ تم إضافة حدث جديد بنجاح: $content في تاريخ $formattedDate");
      print("🕒 وقت الإضافة: ${timestamp.toDate()}");

      _copticCal.insert(
          0,
          CopticCalendarModel(
              id: docRef.id,
              content: content,
              date: formattedDate,
              dateAdded: timestamp));

      // تحديث الكاش بعد الإضافة
      if (_isCurrentDay(formattedDate)) {
        await _updateCache(_copticCal);
      }

      emit(CreateCopticCalendarSuccessState());
    } catch (e) {
      print("❌ خطأ أثناء إضافة حدث جديد: $e");
      emit(CopticCalendarErrorState("❌ حدث خطأ أثناء إضافة البيانات"));
    }
  }

  /// ✅ **تعديل حدث في Firestore**
  Future<void> editCopticCalendar(String docId, String newContent) async {
    try {
      await FirebaseFirestore.instance
          .collection('copticCalendar')
          .doc(docId)
          .update({
        'content': newContent,
      });

      // تحديث القائمة المحلية
      int index = _copticCal.indexWhere((item) => item.id == docId);
      if (index != -1) {
        var updatedItem = CopticCalendarModel(
          id: _copticCal[index].id,
          content: newContent,
          date: _copticCal[index].date,
          dateAdded: _copticCal[index].dateAdded,
        );
        _copticCal[index] = updatedItem;

        // تحديث الكاش
        await _updateCache(_copticCal);
      }

      emit(EditCopticCalendarSuccessState());
    } catch (e) {
      emit(CopticCalendarErrorState("❌ حدث خطأ أثناء تعديل البيانات"));
    }
  }

  /// ✅ **حذف حدث من Firestore**
  Future<void> deleteCopticCalendar(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('copticCalendar')
          .doc(docId)
          .delete();

      _copticCal.removeWhere((item) => item.id == docId);

      // تحديث الكاش بعد الحذف
      await _updateCache(_copticCal);

      emit(DeleteCopticCalendarSuccessState());
    } catch (e) {
      emit(CopticCalendarErrorState("❌ حدث خطأ أثناء حذف البيانات"));
    }
  }

  /// ✅ **جلب البيانات من Firestore لليوم الحالي فقط وترتيبها من الأقدم للأحدث**
  Future<void> fetchCopticCalendar() async {
    try {
      emit(CopticCalendarLoadingState());

      String todayDate = DateFormat('d/M/yyyy').format(DateTime.now());
      print("📆 اليوم الحالي: $todayDate");

      // محاولة تحميل البيانات من الكاش أولاً
      bool loadedFromCache = await _loadFromCache(todayDate);

      if (loadedFromCache) {
        print("✅ تم تحميل البيانات من الكاش");
        if (_copticCal.isNotEmpty) {
          emit(CopticCalendarLoadedState(_copticCal));
        } else {
          emit(CopticCalendarEmptyState());
        }

        // تحقق من الحاجة للتحديث في الخلفية
        _checkForBackgroundUpdate(todayDate);
        return;
      }

      // إذا لم يتم تحميل البيانات من الكاش، قم بتحميلها من Firestore
      await _fetchFromFirestore(todayDate);
    } catch (e) {
      print("❌ خطأ أثناء جلب البيانات: $e");
      emit(CopticCalendarErrorState("❌ حدث خطأ أثناء تحميل البيانات"));
    }
  }

  /// تحميل البيانات من Firestore
  Future<void> _fetchFromFirestore(String todayDate) async {
    try {
      // التحقق من وجود حقل dateAdded في المستندات
      var checkSnapshot = await FirebaseFirestore.instance
          .collection('copticCalendar')
          .where("date", isEqualTo: todayDate)
          .limit(1)
          .get();

      if (checkSnapshot.docs.isNotEmpty) {
        var sampleDoc = checkSnapshot.docs.first.data();
        if (!sampleDoc.containsKey('dateAdded')) {
          print("⚠️ حقل dateAdded غير موجود في بعض المستندات. سيتم تحديثها.");
          // يمكن إضافة منطق هنا لتحديث المستندات القديمة بإضافة حقل dateAdded
        }
      }

      // جلب البيانات مع الترتيب
      var snapshot = await FirebaseFirestore.instance
          .collection('copticCalendar')
          .where("date", isEqualTo: todayDate)
          .get();

      List<CopticCalendarModel> copticCalendarItems = [];

      print("🔥 البيانات القادمة من Firestore:");
      for (var doc in snapshot.docs) {
        var data = doc.data();

        if (!data.containsKey('date') || !data.containsKey('content')) {
          print("⚠️ البيانات غير صحيحة، لا تحتوي على `date` أو `content`");
          continue;
        }

        // التحقق من وجود حقل dateAdded
        Timestamp dateAdded;
        if (data.containsKey('dateAdded') && data['dateAdded'] != null) {
          dateAdded = data['dateAdded'] as Timestamp;
        } else {
          // إذا لم يكن موجودًا، استخدم قيمة افتراضية قديمة
          dateAdded = Timestamp.fromDate(DateTime(2000));
          // يمكن تحديث المستند هنا بإضافة حقل dateAdded
        }

        print(
            "📆 ${data['date']} - ${data['content']} - ${dateAdded.toDate()}");

        copticCalendarItems.add(CopticCalendarModel(
          id: doc.id,
          content: data['content'],
          date: data['date'],
          dateAdded: dateAdded,
        ));
      }

      // ترتيب العناصر من الأقدم للأحدث يدويًا
      copticCalendarItems.sort((a, b) {
        if (a.dateAdded == null && b.dateAdded == null) return 0;
        if (a.dateAdded == null) return -1;
        if (b.dateAdded == null) return 1;
        return a.dateAdded!.compareTo(b.dateAdded!);
      });

      print("✅ عدد العناصر بعد الفلترة: ${copticCalendarItems.length}");
      for (var item in copticCalendarItems) {
        print(
            "🔄 ترتيب العناصر: ${item.content} - ${item.dateAdded?.toDate()}");
      }

      // تحديث القائمة المحلية والكاش
      _copticCal = copticCalendarItems;
      await _updateCache(copticCalendarItems);

      if (copticCalendarItems.isNotEmpty) {
        emit(CopticCalendarLoadedState(copticCalendarItems));
      } else {
        emit(CopticCalendarEmptyState());
      }
    } catch (e) {
      print("❌ خطأ أثناء جلب البيانات من Firestore: $e");
      throw e;
    }
  }

  /// تحميل البيانات من الكاش
  Future<bool> _loadFromCache(String todayDate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDate = prefs.getString(_cacheDateKey);

      // التحقق من أن الكاش يحتوي على بيانات اليوم الحالي
      if (cachedDate != todayDate) {
        print("⚠️ الكاش يحتوي على بيانات ليوم آخر: $cachedDate");
        return false;
      }

      final cachedData = prefs.getString(_cacheKey);
      if (cachedData == null) {
        print("⚠️ لا توجد بيانات في الكاش");
        return false;
      }

      // تحويل البيانات المخزنة إلى قائمة من النماذج
      final List<dynamic> decodedData = json.decode(cachedData);
      _copticCal = decodedData.map((item) {
        return CopticCalendarModel(
          id: item['id'],
          content: item['content'],
          date: item['date'],
          dateAdded: item['dateAdded'] != null
              ? Timestamp.fromMillisecondsSinceEpoch(item['dateAdded'])
              : null,
        );
      }).toList();

      return true;
    } catch (e) {
      print("❌ خطأ أثناء تحميل البيانات من الكاش: $e");
      return false;
    }
  }

  /// تحديث الكاش بالبيانات الجديدة
  Future<void> _updateCache(List<CopticCalendarModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayDate = DateFormat('d/M/yyyy').format(DateTime.now());

      // تحويل النماذج إلى قائمة من الخرائط
      final List<Map<String, dynamic>> itemsToCache = items.map((item) {
        return {
          'id': item.id,
          'content': item.content,
          'date': item.date,
          'dateAdded': item.dateAdded?.millisecondsSinceEpoch,
        };
      }).toList();

      // تخزين البيانات في الكاش
      await prefs.setString(_cacheKey, json.encode(itemsToCache));
      await prefs.setString(_cacheDateKey, todayDate);
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);

      print("✅ تم تحديث الكاش بنجاح: ${items.length} عناصر");
    } catch (e) {
      print("❌ خطأ أثناء تحديث الكاش: $e");
    }
  }

  /// التحقق من الحاجة للتحديث في الخلفية
  Future<void> _checkForBackgroundUpdate(String todayDate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // تحديث البيانات إذا مر أكثر من ساعة على آخر تحديث
      if (now - lastUpdate > 3600000) {
        // 3600000 ميلي ثانية = ساعة واحدة
        print("🔄 مر أكثر من ساعة على آخر تحديث، جاري التحديث في الخلفية...");
        await _fetchFromFirestore(todayDate);

        // إذا كانت البيانات قد تغيرت، قم بإصدار حالة جديدة
        if (_copticCal.isNotEmpty) {
          emit(CopticCalendarLoadedState(_copticCal));
        } else {
          emit(CopticCalendarEmptyState());
        }
      }
    } catch (e) {
      print("⚠️ خطأ أثناء التحقق من التحديث في الخلفية: $e");
      // لا نقوم بإصدار حالة خطأ هنا لأن هذا تحديث في الخلفية
    }
  }

  /// التحقق مما إذا كان التاريخ هو اليوم الحالي
  bool _isCurrentDay(String date) {
    final todayDate = DateFormat('d/M/yyyy').format(DateTime.now());
    return date == todayDate;
  }

  /// التحقق من تغير اليوم وتحديث البيانات إذا لزم الأمر
  Future<void> checkForDayChange() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDate = prefs.getString(_cacheDateKey);
      final todayDate = DateFormat('d/M/yyyy').format(DateTime.now());

      if (cachedDate != todayDate) {
        print(
            "📅 تغير اليوم من $cachedDate إلى $todayDate، جاري تحديث البيانات...");
        await fetchCopticCalendar();
      }
    } catch (e) {
      print("❌ خطأ أثناء التحقق من تغير اليوم: $e");
    }
  }
}
