import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_states.dart';

class HymnsCubit extends Cubit<HymnsStates> {
  HymnsCubit() : super(InitHymnsStates());

  final List<HymnsModel> _hymnsList = [];

  List<HymnsModel> get hymnsList => _hymnsList;
  void creatHymn({required String title}) {
    HymnsModel newHymn = HymnsModel(id: 0, titel: title);
    _hymnsList.insert(0, newHymn);
    emit(CreatHymnsSuccessStates());
  }

  void editHymn(HymnsModel hymnModel, String newTitle) {
    if (hymnModel.titel != newTitle) {
      hymnModel.titel = newTitle;
    }
    emit(EditHymnsStates());
  }

  void deletHymn(int index) {
    hymnsList.removeAt(index);
    emit(DeleteHymnsStates());
  }
}
