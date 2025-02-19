class DailyBreadStates {}

class InitDailyBreadStates extends DailyBreadStates {}

class CreatDailyBreadSuccessStates extends DailyBreadStates {}

class EditDailyBreadStates extends DailyBreadStates {}

class DeleteDailyBreadStates extends DailyBreadStates {}

class SortState extends DailyBreadStates {}

class DailyBreadLoading extends DailyBreadStates {}

class DailyBreadLoaded extends DailyBreadStates {
  final String breadText;
  DailyBreadLoaded(this.breadText);
}

class DailyBreadError extends DailyBreadStates {
  final String message;
  DailyBreadError(this.message);
}
