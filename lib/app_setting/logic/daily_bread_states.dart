abstract class DailyBreadStates {}

class InitDailyBreadStates extends DailyBreadStates {}

class DailyBreadLoading extends DailyBreadStates {}

class DailyBreadLoaded extends DailyBreadStates {
  final List<Map<String, dynamic>> dailyItems;
  DailyBreadLoaded(this.dailyItems);
}

class DailyBreadError extends DailyBreadStates {
  final String message;
  DailyBreadError(this.message);
}

class CreateDailyBreadSuccessState extends DailyBreadStates {}

class DailyBreadEmptyState extends DailyBreadStates {}
