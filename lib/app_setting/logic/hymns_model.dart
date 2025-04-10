import 'package:cloud_firestore/cloud_firestore.dart';

class HymnsModel {
  final String id;
  final String songName;
  final String songUrl;
  final String songCategory;
  final String songAlbum;
  final String? albumImageUrl;
  final int views;
  final DateTime dateAdded;
  final String? youtubeUrl;

  HymnsModel({
    required this.id,
    required this.songName,
    required this.songUrl,
    required this.songCategory,
    required this.songAlbum,
    this.albumImageUrl,
    required this.views,
    required this.dateAdded,
    this.youtubeUrl,
  });

  factory HymnsModel.fromFirestore(
      Map<String, dynamic> data, String documentId) {
    return HymnsModel(
      id: documentId,
      songName: data['songName'] ?? '',
      songUrl: data['songUrl'] ?? '',
      songCategory: data['songCategory'] ?? '',
      songAlbum: data['songAlbum'] ?? '',
      albumImageUrl: data['albumImageUrl'],
      views: data['views'] ?? 0,
      dateAdded: (data['dateAdded'] is Timestamp)
          ? (data['dateAdded'] as Timestamp).toDate()
          : DateTime.now(),
      youtubeUrl: data['youtubeUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'songName': songName,
      'songUrl': songUrl,
      'songCategory': songCategory,
      'songAlbum': songAlbum,
      'albumImageUrl': albumImageUrl,
      'views': views,
      'dateAdded': dateAdded,
      'youtubeUrl': youtubeUrl,
    };
  }

  factory HymnsModel.fromJson(Map<String, dynamic> json) {
    return HymnsModel(
      id: json['id'] as String,
      songName: json['songName'] as String,
      songUrl: json['songUrl'] as String,
      songCategory: json['songCategory'] as String,
      songAlbum: json['songAlbum'] as String,
      albumImageUrl: json['albumImageUrl'] as String?,
      views: json['views'] as int,
      // تعديل هنا للتعامل مع التاريخ بشكل صحيح
      dateAdded: json['dateAdded'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['dateAdded'] as int)
          : (json['dateAdded'] is Timestamp
              ? (json['dateAdded'] as Timestamp).toDate()
              : DateTime.now()),
      youtubeUrl: json['youtubeUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'songName': songName,
      'songUrl': songUrl,
      'songCategory': songCategory,
      'songAlbum': songAlbum,
      'albumImageUrl': albumImageUrl,
      'views': views,
      // تعديل هنا لتحويل التاريخ إلى عدد صحيح بدلاً من Timestamp
      'dateAdded': dateAdded.millisecondsSinceEpoch,
      'youtubeUrl': youtubeUrl,
    };
  }
}
