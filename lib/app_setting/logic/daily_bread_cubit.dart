import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_states.dart';

class DailyBreadCubit extends Cubit<DailyBreadStates> {
  DailyBreadCubit() : super(InitDailyBreadStates());

  /// ✅ **إضافة عنصر جديد إلى Firestore وقائمة التطبيق**
  Future<void> createDaily({required String content}) async {
    try {
      await FirebaseFirestore.instance.collection('ourDailyBread').add({
        'content': content,
        'date': Timestamp.now(),
        'endDate': Timestamp.fromDate(DateTime.now().add(Duration(days: 1))),
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

  /// ✅ **جلب البيانات من Firestore مع دعم الصورة والصوت**
  Future<void> fetchDailyBread() async {
    try {
      emit(DailyBreadLoading());

      var now = DateTime.now();
      var snapshot = await FirebaseFirestore.instance
          .collection('ourDailyBread')
          .orderBy('date', descending: true)
          .get();

      List<Map<String, dynamic>> dailyItems = [];

      for (var doc in snapshot.docs) {
        var date = (doc['date'] as Timestamp).toDate();
        var endDate = (doc['endDate'] as Timestamp).toDate();

        // ✅ التأكد أن البيانات ما زالت ضمن النطاق الزمني الصحيح
        if (now.isBefore(endDate)) {
          dailyItems.add({
            'id': doc.id,
            'content': doc['content'] ?? "",
            'imageUrl': doc['imageUrl'] ?? "",
            'voiceUrl': doc['voiceUrl'] ?? "",
            'voiceViews': doc['voiceViews'] ?? 0,
          });
        }
      }

      if (dailyItems.isNotEmpty) {
        emit(DailyBreadLoaded(dailyItems));
      } else {
        emit(DailyBreadEmptyState()); // ✅ حالة خاصة عند عدم وجود بيانات
      }
    } catch (e) {
      emit(DailyBreadError("❌ حدث خطأ أثناء تحميل البيانات"));
    }
  }
}
