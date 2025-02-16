import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_states.dart';

class VerceCubit extends Cubit<VerceStates> {
  String currentVerse = "";

  VerceCubit() : super(VerceInitial());

  static VerceCubit get(context) => BlocProvider.of(context);

  void createVerce({required String title}) {
    currentVerse = title;
    emit(VerceLoaded(currentVerse));
  }
}
