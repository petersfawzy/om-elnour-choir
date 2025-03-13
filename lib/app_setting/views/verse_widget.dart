import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerseWidget extends StatelessWidget {
  const VerseWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('verses')
          .orderBy('date', descending: true)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Text("لا يوجد");
        }
        var verseData = snapshot.data!.docs.first;
        String content = verseData['content'];
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            content,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
