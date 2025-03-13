import 'package:cloud_firestore/cloud_firestore.dart';

class HymnsModel {
  final String id;
  final String songName;
  final String songUrl;
  final String? youtubeUrl;
  final String category;
  final String album;
  final int views;

  HymnsModel({
    required this.id,
    required this.songName,
    required this.songUrl,
    this.youtubeUrl,
    required this.category,
    required this.album,
    required this.views,
  });

  // دالة التحويل من Firestore
  factory HymnsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HymnsModel(
      id: doc.id,
      songName: data.containsKey('title') ? data['title'] : '',
      songUrl: data.containsKey('url') ? data['url'] : '',
      youtubeUrl: data.containsKey('youtubeUrl') ? data['youtubeUrl'] : null,
      category: data.containsKey('category') ? data['category'] : '',
      album: data.containsKey('album') ? data['album'] : '',
      views: data.containsKey('views') ? data['views'] : 0,
    );
  }
}
