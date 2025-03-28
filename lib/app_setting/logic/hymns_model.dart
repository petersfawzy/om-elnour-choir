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
  final String? youtubeUrl; // ✅ إضافة الحقل الجديد

  HymnsModel({
    required this.id,
    required this.songName,
    required this.songUrl,
    required this.songCategory,
    required this.songAlbum,
    this.albumImageUrl,
    required this.views,
    required this.dateAdded,
    this.youtubeUrl, // ✅ تأكد من إضافة هذا الحقل كخيار اختياري
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
      dateAdded: (data['dateAdded'] as Timestamp).toDate(),
      youtubeUrl: data['youtubeUrl'], // ✅ جلب الرابط من Firestore
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
      'youtubeUrl': youtubeUrl, // ✅ التأكد من حفظ الرابط عند التخزين
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
      dateAdded: (json['dateAdded'] as Timestamp).toDate(),
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
      'dateAdded': Timestamp.fromDate(dateAdded),
      'youtubeUrl': youtubeUrl,
    };
  }
}
