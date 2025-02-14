import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_states.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CopticCalendarCubit extends Cubit<CopticCalendarStates> {
  CopticCalendarCubit() : super(InitCopticCalendarStates());

  final List<CopticCalendarModel> _copticCal = [];

  List<CopticCalendarModel> get copticCal => _copticCal;
  void creatCal({required String title}) {
    CopticCalendarModel newItem = CopticCalendarModel(id: 0, titel: title);
    _copticCal.insert(0, newItem);
    emit(CreatCopticCalendarSuccessStates());
  }

  void editCopticCalendar(
      CopticCalendarModel dailyBreadModel, String newTitle) {
    if (dailyBreadModel.titel != newTitle) {
      dailyBreadModel.titel = newTitle;
    }
    emit(EditCopticCalendarStates());
  }

  void deletCopticCalendar(int index) {
    copticCal.removeAt(index);
    emit(DeletCopticCalendarStates());
  }
}
