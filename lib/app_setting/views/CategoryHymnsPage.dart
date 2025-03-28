import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';

class CategoryHymnsWidget extends StatefulWidget {
  final String categoryName;
  final MyAudioService audioService;

  const CategoryHymnsWidget({
    super.key,
    required this.categoryName,
    required this.audioService,
  });

  @override
  _CategoryHymnsWidgetState createState() => _CategoryHymnsWidgetState();
}

class _CategoryHymnsWidgetState extends State<CategoryHymnsWidget>
    with AutomaticKeepAliveClientMixin {
  List<DocumentSnapshot> _hymns = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hymnsCubit = context.watch<HymnsCubit>();
    final currentHymn = hymnsCubit.currentHymn;

    return Column(
      children: [
        AppBar(
          backgroundColor: AppColors.backgroundColor,
          title: Text(
            widget.categoryName,
            style: TextStyle(color: AppColors.appamber),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.appamber),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('hymns')
                .where('songCategory', isEqualTo: widget.categoryName)
                .orderBy('dateAdded', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("❌ خطأ في تحميل الترانيم"));
              }

              _hymns = snapshot.data!.docs;
              if (_hymns.isEmpty) {
                return Center(child: Text("لا توجد ترانيم في هذا التصنيف"));
              }

              return ListView.builder(
                itemCount: _hymns.length,
                itemBuilder: (context, index) {
                  var hymn = _hymns[index];
                  String title = hymn['songName'];
                  int views = hymn['views'];
                  bool isPlaying = currentHymn?.id == hymn.id;

                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isPlaying ? AppColors.appamber.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isPlaying ? AppColors.appamber : AppColors.appamber.withOpacity(0.3),
                        width: isPlaying ? 2 : 1,
                      ),
                      boxShadow: isPlaying ? [
                        BoxShadow(
                          color: AppColors.appamber.withOpacity(0.2),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                      title: Text(
                        title,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: AppColors.appamber,
                          fontSize: 18,
                          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        hymn['englishName'] ?? '',
                        style: TextStyle(
                          color: AppColors.appamber.withOpacity(0.7),
                          fontSize: MediaQuery.of(context).size.width > 600 ? 16 : 14,
                        ),
                      ),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_note, color: AppColors.appamber),
                          const SizedBox(width: 5),
                          Text(
                            '$views',
                            style: TextStyle(color: AppColors.appamber),
                          ),
                        ],
                      ),
                      onTap: () => _playHymn(index, hymn),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// ✅ **تشغيل الترنيمة وتحديث المشاهدات**
  void _playHymn(int index, DocumentSnapshot hymn) {
    try {
      List<String> urls = _hymns.map((h) => h['songUrl'] as String).toList();
      List<String> titles = _hymns.map((h) => h['songName'] as String).toList();

      widget.audioService.setPlaylist(urls, titles);

      if (widget.audioService.currentIndexNotifier.value == index &&
          widget.audioService.isPlayingNotifier.value) {
        widget.audioService.togglePlayPause();
      } else {
        widget.audioService.play(index, titles[index]);

        // ✅ تحديث عدد المشاهدات بدون إعادة تحميل القائمة بالكامل
        FirebaseFirestore.instance
            .collection('hymns')
            .doc(hymn.id)
            .update({'views': FieldValue.increment(1)});
      }
    } catch (e) {
      print('❌ خطأ في تشغيل الترنيمة: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تشغيل الترنيمة')),
      );
    }
  }
}
