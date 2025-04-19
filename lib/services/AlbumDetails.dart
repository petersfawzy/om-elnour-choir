import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:om_elnour_choir/shared/shared_widgets/music_player_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/shared/shared_widgets/hymn_list_item.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';

class AlbumDetails extends StatefulWidget {
  final String albumName;
  final String? albumImage;
  final MyAudioService audioService;

  const AlbumDetails({
    Key? key,
    required this.albumName,
    this.albumImage,
    required this.audioService,
  }) : super(key: key);

  @override
  State<AlbumDetails> createState() => _AlbumDetailsState();
}

class _AlbumDetailsState extends State<AlbumDetails>
    with WidgetsBindingObserver {
  int? _currentPlayingIndex;
  List<DocumentSnapshot> _hymns = [];
  StreamSubscription? _hymnsSubscription;
  VoidCallback? _titleListener;
  bool _isProcessingTap = false;
  bool _disposed = false;
  bool _isLoading = true;
  String? _errorMessage;

  // إضافة متغير لتتبع محاولات التشغيل
  int _playAttempts = 0;
  static const int _maxPlayAttempts = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Register the callback for view count increments
    widget.audioService.registerHymnChangedCallback(_onHymnChangedCallback);

    _initializeData();
  }

  // Add the callback method:
  void _onHymnChangedCallback(int index, String title) {
    if (_disposed) return;

    print('📊 تم استدعاء callback في AlbumDetails للترنيمة: $title');

    // البحث عن الترنيمة في قائمتنا
    int hymnIndex = -1;
    for (int i = 0; i < _hymns.length; i++) {
      if (_hymns[i]['songName'] == title) {
        hymnIndex = i;
        break;
      }
    }

    if (hymnIndex != -1) {
      try {
        // زيادة عدد المشاهدات باستخدام HymnsCubit
        final hymnId = _hymns[hymnIndex].id;
        print(
            '📊 زيادة عدد المشاهدات للترنيمة: $title (ID: $hymnId) من AlbumDetails');
        context.read<HymnsCubit>().incrementHymnViews(hymnId);
      } catch (e) {
        print('❌ خطأ أثناء زيادة عدد المشاهدات: $e');
      }
    } else {
      print('⚠️ لم يتم العثور على الترنيمة: $title في قائمة الألبوم');
    }
  }

  Future<void> _initializeData() async {
    try {
      await _loadHymns();
      await _loadLastPlayedHymn();
      _setupTitleListener();

      if (mounted && !_disposed) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error initializing album details: $e');
      if (mounted && !_disposed) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'حدث خطأ أثناء تحميل البيانات. يرجى المحاولة مرة أخرى.';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground
      _updateCurrentPlayingIndex();
    }
  }

  /// ✅ Set up current hymn listener
  void _setupTitleListener() {
    try {
      _titleListener = () {
        if (mounted && !_disposed) {
          String? currentTitle = widget.audioService.currentTitleNotifier.value;
          if (currentTitle != null && currentTitle.isNotEmpty) {
            int index = -1;
            for (int i = 0; i < _hymns.length; i++) {
              if (_hymns[i]['songName'] == currentTitle) {
                index = i;
                break;
              }
            }

            if (index != -1 && index != _currentPlayingIndex) {
              setState(() {
                _currentPlayingIndex = index;
              });
            }
          }
        }
      };
      widget.audioService.currentTitleNotifier.addListener(_titleListener!);
    } catch (e) {
      print('❌ Error setting up title listener: $e');
    }
  }

  /// ✅ Load hymns from Firestore
  Future<void> _loadHymns() async {
    try {
      print('🔄 Loading hymns for album: ${widget.albumName}');

      // Cancel any existing subscription
      await _hymnsSubscription?.cancel();

      // Create new subscription
      _hymnsSubscription = FirebaseFirestore.instance
          .collection('hymns')
          .where('songAlbum', isEqualTo: widget.albumName)
          .snapshots()
          .listen(
        (snapshot) {
          if (mounted && !_disposed) {
            setState(() {
              _hymns = snapshot.docs;
              _isLoading = false;
            });
            // Update current playing hymn after loading hymns
            _updateCurrentPlayingIndex();
          }
        },
        onError: (error) {
          print('❌ Error in hymns stream: $error');
          if (mounted && !_disposed) {
            setState(() {
              _isLoading = false;
              _errorMessage =
                  'حدث خطأ أثناء تحميل الترانيم. يرجى المحاولة مرة أخرى.';
            });
          }
        },
      );
    } catch (e) {
      print('❌ Error loading hymns: $e');
      rethrow;
    }
  }

  /// ✅ Load last played hymn in album
  Future<void> _loadLastPlayedHymn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? lastPlayedHymn =
          prefs.getString('lastPlayedHymn_${widget.albumName}');

      if (lastPlayedHymn != null && mounted && !_disposed) {
        int index = -1;
        for (int i = 0; i < _hymns.length; i++) {
          if (_hymns[i]['songName'] == lastPlayedHymn) {
            index = i;
            break;
          }
        }

        if (index != -1) {
          setState(() {
            _currentPlayingIndex = index;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading last played hymn: $e');
    }
  }

  /// ✅ Update current playing hymn
  void _updateCurrentPlayingIndex() {
    try {
      String? currentTitle = widget.audioService.currentTitleNotifier.value;
      if (currentTitle != null && currentTitle.isNotEmpty) {
        int index = -1;
        for (int i = 0; i < _hymns.length; i++) {
          if (_hymns[i]['songName'] == currentTitle) {
            index = i;
            break;
          }
        }

        if (index != -1 && index != _currentPlayingIndex) {
          setState(() {
            _currentPlayingIndex = index;
          });
        }
      }
    } catch (e) {
      print('❌ Error updating current playing index: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);

    // تعديل طريقة إلغاء تسجيل الـ callback
    widget.audioService.registerHymnChangedCallback(null);

    // Cancel subscriptions
    _hymnsSubscription?.cancel();

    // Remove listeners
    if (_titleListener != null) {
      widget.audioService.currentTitleNotifier.removeListener(_titleListener!);
    }

    super.dispose();
  }

  // تعديل في دالة build لمنع إعادة إنشاء العناصر
  @override
  Widget build(BuildContext context) {
    // Check screen orientation
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

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
        child: _isLoading
            ? _buildLoadingView()
            : _errorMessage != null
                ? _buildErrorView()
                : isLandscape
                    ? _buildLandscapeLayout(screenWidth, screenHeight)
                    : _buildPortraitLayout(screenWidth),
      ),
    );
  }

  // Loading view
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.appamber),
          ),
          SizedBox(height: 16),
          Text(
            'جاري تحميل الترانيم...',
            style: TextStyle(color: AppColors.appamber),
          ),
        ],
      ),
    );
  }

  // Error view
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            _errorMessage ?? 'حدث خطأ غير معروف',
            style: TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _initializeData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.appamber,
            ),
            child: Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  // تعديل في دالة _buildPortraitLayout لإصلاح مشكلة إعادة إنشاء العناصر
  Widget _buildPortraitLayout(double screenWidth) {
    return Column(
      children: [
        // Album image at top with appropriate size
        if (widget.albumImage != null && widget.albumImage!.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: Hero(
              tag: 'album_${widget.albumName}',
              child: Container(
                width: screenWidth * 0.5, // 50% of screen width
                height: screenWidth * 0.5, // Square aspect ratio
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: widget.albumImage!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.appamber),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[800],
                      child: Icon(Icons.music_note,
                          color: AppColors.appamber, size: 40),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Hymns section title
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.music_note, color: AppColors.appamber),
              SizedBox(width: 8),
              Text(
                "ترانيم الألبوم",
                style: TextStyle(
                  color: AppColors.appamber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Text(
                "${_hymns.length} ترنيمة",
                style: TextStyle(
                  color: AppColors.appamber,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // Hymns list
        Expanded(
          child: _buildHymnsList(),
        ),

        // Music player and ad
        Container(
          height: 280, // Increased height to show all music player details
          child: Column(
            children: [
              // Music player
              Expanded(
                child: MusicPlayerWidget(
                    key: ValueKey('music_player_portrait'),
                    audioService: widget.audioService),
              ),
              // Ad
              Container(
                height: 50, // Fixed height for ad
                child: AdBanner(
                  key: ValueKey('album_ad_banner_portrait'),
                  cacheKey: 'album_details_${widget.albumName}_portrait',
                  audioService: widget.audioService,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // تعديل في دالة _buildLandscapeLayout لإصلاح مشكلة إعادة إنشاء العناصر
  Widget _buildLandscapeLayout(double screenWidth, double screenHeight) {
    return Column(
      children: [
        // Main section - takes most of the space
        Expanded(
          child: Row(
            children: [
              // Album image - takes 20% of width
              if (widget.albumImage != null && widget.albumImage!.isNotEmpty)
                Container(
                  width: screenWidth * 0.2,
                  padding: EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Hero(
                        tag: 'album_${widget.albumName}',
                        child: Container(
                          width: screenWidth * 0.18, // 18% of screen width
                          height: screenWidth * 0.18, // Square aspect ratio
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
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
                                    color: AppColors.appamber, size: 40),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "${_hymns.length} ترنيمة",
                        style: TextStyle(
                          color: AppColors.appamber,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              // Hymns list - takes remaining space
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hymns section title
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.music_note,
                              color: AppColors.appamber, size: 16),
                          SizedBox(width: 4),
                          Text(
                            "ترانيم الألبوم",
                            style: TextStyle(
                              color: AppColors.appamber,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Hymns list
                    Expanded(
                      child: _buildHymnsList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Bottom section - music player and ad side by side
        Container(
          height: 150, // Increased height in landscape mode
          child: Row(
            children: [
              // Music player - 75% of width
              Expanded(
                flex: 75,
                child: MusicPlayerWidget(
                    key: ValueKey('music_player_landscape'),
                    audioService: widget.audioService),
              ),
              // Ad - 25% of width
              Expanded(
                flex: 25,
                child: AdBanner(
                  key: ValueKey('album_ad_banner_landscape'),
                  cacheKey: 'album_details_${widget.albumName}_landscape',
                  audioService: widget.audioService,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Common function to build hymns list
  // تعديل في دالة _buildHymnsList لإصلاح مشكلة عدم القدرة على تشغيل ترنيمة أخرى
  Widget _buildHymnsList() {
    if (_hymns.isEmpty) {
      return Center(
        child: Text(
          "لا توجد ترانيم في هذا الألبوم",
          style: TextStyle(color: AppColors.appamber),
        ),
      );
    }

    return ListView.builder(
      itemCount: _hymns.length,
      itemBuilder: (context, index) {
        try {
          var hymn = _hymns[index];
          Map<String, dynamic> data = hymn.data() as Map<String, dynamic>;

          String title = data['songName']?.toString() ?? 'بدون عنوان';
          String url = data['songUrl']?.toString() ?? '';
          String category = data['songCategory']?.toString() ?? '';
          String album = data['songAlbum']?.toString() ?? '';
          int views = data['views'] ?? 0;
          DateTime dateAdded =
              (data['dateAdded'] as Timestamp?)?.toDate() ?? DateTime.now();
          String? youtubeUrl = data['youtubeUrl'];

          // Skip invalid hymns
          if (url.isEmpty) {
            return SizedBox.shrink();
          }

          // Convert data to HymnsModel
          var hymnModel = HymnsModel(
            id: hymn.id,
            songName: title,
            songUrl: url,
            songCategory: category,
            songAlbum: album,
            albumImageUrl: widget.albumImage,
            views: views,
            dateAdded: dateAdded,
            youtubeUrl: youtubeUrl,
          );

          bool isPlaying =
              widget.audioService.currentTitleNotifier.value == title;

          return HymnListItem(
            hymn: hymnModel,
            isPlaying: isPlaying,
            onTap: () {
              print('🎵 Hymn tapped: ${hymnModel.songName}');

              // مهم: تحقق فقط إذا كانت المعالجة جارية، ولكن لا تمنع النقر إذا كانت الترنيمة قيد التشغيل بالفعل
              if (_isProcessingTap || _disposed) {
                print('⚠️ Tap ignored - processing in progress or disposed');
                return;
              }

              // تعيين علامة المعالجة
              setState(() {
                _isProcessingTap = true;
              });

              // تشغيل الترنيمة مباشرة باستخدام الطريقة التقليدية
              _playHymnFromAlbum(hymnModel, index);
            },
            onToggleFavorite: (hymn) =>
                context.read<HymnsCubit>().toggleFavorite(hymn),
          );
        } catch (e) {
          print('❌ Error rendering hymn at index $index: $e');
          return SizedBox.shrink();
        }
      },
    );
  }

  // تعديل دالة _playHymnFromAlbum لتحسين تشغيل الترانيم من الألبوم
  Future<void> _playHymnFromAlbum(HymnsModel hymn, int index) async {
    if (_disposed) return;

    print('🎵 Playing hymn from album: ${hymn.songName} (ID: ${hymn.id})');
    print('🔍 Hymn URL: ${hymn.songUrl}');
    print('📋 Total hymns in album: ${_hymns.length}');
    print('📊 Selected hymn index: $index');

    try {
      // تعيين نوع قائمة التشغيل إلى ألبوم باستخدام الدالة العامة
      context.read<HymnsCubit>().setCurrentPlaylistType('album');
      context.read<HymnsCubit>().setCurrentPlaylistId(widget.albumName);

      // إيقاف التشغيل الحالي تمامًا
      await widget.audioService.stop();
      await Future.delayed(Duration(milliseconds: 300));

      // تحضير قوائم URLs و Titles لجميع ترانيم الألبوم
      List<String> urls = [];
      List<String> titles = [];
      List<int> validIndices = []; // لتتبع الفهارس الصالحة
      int validIndex = 0; // لتتبع الفهرس الصالح للترنيمة المحددة

      // إضافة جميع ترانيم الألبوم إلى قائمة التشغيل
      for (int i = 0; i < _hymns.length; i++) {
        var hymnData = _hymns[i].data() as Map<String, dynamic>;
        String url = hymnData['songUrl']?.toString() ?? '';
        String title = hymnData['songName']?.toString() ?? '';

        if (url.isNotEmpty && title.isNotEmpty) {
          urls.add(url);
          titles.add(title);
          validIndices.add(i);

          // تحديد الفهرس الصالح للترنيمة المحددة
          if (i == index) {
            validIndex = urls.length - 1;
          }
        }
      }

      if (urls.isEmpty) {
        print('⚠️ No valid hymns to play');
        if (mounted && !_disposed) {
          setState(() {
            _isProcessingTap = false;
          });
        }
        return;
      }

      print('📋 Prepared playlist with ${urls.length} hymns');
      print('🔍 Selected hymn valid index: $validIndex');

      // تعيين قائمة التشغيل الكاملة للألبوم
      await widget.audioService.setPlaylist(urls, titles);
      await Future.delayed(Duration(milliseconds: 300));

      // زيادة عدد المشاهدات مباشرة قبل التشغيل
      // try {
      //   await context.read<HymnsCubit>().incrementHymnViews(hymn.id);
      // } catch (e) {
      //   print('⚠️ Error incrementing view count: $e');
      // }
      print('👁️ View count will be incremented via callback');

      // تشغيل الترنيمة المحددة
      await widget.audioService.play(validIndex, titles[validIndex]);
      print('▶️ Started playing hymn at index $validIndex in album playlist');

      // تحديث مؤشر التشغيل الحالي
      if (mounted && !_disposed) {
        setState(() {
          _currentPlayingIndex = index;
        });
      }

      // حفظ آخر ترنيمة تم تشغيلها
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'lastPlayedHymn_${widget.albumName}', hymn.songName);

      print('✅ Hymn played from album successfully with complete playlist');
    } catch (e) {
      print('❌ Error playing hymn from album: $e');

      // محاولة بديلة باستخدام playFromBeginning
      try {
        print('🔄 Trying alternative method');

        // تأكد من تعيين سياق الألبوم حتى في الطريقة البديلة
        context.read<HymnsCubit>().setCurrentPlaylistType('album');
        context.read<HymnsCubit>().setCurrentPlaylistId(widget.albumName);

        // إيقاف التشغيل الحالي تمامًا
        await widget.audioService.stop();
        await Future.delayed(Duration(milliseconds: 300));

        // تعيين قائمة التشغيل مع الترنيمة المحددة فقط
        await widget.audioService.setPlaylist([hymn.songUrl], [hymn.songName]);
        await Future.delayed(Duration(milliseconds: 300));

        // استخدام playFromBeginning
        await widget.audioService.playFromBeginning(0, hymn.songName);
        print('▶️ Started playing hymn using alternative method');
      } catch (e2) {
        print('❌ All methods failed: $e2');

        // عرض رسالة خطأ للمستخدم
        if (mounted && !_disposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('حدث خطأ أثناء تشغيل الترنيمة. يرجى المحاولة مرة أخرى.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      // مهم جدًا: إعادة تعيين علامة المعالجة بعد الانتهاء
      if (mounted && !_disposed) {
        setState(() {
          _isProcessingTap = false;
        });
        print('🔄 Reset processing flag - ready for next tap');
      } else {
        _isProcessingTap = false;
      }
    }
  }
}
