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

  /// ✅ **جلب البيانات من Firestore لليوم الحالي فقط وترتيبها من الأقدم للأحدث**
  Future<void> fetchCopticCalendar() async {
    try {
      emit(CopticCalendarLoadingState());

      String todayDate = DateFormat('d/M/yyyy').format(DateTime.now());
      print("📆 اليوم الحالي: $todayDate");

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
