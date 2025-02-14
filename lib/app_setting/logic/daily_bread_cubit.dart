import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_model.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_states.dart';
import 'dart:convert';

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
}
