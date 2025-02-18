abstract class VerceStates {}

class VerceInitial extends VerceStates {}

class VerceLoaded extends VerceStates {
  final String verse;
  VerceLoaded(this.verse);
}

class VerceError extends VerceStates {
  final String errorMessage;
  VerceError(this.errorMessage);
}
