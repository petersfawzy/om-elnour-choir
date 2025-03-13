import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';

class HymnsListPage extends StatelessWidget {
  final String categoryName;

  const HymnsListPage({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text('الترانيم - $categoryName',
            style: TextStyle(color: Colors.amber)),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('hymns')
            .where('category', isEqualTo: categoryName)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("❌ خطأ في تحميل الترانيم"));
          }

          var hymns = snapshot.data!.docs;

          return ListView.builder(
            itemCount: hymns.length,
            itemBuilder: (context, index) {
              var hymn = hymns[index];
              String title = hymn['songName'];
              int views = hymn['views'];

              return ListTile(
                title: Text(title,
                    style: TextStyle(color: Colors.amber, fontSize: 18)),
                subtitle: Text('$views مشاهدة',
                    style: TextStyle(color: Colors.white70)),
                onTap: () {
                  // تشغيل الترنيمة هنا
                },
              );
            },
          );
        },
      ),
    );
  }
}
