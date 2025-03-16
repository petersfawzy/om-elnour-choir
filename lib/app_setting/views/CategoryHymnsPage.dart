import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/music_player_widget.dart';

class CategoryHymnsWidget extends StatefulWidget {
  final String categoryName;
  final Myaudioservice audioService;

  const CategoryHymnsWidget(
      {super.key, required this.categoryName, required this.audioService});

  @override
  _CategoryHymnsWidgetState createState() => _CategoryHymnsWidgetState();
}

class _CategoryHymnsWidgetState extends State<CategoryHymnsWidget> {
  int? _currentPlayingIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('hymns')
                .where('songCategory', isEqualTo: widget.categoryName)
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
                  bool isPlaying = _currentPlayingIndex == index;

                  return ListTile(
                    tileColor: isPlaying ? AppColors.appamber : null,
                    contentPadding: EdgeInsets.symmetric(horizontal: 15),
                    title: Text(
                      title,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: isPlaying
                            ? AppColors.backgroundColor
                            : AppColors.appamber,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_note,
                            color: isPlaying
                                ? AppColors.backgroundColor
                                : AppColors.appamber),
                        SizedBox(width: 5),
                        Text(
                          '$views',
                          style: TextStyle(
                              color: isPlaying
                                  ? AppColors.backgroundColor
                                  : AppColors.appamber),
                        ),
                      ],
                    ),
                    onTap: () {
                      List<String> urls =
                          hymns.map((h) => h['songUrl'] as String).toList();
                      List<String> titles =
                          hymns.map((h) => h['songName'] as String).toList();

                      widget.audioService.setPlaylist(urls, titles);

                      if (widget.audioService.currentIndexNotifier.value ==
                              index &&
                          widget.audioService.isPlayingNotifier.value) {
                        // إذا كانت الترنيمة نفسها شغالة، قم بإيقافها
                        widget.audioService.togglePlayPause();
                      } else {
                        // إذا كانت ترنيمة مختلفة، قم بتشغيلها
                        widget.audioService.play(index, titles[index]);
                        // زيادة عدد المشاهدات
                        FirebaseFirestore.instance
                            .collection('hymns')
                            .doc(hymn.id)
                            .update({'views': FieldValue.increment(1)});
                      }

                      setState(() {
                        _currentPlayingIndex = index;
                      });
                    },
                  );
                },
              );
            },
          ),
        ),
        MusicPlayerWidget(audioService: widget.audioService),
      ],
    );
  }
}
