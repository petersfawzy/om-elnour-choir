import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/news_model.dart';
import 'package:om_elnour_choir/app_setting/logic/news_states.dart';

class NewsCubit extends Cubit<NewsStates> {
  NewsCubit() : super(InitNewsStates());
  final List<NewsModel> _newsList = [];
  List<NewsModel> get newsList => _newsList;
  void creatNews({required String title}) {
    NewsModel newItem = NewsModel(id: 0, NewsTitle: title);
    _newsList.insert(0, newItem);
    emit(CreatNewsSuccessStates());
  }

  void editNews(NewsModel neewsModel, String newsTitle) {
    if (neewsModel.NewsTitle != newsTitle) {
      neewsModel.NewsTitle = newsTitle;
    }
    emit(EditNewsStates());
  }

  void deletNews(int index) {
    newsList.removeAt(index);
    emit(DeleteNewsStates());
  }
}
