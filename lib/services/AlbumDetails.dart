import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:om_elnour_choir/shared/shared_widgets/music_player_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/shared/shared_widgets/hymn_list_item.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';

class AlbumDetails extends StatefulWidget {
  final String albumName;
  final String? albumImage;
  final MyAudioService audioService;

  const AlbumDetails({
    super.key,
    required this.albumName,
    this.albumImage,
    required this.audioService,
  });

  @override
  _AlbumDetailsState createState() => _AlbumDetailsState();
}

class _AlbumDetailsState extends State<AlbumDetails> {
  int? _currentPlayingIndex;
  List<DocumentSnapshot> _hymns = [];
  late StreamSubscription _hymnsSubscription;
  VoidCallback? _titleListener;
  bool _isProcessingTap = false;

  @override
  void initState() {
    super.initState();
    _loadHymns();
    _loadLastPlayedHymn();
    _setupTitleListener();
    _restorePlaybackState();
  }

  /// ✅ إعداد مستمع الترنيمة المشغلة
  void _setupTitleListener() {
    _titleListener = () {
      if (mounted) {
        String currentTitle =
            widget.audioService.currentTitleNotifier.value ?? '';
        if (currentTitle.isNotEmpty) {
          int index =
              _hymns.indexWhere((hymn) => hymn['songName'] == currentTitle);
          if (index != -1 && index != _currentPlayingIndex) {
            setState(() {
              _currentPlayingIndex = index;
            });
          }
        }
      }
    };
    widget.audioService.currentTitleNotifier.addListener(_titleListener!);
  }

  /// ✅ تحميل الترانيم من Firestore
  void _loadHymns() {
    _hymnsSubscription = FirebaseFirestore.instance
        .collection('hymns')
        .where('songAlbum', isEqualTo: widget.albumName)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _hymns = snapshot.docs;
        });
        // تحديث الترنيمة المشغلة بعد تحميل الترانيم
        _updateCurrentPlayingIndex();
      }
    });
  }

  /// ✅ تحميل آخر ترنيمة تم تشغيلها داخل الألبوم
  Future<void> _loadLastPlayedHymn() async {
    final prefs = await SharedPreferences.getInstance();
    String? lastPlayedHymn =
        prefs.getString('lastPlayedHymn_${widget.albumName}');

    if (lastPlayedHymn != null && mounted) {
      int index =
          _hymns.indexWhere((hymn) => hymn['songName'] == lastPlayedHymn);
      if (index != -1) {
        setState(() {
          _currentPlayingIndex = index;
        });
      }
    }
  }

  /// ✅ تحديث الترنيمة المشغلة
  void _updateCurrentPlayingIndex() {
    String currentTitle = widget.audioService.currentTitleNotifier.value ?? '';
    if (currentTitle.isNotEmpty) {
      int index = _hymns.indexWhere((hymn) => hymn['songName'] == currentTitle);
      if (index != -1 && index != _currentPlayingIndex) {
        setState(() {
          _currentPlayingIndex = index;
        });
      }
    }
  }

  /// ✅ استعادة حالة التشغيل
  Future<void> _restorePlaybackState() async {
    String? lastTitle = widget.audioService.currentTitleNotifier.value;
    if (lastTitle != null && lastTitle.isNotEmpty) {
      int index = _hymns.indexWhere((hymn) => hymn['songName'] == lastTitle);
      if (index != -1) {
        setState(() {
          _currentPlayingIndex = index;
        });
      }
    }
  }

  /// ✅ تشغيل الترانيم داخل الألبوم فقط
  void _playHymn(int index) {
    if (index < 0 || index >= _hymns.length) return;

    setState(() {
      _currentPlayingIndex = index;
    });

    List<String> albumUrls =
        _hymns.map((hymn) => hymn['songUrl'].toString()).toList();
    List<String> albumTitles =
        _hymns.map((hymn) => hymn['songName'].toString()).toList();

    widget.audioService.setPlaylist(albumUrls, albumTitles);
    widget.audioService.play(index, albumTitles[index]);
    widget.audioService.currentTitleNotifier.value = albumTitles[index];

    // تحديث HymnsCubit
    var hymn = _hymns[index];
    var hymnsCubit = context.read<HymnsCubit>();
    var hymnModel = HymnsModel(
      id: hymn.id,
      songName: hymn['songName'].toString(),
      songUrl: hymn['songUrl'].toString(),
      songCategory: hymn['songCategory'].toString(),
      songAlbum: hymn['songAlbum'].toString(),
      albumImageUrl: widget.albumImage,
      views: hymn['views'] ?? 0,
      dateAdded: (hymn['dateAdded'] as Timestamp).toDate(),
    );
    hymnsCubit.playHymn(hymnModel);

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('lastPlayedHymn_${widget.albumName}', albumTitles[index]);
    });
  }

  @override
  void dispose() {
    _hymnsSubscription.cancel();
    if (_titleListener != null) {
      widget.audioService.currentTitleNotifier.removeListener(_titleListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text(
          widget.albumName,
          style: TextStyle(color: AppColors.appamber),
        ),
        leading: BackBtn(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // صورة الألبوم في الأعلى كما في الكود الأصلي
            if (widget.albumImage != null && widget.albumImage!.isNotEmpty)
              Hero(
                tag: widget.albumName,
                child: Container(
                  margin: EdgeInsets.all(10),
                  width: screenWidth * 0.9,
                  height: screenWidth * 0.5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: CachedNetworkImage(
                      imageUrl: widget.albumImage!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.appamber),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: Icon(Icons.music_note,
                            color: AppColors.appamber, size: 80),
                      ),
                    ),
                  ),
                ),
              ),

            // قائمة الترانيم
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('hymns')
                    .where('songAlbum', isEqualTo: widget.albumName)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("❌ خطأ في تحميل الترانيم"));
                  }

                  final hymns = snapshot.data!.docs;
                  if (hymns.isEmpty) {
                    return Center(child: Text("لا توجد ترانيم في هذا الألبوم"));
                  }

                  return ListView.builder(
                    itemCount: hymns.length,
                    itemBuilder: (context, index) {
                      var hymn = hymns[index];
                      String title = hymn['songName'];

                      // تحويل البيانات إلى نموذج HymnsModel
                      var hymnModel = HymnsModel(
                        id: hymn.id,
                        songName: hymn['songName'].toString(),
                        songUrl: hymn['songUrl'].toString(),
                        songCategory: hymn['songCategory'].toString(),
                        songAlbum: hymn['songAlbum'].toString(),
                        albumImageUrl: widget.albumImage,
                        views: hymn['views'] ?? 0,
                        dateAdded: (hymn['dateAdded'] as Timestamp).toDate(),
                        youtubeUrl: hymn['youtubeUrl'],
                      );

                      bool isPlaying = _currentPlayingIndex == index;

                      return HymnListItem(
                        hymn: hymnModel,
                        isPlaying: isPlaying,
                        onTap: () {
                          if (_isProcessingTap) return;
                          _isProcessingTap = true;

                          // استخدام الدالة الموجودة لتشغيل الترنيمة
                          _playHymn(index);

                          Future.delayed(Duration(milliseconds: 500), () {
                            if (mounted) {
                              setState(() {
                                _isProcessingTap = false;
                              });
                            } else {
                              _isProcessingTap = false;
                            }
                          });
                        },
                        onToggleFavorite: (hymn) =>
                            context.read<HymnsCubit>().toggleFavorite(hymn),
                      );
                    },
                  );
                },
              ),
            ),

            // مشغل الموسيقى
            MusicPlayerWidget(audioService: widget.audioService),

            // إضافة الإعلان
            Container(
              height: 50, // ارتفاع ثابت للإعلان
              child: AdBanner(
                key: UniqueKey(),
                cacheKey: 'album_details',
                audioService: widget.audioService,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
