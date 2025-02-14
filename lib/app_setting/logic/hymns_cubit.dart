import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_states.dart';

class HymnsCubit extends Cubit<HymnsStates> {
  HymnsCubit() : super(InitHymnsStates());

  final List<HymnsModel> _hymnsList = [];

  List<HymnsModel> get hymnsList => _hymnsList;
  void creatHymn({required String title,required String url}) async{
    HymnsModel newHymn = HymnsModel(id: 0, songName: title, songUrl: url);
    _hymnsList.insert(0, newHymn);
    emit(CreatHymnsSuccessStates());
  }

  void editHymn(HymnsModel hymnModel, String newTitle) {
    if (hymnModel.songName != newTitle) {
      hymnModel.songName = newTitle;
    }
    emit(EditHymnsStates());
  }

  void deletHymn(int index) {
    hymnsList.removeAt(index);
    emit(DeleteHymnsStates());
  }
}
