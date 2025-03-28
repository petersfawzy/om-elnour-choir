import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';

abstract class HymnsState {}

class HymnsInitial extends HymnsState {}

class HymnsLoading extends HymnsState {}

class HymnsLoaded extends HymnsState {
  final List<HymnsModel> hymns;
  HymnsLoaded(this.hymns);
}

class HymnsError extends HymnsState {
  final String message;
  HymnsError(this.message);
}
