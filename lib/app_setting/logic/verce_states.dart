abstract class VerceState {}

class VerceInitial extends VerceState {}

class VerceLoaded extends VerceState {
  final String verse;
  VerceLoaded(this.verse);
}

class VerceError extends VerceState {
  final String message;
  VerceError(this.message);
}

class VerceLoading extends VerceState {} // حالة تحميل الآية
