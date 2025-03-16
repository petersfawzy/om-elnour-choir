import 'package:cloud_firestore/cloud_firestore.dart';

class NewsModel {
  final String docId;
  final String content;
  final String? imageUrl;
  final DateTime? createdAt;

  NewsModel({
    required this.docId,
    required this.content,
    this.imageUrl,
    this.createdAt,
  });

  factory NewsModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return NewsModel(
      docId: docId,
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'imageUrl': imageUrl ?? '',
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
