import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_states.dart';
// import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'verce_states.dart';

class VerceCubit extends Cubit<VerceStates> {
  String currentVerse = "";
  VerceCubit() : super(VerceInitial());
  static VerceCubit get(context) => BlocProvider.of(context);
  void fetchVerse() async {
    try {
      emit(VerceLoading());

      DateTime now = DateTime.now();
      String todayDate = "${now.day}/${now.month}/${now.year}";

      var snapshot = await FirebaseFirestore.instance
          .collection('verses')
          .where('date', isEqualTo: todayDate)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        String verseContent = snapshot.docs.first['content'];
        // String docId = snapshot.docs.first.id;

        // تحويل الأرقام إلى العربية قبل العرض
        String arabicVerse = convertNumbersToArabic(verseContent);

        emit(VerceLoaded(arabicVerse));
      } else {
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
  // Future<void> fetchLatestVerse() async {
  //   emit(VerceLoading()); // حالة التحميل

  //   try {
  //     var snapshot = await FirebaseFirestore.instance
  //         .collection('verses')
  //         .orderBy('date', descending: true) // جلب أحدث آية
  //         .limit(1)
  //         .get();

  //     if (snapshot.docs.isNotEmpty) {
  //       String latestVerse = snapshot.docs.first['content'];
  //       emit(VerceLoaded(latestVerse)); // إرسال الآية المحملة
  //     } else {
  //       emit(VerceError("لا توجد آيات متاحة."));
  //     }
  //   } catch (e) {
  //     emit(VerceError("حدث خطأ أثناء تحميل الآية."));
  //   }
  // }

  void createVerce({required String title}) {
    currentVerse = title;
    emit(VerceLoaded(currentVerse));
  }
}

// class VerceCubit extends Cubit<VerceStates> {
  // String currentVerse = "";

  // VerceCubit() : super(VerceInitial());

  // static VerceCubit get(context) => BlocProvider.of(context);

//   void createVerce({required String title}) {
//     currentVerse = title;
//     emit(VerceLoaded(currentVerse));
//   }
// }
