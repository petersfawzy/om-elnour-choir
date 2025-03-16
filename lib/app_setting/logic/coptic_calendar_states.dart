import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_model.dart';

abstract class CopticCalendarStates {}

class InitCopticCalendarStates extends CopticCalendarStates {}

class CopticCalendarLoadingState extends CopticCalendarStates {}

class CreateCopticCalendarSuccessState extends CopticCalendarStates {}

class EditCopticCalendarSuccessState extends CopticCalendarStates {}

class DeleteCopticCalendarSuccessState extends CopticCalendarStates {}

class CopticCalendarLoadedState extends CopticCalendarStates {
  final List<CopticCalendarModel> copticCalendarItems;
  CopticCalendarLoadedState(this.copticCalendarItems);
}

class CopticCalendarEmptyState extends CopticCalendarStates {}

class CopticCalendarErrorState extends CopticCalendarStates {
  final String error;
  CopticCalendarErrorState(this.error);
}
