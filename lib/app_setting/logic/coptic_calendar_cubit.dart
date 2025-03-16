import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_states.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_model.dart';

class CopticCalendarCubit extends Cubit<CopticCalendarStates> {
  CopticCalendarCubit() : super(InitCopticCalendarStates());

  List<CopticCalendarModel> _copticCal = [];

  List<CopticCalendarModel> get copticCal => _copticCal;

  /// ✅ **إضافة حدث جديد إلى Firestore**
  Future<void> createCal(
      {required String content, required DateTime date}) async {
    try {
      String formattedDate = DateFormat('d/M/yyyy').format(date);

      var docRef =
          await FirebaseFirestore.instance.collection('copticCalendar').add({
        'content': content,
        'date': formattedDate, // ✅ تخزين التاريخ كنص بنفس تنسيق Firestore
        'dateAdded': Timestamp.now(),
      });

      _copticCal.insert(
          0,
          CopticCalendarModel(
              id: docRef.id, content: content, date: formattedDate));

      emit(CreateCopticCalendarSuccessState());
    } catch (e) {
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

      emit(DeleteCopticCalendarSuccessState());
    } catch (e) {
      emit(CopticCalendarErrorState("❌ حدث خطأ أثناء حذف البيانات"));
    }
  }

  /// ✅ **جلب البيانات من Firestore لليوم الحالي فقط**
  Future<void> fetchCopticCalendar() async {
    try {
      emit(CopticCalendarLoadingState());

      String todayDate = DateFormat('d/M/yyyy').format(DateTime.now());
      print("📆 اليوم الحالي: $todayDate");

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

        print("📆 ${data['date']} - ${data['content']}");

        copticCalendarItems.add(CopticCalendarModel(
          id: doc.id,
          content: data['content'],
          date: data['date'],
        ));
      }

      print("✅ عدد العناصر بعد الفلترة: ${copticCalendarItems.length}");

      if (copticCalendarItems.isNotEmpty) {
        emit(CopticCalendarLoadedState(copticCalendarItems));
      } else {
        emit(CopticCalendarEmptyState());
      }
    } catch (e) {
      print("❌ خطأ أثناء جلب البيانات: $e");
      emit(CopticCalendarErrorState("❌ حدث خطأ أثناء تحميل البيانات"));
    }
  }
}
