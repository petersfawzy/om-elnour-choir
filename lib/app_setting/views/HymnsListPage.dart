import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';

class HymnsListPage extends StatefulWidget {
  final String categoryName;

  const HymnsListPage({super.key, required this.categoryName});

  @override
  _HymnsListPageState createState() => _HymnsListPageState();
}

class _HymnsListPageState extends State<HymnsListPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // ✅ منع إعادة تحميل التبويب

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text('الترانيم - ${widget.categoryName}',
            style: TextStyle(color: AppColors.appamber)),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('hymns')
            .where('category', isEqualTo: widget.categoryName)
            .snapshots()
            .asBroadcastStream(), // ✅ منع إعادة تحميل البيانات
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
                    style: TextStyle(color: AppColors.appamber, fontSize: 18)),
                subtitle: Text('$views مشاهدة',
                    style: TextStyle(color: Colors.white70)),
                onTap: () {
                  // ✅ تشغيل الترانيمة هنا
                },
              );
            },
          );
        },
      ),
      // bottomNavigationBar: const AdBanner(),
    );
  }
}
