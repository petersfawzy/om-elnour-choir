import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';

class CategoriesWidget extends StatefulWidget {
  final Function(String) onCategorySelected;

  const CategoriesWidget({super.key, required this.onCategorySelected});

  @override
  _CategoriesWidgetState createState() => _CategoriesWidgetState();
}

class _CategoriesWidgetState extends State<CategoriesWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // ✅ يمنع إعادة تحميل الصفحة عند التبديل

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ ضروري عند استخدام AutomaticKeepAliveClientMixin
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
              title: Text(categoryName,
                  style: TextStyle(color: AppColors.appamber)),
              trailing: Icon(Icons.arrow_forward, color: AppColors.appamber),
              onTap: () => widget.onCategorySelected(categoryName),
            );
          },
        );
      },
    );
  }
}
