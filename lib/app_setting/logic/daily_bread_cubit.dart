import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_model.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_states.dart';

class DailyBreadCubit extends Cubit<DailyBreadStates> {
  DailyBreadCubit() : super(InitDailyBreadStates());
  final List<DailyBreadModel> _dailyList = [];
  List<DailyBreadModel> get dailyList => _dailyList;
  void creatDaily({required String title}) {
    DailyBreadModel newItem = DailyBreadModel(id: 0, titel: title);
    _dailyList.insert(0, newItem);
    emit(CreatDailyBreadSuccessStates());
  }

  void editDailyBread(DailyBreadModel dailyBreadModel, String newTitle) {
    if (dailyBreadModel.titel != newTitle) {
      dailyBreadModel.titel = newTitle;
    }
    emit(EditDailyBreadStates());
  }

  void deletDailyBread(int index) {
    dailyList.removeAt(index);
    emit(DeleteDailyBreadStates());
  }

  void fetchDailyBread() async {
    try {
      var now = DateTime.now();

      var snapshot = await FirebaseFirestore.instance
          .collection('ourDailyBread')
          .orderBy('date', descending: true) // 👈 ترتيب بدل فلترة
          .get();

      var docs = snapshot.docs.where((doc) {
        var date = (doc['date'] as Timestamp).toDate();
        var endDate = (doc['endDate'] as Timestamp).toDate();
        return now.isAfter(date) && now.isBefore(endDate);
      }).toList();

      if (docs.isNotEmpty) {
        var data = docs.first.data();
        emit(DailyBreadLoaded(data['content'] ?? "لا يوجد خبز يومي اليوم"));
      } else {
        emit(DailyBreadError("لا يوجد خبز يومي متاح"));
      }
    } catch (e) {
      emit(DailyBreadError("حدث خطأ أثناء تحميل البيانات"));
    }
  }
}
