import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:om_elnour_choir/shared/shared_widgets/music_player_widget.dart';

class AlbumDetails extends StatefulWidget {
  final String albumName;
  final Myaudioservice audioService; // إضافة MyAudioService كمعامل

  const AlbumDetails({super.key, required this.albumName, required this.audioService});

  @override
  _AlbumDetailsState createState() => _AlbumDetailsState();
}

class _AlbumDetailsState extends State<AlbumDetails> {
  int? _currentPlayingIndex;
  StreamSubscription? _hymnsSubscription;
  List<DocumentSnapshot> _hymns = [];

  void _playHymn(int index) {
    setState(() {
      _currentPlayingIndex = index;
    });

    // تحديث قائمة التشغيل بالترانيم الخاصة بهذا الألبوم
    widget.audioService.setPlaylist(
      _hymns.map((hymn) => hymn['songUrl'].toString()).toList(),
      _hymns.map((hymn) => hymn['songName'].toString()).toList(),
    );

    // تشغيل الترنيمة المحددة
    widget.audioService.play(index, _hymns[index]['songName']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text(
          'الترانيم في ${widget.albumName}',
          style: TextStyle(color: Colors.amber),
        ),
        leading: BackBtn(),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('hymns')
                  .where('songAlbum', isEqualTo: widget.albumName)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("❌ خطأ في تحميل الترانيم"));
                }

                _hymns = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: _hymns.length,
                  itemBuilder: (context, index) {
                    var hymn = _hymns[index];
                    String title = hymn['songName'];
                    int views = hymn['views'];
                    bool isPlaying = _currentPlayingIndex == index;

                    return ListTile(
                      tileColor: isPlaying ? Colors.amber : null,
                      contentPadding: EdgeInsets.symmetric(horizontal: 15),
                      title: Text(
                        title,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: isPlaying
                              ? AppColors.backgroundColor
                              : Colors.amber,
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
                                  : Colors.amber),
                          SizedBox(width: 5),
                          Text(
                            '$views',
                            style: TextStyle(
                                color: isPlaying
                                    ? AppColors.backgroundColor
                                    : Colors.amber),
                          ),
                        ],
                      ),
                      onTap: () => _playHymn(index),
                    );
                  },
                );
              },
            ),
          ),
          MusicPlayerWidget(
              audioService: widget.audioService), // إضافة المشغل هنا
        ],
      ),
    );
  }
}
