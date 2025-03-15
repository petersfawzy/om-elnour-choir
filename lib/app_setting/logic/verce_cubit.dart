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
          .get(const GetOptions(
              source: Source.cache)) // ✅ أولًا، جلب البيانات من الكاش
          .onError((error, stackTrace) {
        print("⚠️ البيانات غير متاحة في الكاش، جاري جلبها من Firestore...");
        return FirebaseFirestore.instance
            .collection('verses')
            .get(); // ✅ إذا لم تكن في الكاش، يتم جلبها من Firestore
      });

      Map<String, dynamic>? todayVerseData;

      for (var doc in snapshot.docs) {
        if (doc['date'].toString().trim() == todayDate.trim()) {
          todayVerseData = doc.data();
          break;
        }
      }

      if (todayVerseData != null) {
        print("✅ تم العثور على الآية لليوم الحالي!");

        if (!todayVerseData.containsKey('content')) {
          emit(VerceError("البيانات غير صحيحة"));
          return;
        }

        String verseContent = todayVerseData['content'];
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
