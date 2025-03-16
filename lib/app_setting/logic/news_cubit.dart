import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/news_model.dart';
import 'package:om_elnour_choir/app_setting/logic/news_states.dart';

class NewsCubit extends Cubit<NewsStates> {
  NewsCubit() : super(InitNewsStates());

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void createNews({required String content, String? imageUrl}) async {
    try {
      await _firestore.collection('news').add({
        'content': content,
        'imageUrl': imageUrl ?? "",
        'createdAt': FieldValue.serverTimestamp(),
      });
      emit(CreatNewsSuccessStates());
    } catch (e) {
      emit(CreatNewsFailedStates(error: e.toString()));
    }
  }

  void editNews(
      {required String docId,
      required String content,
      String? imageUrl}) async {
    try {
      await _firestore.collection('news').doc(docId).update({
        'content': content,
        'imageUrl': imageUrl ?? "",
      });
      emit(EditNewsStates());
    } catch (e) {
      emit(EditNewsFailedStates(error: e.toString()));
    }
  }

  void deleteNews(String docId) async {
    try {
      await _firestore.collection('news').doc(docId).delete();
      emit(DeleteNewsStates());
    } catch (e) {
      emit(DeleteNewsFailedStates(error: e.toString()));
    }
  }
}
