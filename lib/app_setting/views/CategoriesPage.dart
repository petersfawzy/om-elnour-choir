import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoriesWidget extends StatelessWidget {
  final Function(String) onCategorySelected;

  const CategoriesWidget({super.key, required this.onCategorySelected});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('categories').snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("❌ خطأ في تحميل التصنيفات"));
        }

        var categories = snapshot.data!.docs;

        return ListView.builder(
          itemCount: categories.length,
          itemBuilder: (context, index) {
            var category = categories[index];
            String categoryName = category['name'];

            return ListTile(
              title: Text(categoryName, style: TextStyle(color: Colors.amber)),
              trailing: Icon(Icons.arrow_forward, color: Colors.amber),
              onTap: () => onCategorySelected(categoryName),
            );
          },
        );
      },
    );
  }
}
