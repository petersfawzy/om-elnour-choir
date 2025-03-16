import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_states.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerceCubit extends Cubit<VerceState> {
  String currentVerse = "";
  VerceCubit() : super(VerceInitial());

  static VerceCubit get(context) => BlocProvider.of(context);

  void fetchVerse() async {
    try {
      emit(VerceLoading());

      String todayDate =
          "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
      print("📅 البحث عن آية بتاريخ: $todayDate");

      var snapshot = await FirebaseFirestore.instance
          .collection('verses')
          .where('date', isEqualTo: todayDate) // ✅ جلب فقط آية اليوم
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
        emit(VerceError("لم يتم العثور على آية لليوم"));
      }
    } catch (e) {
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

  void createVerce({required String title}) {
    currentVerse = title;
    emit(VerceLoaded(currentVerse));
  }
}
