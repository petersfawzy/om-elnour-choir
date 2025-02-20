import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:om_elnour_choir/services/AudioService.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';

class HymnsPage extends StatefulWidget {
  @override
  _HymnsPageState createState() => _HymnsPageState();
}

class _HymnsPageState extends State<HymnsPage> with WidgetsBindingObserver {
  final AudioService _audioService = AudioService();
  List<DocumentSnapshot>? _hymns;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // تحديث عدد المشاهدات عند بدء تشغيل الترنيمة
    _audioService.currentIndexNotifier.addListener(() {
      if (_hymns != null && _audioService.currentIndexNotifier.value != null) {
        int index = _audioService.currentIndexNotifier.value!;
        var hymn = _hymns![index];
        String docId = hymn.id;
        int views = hymn['views'];

        // تحديث عدد المشاهدات في Firestore
        FirebaseFirestore.instance.collection('hymns').doc(docId).update({
          'views': views + 1,
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _audioService.handleAppLifecycleState(state);
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text('Hymns', style: TextStyle(color: Colors.amber)),
        backgroundColor: AppColors.backgroundColor,
        leading: BackBtn(),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream:
                  FirebaseFirestore.instance.collection('hymns').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error loading hymns"));
                }

                _hymns = snapshot.data!.docs;

                if (_hymns != null) {
                  _audioService.setPlaylist(
                      _hymns!.map((hymn) => hymn['songUrl'] as String).toList(),
                      _hymns!
                          .map((hymn) => hymn['songName'] as String)
                          .toList());
                }

                return ListView.builder(
                  itemCount: _hymns!.length,
                  itemBuilder: (context, index) {
                    var hymn = _hymns![index];
                    String title = hymn['songName'];
                    int views = hymn['views'];

                    return ValueListenableBuilder<int?>(
                      valueListenable: _audioService.currentIndexNotifier,
                      builder: (context, currentIndex, child) {
                        bool isPlaying = index == currentIndex;
                        return GestureDetector(
                          onTap: () => playHymn(index),
                          child: Container(
                            margin: EdgeInsets.symmetric(
                                vertical: 5, horizontal: 10),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isPlaying ? Colors.amber : Colors.blueGrey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.remove_red_eye,
                                        color: isPlaying
                                            ? AppColors.backgroundColor
                                            : Colors.amber[200],
                                        size: 20),
                                    SizedBox(width: 5),
                                    Text(
                                      '$views',
                                      style: TextStyle(
                                        color: isPlaying
                                            ? AppColors.backgroundColor
                                            : Colors.amber[200],
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Expanded(
                                  child: Text(
                                    title,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: isPlaying
                                          ? AppColors.backgroundColor
                                          : Colors.amber[200],
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          _buildPlayerBar(),
        ],
      ),
    );
  }

  Widget _buildPlayerBar() {
    return ValueListenableBuilder<String?>(
      valueListenable: _audioService.currentTitleNotifier,
      builder: (context, currentTitle, child) {
        return Container(
          padding: EdgeInsets.all(10),
          color: AppColors.backgroundColor,
          child: Column(
            children: [
              Text(
                currentTitle ?? "No hymn playing",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ValueListenableBuilder<Duration>(
                    valueListenable: _audioService.positionNotifier,
                    builder: (context, currentPosition, child) {
                      return Text(formatDuration(currentPosition),
                          style: TextStyle(color: Colors.amber));
                    },
                  ),
                  Expanded(
                    child: ValueListenableBuilder<Duration>(
                      valueListenable: _audioService.durationNotifier,
                      builder: (context, totalDuration, child) {
                        return Slider(
                          activeColor: Colors.amber,
                          inactiveColor: Colors.grey,
                          min: 0,
                          max: totalDuration.inSeconds.toDouble(),
                          value: _audioService.positionNotifier.value.inSeconds
                              .toDouble(),
                          onChanged: (value) {
                            _audioService
                                .seek(Duration(seconds: value.toInt()));
                          },
                        );
                      },
                    ),
                  ),
                  ValueListenableBuilder<Duration>(
                    valueListenable: _audioService.durationNotifier,
                    builder: (context, totalDuration, child) {
                      return Text(formatDuration(totalDuration),
                          style: TextStyle(color: Colors.amber));
                    },
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _audioService.isShufflingNotifier,
                    builder: (context, isShuffling, child) {
                      return IconButton(
                        icon: Icon(Icons.shuffle,
                            color: isShuffling ? Colors.green : Colors.amber),
                        onPressed: _audioService.toggleShuffle,
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_previous, color: Colors.amber),
                    onPressed: _audioService.playPrevious,
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _audioService.isPlayingNotifier,
                    builder: (context, isPlaying, child) {
                      return IconButton(
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.amber),
                        onPressed: isPlaying
                            ? _audioService.pause
                            : _audioService.resume,
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_next, color: Colors.amber),
                    onPressed: _audioService.playNext,
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _audioService.isRepeatingNotifier,
                    builder: (context, isRepeating, child) {
                      return IconButton(
                        icon: Icon(Icons.repeat,
                            color: isRepeating ? Colors.green : Colors.amber),
                        onPressed: _audioService.toggleRepeat,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void playHymn(int index) {
    if (_hymns == null || index < 0 || index >= _hymns!.length) return;

    var hymn = _hymns![index];
    String title = hymn['songName']; // ✅ اسم الترنيمة
    String docId = hymn.id;
    int views = hymn['views'];

    _audioService.play(index, title); // ✅ تمرير اسم الترنيمة

    // تحديث عدد المشاهدات
    FirebaseFirestore.instance.collection('hymns').doc(docId).update({
      'views': views + 1,
    });
  }
}
