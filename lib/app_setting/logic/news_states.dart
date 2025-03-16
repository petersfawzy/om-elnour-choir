abstract class NewsStates {}

class InitNewsStates extends NewsStates {}

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
