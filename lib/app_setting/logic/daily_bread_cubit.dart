import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_states.dart';

class DailyBreadCubit extends Cubit<DailyBreadStates> {
  DailyBreadCubit() : super(InitDailyBreadStates());

  List<Map<String, dynamic>> _cachedDailyItems = []; // ✅ **كاش للبيانات**

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
  Future<void> fetchDailyBread() async {
    try {
      emit(DailyBreadLoading());

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
        }
      }

      if (dailyItems.isNotEmpty) {
        _cachedDailyItems = dailyItems;
        emit(DailyBreadLoaded(dailyItems));
      } else {
        emit(DailyBreadEmptyState());
      }
    } catch (e) {
      emit(DailyBreadError("❌ حدث خطأ أثناء تحميل البيانات"));
    }
  }
}
