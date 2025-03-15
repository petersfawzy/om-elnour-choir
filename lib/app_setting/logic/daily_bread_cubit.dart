import 'dart:io'; // ✅ استيراد `Platform` لمعرفة النظام
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_states.dart';

class DailyBreadCubit extends Cubit<DailyBreadStates> {
  DailyBreadCubit() : super(InitDailyBreadStates());

  List<Map<String, dynamic>> _cachedDailyItems = []; // ✅ **كاش للبيانات**

  /// ✅ **إضافة عنصر جديد إلى Firestore وقائمة التطبيق**
  Future<void> createDaily(
      {required String content, required DateTime date}) async {
    try {
      await FirebaseFirestore.instance.collection('ourDailyBread').add({
        'content': content,
        'date':
            Timestamp.fromDate(date), // ✅ استخدم التاريخ الذي اختاره المستخدم
        'endDate': Timestamp.fromDate(date.add(const Duration(days: 1))),
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

  Future<void> fetchDailyBread() async {
    try {
      emit(DailyBreadLoading());

      // ✅ استخدام البيانات المخزنة إن وجدت
      if (_cachedDailyItems.isNotEmpty) {
        emit(DailyBreadLoaded(_cachedDailyItems));
        return;
      }

      // ✅ تحويل تاريخ اليوم إلى UTC بدون توقيت
      var now = DateTime.now().toUtc();
      var todayDate = DateTime.utc(now.year, now.month, now.day);

      print("📲 النظام الحالي: ${Platform.operatingSystem}");
      print("⏳ الآن (UTC): $now");
      print("📆 اليوم بدون توقيت (UTC): $todayDate");

      var snapshot = await FirebaseFirestore.instance
          .collection('ourDailyBread')
          .orderBy('date', descending: true)
          .get();

      List<Map<String, dynamic>> dailyItems = [];

      print("🔥 البيانات القادمة من Firestore:");
      for (var doc in snapshot.docs) {
        var data = doc.data();

        if (!data.containsKey('date') || !data.containsKey('endDate')) {
          print("⚠️ البيانات غير صحيحة، لا تحتوي على `date` أو `endDate`");
          continue;
        }

        DateTime startDate = (data['date'] as Timestamp).toDate().toUtc();
        DateTime endDate = (data['endDate'] as Timestamp).toDate().toUtc();

        startDate =
            DateTime.utc(startDate.year, startDate.month, startDate.day);
        endDate = DateTime.utc(endDate.year, endDate.month, endDate.day);

        print(
            "📆 نص متاح من ${startDate.toIso8601String()} إلى ${endDate.toIso8601String()}");

        if (todayDate.isAtSameMomentAs(startDate) ||
            (todayDate.isAfter(startDate) &&
                todayDate.isBefore(endDate.add(const Duration(days: 1))))) {
          dailyItems.add({
            'id': doc.id,
            'content': data['content'] ?? "",
            'imageUrl': data['imageUrl'] ?? "",
            'voiceUrl': data['voiceUrl'] ?? "",
            'voiceViews': data['voiceViews'] ?? 0,
          });
        }
      }

      print("✅ عدد العناصر بعد الفلترة: ${dailyItems.length}");

      if (dailyItems.isNotEmpty) {
        _cachedDailyItems = dailyItems; // ✅ **تخزين البيانات للكاش**
        emit(DailyBreadLoaded(dailyItems));
      } else {
        emit(DailyBreadEmptyState());
      }
    } catch (e) {
      print("❌ خطأ أثناء جلب البيانات: $e");
      emit(DailyBreadError("❌ حدث خطأ أثناء تحميل البيانات"));
    }
  }
}
