import 'package:cloud_firestore/cloud_firestore.dart';

class CopticCalendarModel {
  final String id;
  final String content;
  final String date;
  final Timestamp? dateAdded;

  CopticCalendarModel({
    required this.id,
    required this.content,
    required this.date,
    this.dateAdded,
  });
}
