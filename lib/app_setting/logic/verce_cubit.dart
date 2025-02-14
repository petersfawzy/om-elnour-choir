import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_model.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_states.dart';

class VerceCubit extends Cubit<VerceStates> {
  VerceCubit() : super(InitVerceStates());
  final List<VerceModel> _verceList = [];
  List<VerceModel> get verceList => _verceList;
  void creatVerce({required String title}) {
    VerceModel newItem = VerceModel(id: 0, titel: title);
    _verceList.insert(0, newItem);
    emit(CreatVerceSuccessStates());
  }
}
