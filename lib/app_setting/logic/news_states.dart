abstract class NewsStates {}

class InitNewsStates extends NewsStates {}

// Loading state
class NewsLoadingState extends NewsStates {}

// Loaded state with news data
class NewsLoadedState extends NewsStates {
  final List<Map<String, dynamic>> news;

  NewsLoadedState(this.news);
}

// Error state
class NewsErrorState extends NewsStates {
  final String error;

  NewsErrorState({required this.error});
}

class CreatNewsSuccessStates extends NewsStates {}

class CreatNewsFailedStates extends NewsStates {
  final String error;
  CreatNewsFailedStates({required this.error});
}

class EditNewsStates extends NewsStates {}

class EditNewsFailedStates extends NewsStates {
  final String error;
  EditNewsFailedStates({required this.error});
}

class DeleteNewsStates extends NewsStates {}

class DeleteNewsFailedStates extends NewsStates {
  final String error;
  DeleteNewsFailedStates({required this.error});
}
