import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_states.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class VerceCubit extends Cubit<VerceState> {
  String currentVerse = "";
  VerceCubit() : super(VerceInitial());

  static VerceCubit get(context) => BlocProvider.of(context);

  // تعديل دالة fetchVerse لاستخدام بداية اليوم حسب المنطقة الزمنية للمستخدم
  void fetchVerse() async {
    try {
      emit(VerceLoading());

      // الحصول على تاريخ اليوم في بداية اليوم (00:00:00) بالتوقيت المحلي للمستخدم
      DateTime now = DateTime.now();
      DateTime todayStart = DateTime(now.year, now.month, now.day);
      DateTime tomorrowStart = DateTime(now.year, now.month, now.day + 1);

      print("📅 البحث عن آية بتاريخ: ${DateFormat('dd/MM/yyyy').format(now)}");
      print(
          "🕒 نطاق البحث: من ${todayStart.toIso8601String()} إلى ${tomorrowStart.toIso8601String()}");

      // البحث عن آية اليوم باستخدام Timestamp
      var snapshot = await FirebaseFirestore.instance
          .collection('verses')
          .where('dateTimestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('dateTimestamp', isLessThan: Timestamp.fromDate(tomorrowStart))
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        var todayVerseData = snapshot.docs.first.data();

        if (!todayVerseData.containsKey('content')) {
          emit(VerceError("البيانات غير صحيحة"));
          return;
        }

        String verseContent = todayVerseData['content'].toString().trim();
        print("✅ تم استرجاع الآية: $verseContent");

        String arabicVerse = convertNumbersToArabic(verseContent);
        emit(VerceLoaded(arabicVerse));
      } else {
        print("⚠️ لا يوجد آية لليوم الحالي في Firestore");

        // محاولة ثانية باستخدام التنسيق القديم للتاريخ (للتوافق مع البيانات القديمة)
        String todayDateString = "${now.day}/${now.month}/${now.year}";
        var legacySnapshot = await FirebaseFirestore.instance
            .collection('verses')
            .where('date', isEqualTo: todayDateString)
            .limit(1)
            .get();

        if (legacySnapshot.docs.isNotEmpty) {
          var todayVerseData = legacySnapshot.docs.first.data();
          String verseContent = todayVerseData['content'].toString().trim();
          print("✅ تم استرجاع الآية بالتنسيق القديم: $verseContent");

          // تحديث الوثيقة لاستخدام التنسيق الجديد
          await FirebaseFirestore.instance
              .collection('verses')
              .doc(legacySnapshot.docs.first.id)
              .update({
            'dateTimestamp': Timestamp.fromDate(todayStart),
          });

          String arabicVerse = convertNumbersToArabic(verseContent);
          emit(VerceLoaded(arabicVerse));
        } else {
          emit(VerceError("لم يتم العثور على آية لليوم"));
        }
      }
    } catch (e) {
      print("❌ خطأ في استرجاع الآية: $e");
      emit(VerceError("حدث خطأ أثناء تحميل الآية: $e"));
    }
  }

  String convertNumbersToArabic(String input) {
    const englishNumbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    for (int i = 0; i < englishNumbers.length; i++) {
      input = input.replaceAll(englishNumbers[i], arabicNumbers[i]);
    }
    return input;
  }

  // تعديل دالة createVerce لاستخدام بداية اليوم حسب المنطقة الزمنية للمستخدم
  Future<bool> createVerce(
      {required String content, required String date}) async {
    try {
      emit(VerceLoading());

      // تحويل التاريخ من النص إلى كائن DateTime
      List<String> dateParts = date.split('/');
      if (dateParts.length != 3) {
        throw Exception("تنسيق التاريخ غير صحيح");
      }

      int day = int.parse(dateParts[0]);
      int month = int.parse(dateParts[1]);
      int year = int.parse(dateParts[2]);

      // إنشاء كائن DateTime في بداية اليوم (00:00:00) بالتوقيت المحلي
      DateTime dateTime = DateTime(year, month, day);
      Timestamp dateTimestamp = Timestamp.fromDate(dateTime);

      print("📅 إضافة/تحديث آية بتاريخ: $date (${dateTime.toIso8601String()})");

      // التحقق من وجود آية بنفس التاريخ باستخدام Timestamp
      DateTime dayStart = DateTime(dateTime.year, dateTime.month, dateTime.day);
      DateTime nextDayStart =
          DateTime(dateTime.year, dateTime.month, dateTime.day + 1);

      var existingVerses = await FirebaseFirestore.instance
          .collection('verses')
          .where('dateTimestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('dateTimestamp', isLessThan: Timestamp.fromDate(nextDayStart))
          .get();

      if (existingVerses.docs.isNotEmpty) {
        // إذا كانت هناك آية موجودة بالفعل في هذا التاريخ، قم بتحديثها
        await FirebaseFirestore.instance
            .collection('verses')
            .doc(existingVerses.docs.first.id)
            .update({
          'content': content,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print("✅ تم تحديث الآية الموجودة بتاريخ: $date");
      } else {
        // محاولة ثانية باستخدام التنسيق القديم للتاريخ (للتوافق مع البيانات القديمة)
        var legacyVerses = await FirebaseFirestore.instance
            .collection('verses')
            .where('date', isEqualTo: date)
            .get();

        if (legacyVerses.docs.isNotEmpty) {
          // تحديث الآية الموجودة وإضافة حقل التاريخ الجديد
          await FirebaseFirestore.instance
              .collection('verses')
              .doc(legacyVerses.docs.first.id)
              .update({
            'content': content,
            'dateTimestamp': dateTimestamp,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print(
              "✅ تم تحديث الآية الموجودة بالتنسيق القديم وإضافة التنسيق الجديد");
        } else {
          // إضافة آية جديدة بكلا التنسيقين
          await FirebaseFirestore.instance.collection('verses').add({
            'content': content,
            'date': date, // الاحتفاظ بالتنسيق القديم للتوافق
            'dateTimestamp': dateTimestamp, // إضافة التنسيق الجديد
            'createdAt': FieldValue.serverTimestamp(),
          });
          print("✅ تم إضافة آية جديدة بتاريخ: $date");
        }
      }

      currentVerse = content;
      emit(VerceLoaded(currentVerse));
      return true;
    } catch (e) {
      print("❌ خطأ في إضافة/تحديث الآية: $e");
      emit(VerceError("حدث خطأ أثناء حفظ الآية: $e"));
      return false;
    }
  }

  // تعديل دالة ترحيل البيانات القديمة لاستخدام بداية اليوم
  Future<void> migrateOldVerses() async {
    try {
      print("🔄 بدء ترحيل الآيات القديمة...");

      var snapshot = await FirebaseFirestore.instance
          .collection('verses')
          .where('dateTimestamp', isNull: true)
          .get();

      print("📊 عدد الآيات التي تحتاج إلى ترحيل: ${snapshot.docs.length}");

      for (var doc in snapshot.docs) {
        try {
          var data = doc.data();
          String dateStr = data['date'];

          List<String> dateParts = dateStr.split('/');
          if (dateParts.length != 3) {
            print("⚠️ تنسيق تاريخ غير صحيح: $dateStr");
            continue;
          }

          int day = int.parse(dateParts[0]);
          int month = int.parse(dateParts[1]);
          int year = int.parse(dateParts[2]);

          // إنشاء كائن DateTime في بداية اليوم (00:00:00) بالتوقيت المحلي
          DateTime dateTime = DateTime(year, month, day);
          Timestamp dateTimestamp = Timestamp.fromDate(dateTime);

          await FirebaseFirestore.instance
              .collection('verses')
              .doc(doc.id)
              .update({
            'dateTimestamp': dateTimestamp,
          });

          print("✅ تم ترحيل الآية بتاريخ: $dateStr");
        } catch (e) {
          print("❌ خطأ في ترحيل الآية ${doc.id}: $e");
        }
      }

      print("✅ اكتمل ترحيل الآيات القديمة");
    } catch (e) {
      print("❌ خطأ في عملية الترحيل: $e");
    }
  }
}
