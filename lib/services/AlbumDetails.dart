import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Register the callback for view count increments
    widget.audioService.registerHymnChangedCallback(_onHymnChangedCallback);

    // تعيين سياق قائمة التشغيل عند بدء الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_disposed) {
        // تعيين سياق الألبوم
        context.read<HymnsCubit>().setCurrentPlaylistType('album');
        context.read<HymnsCubit>().setCurrentPlaylistId(widget.albumName);
        print('📋 تم تسجيل سياق الألبوم عند بدء الصفحة: ${widget.albumName}');

        // حفظ سياق الألبوم في التخزين المؤقت
        context.read<HymnsCubit>().saveStateOnAppClose();
      }
    });

    _initializeData();
  }

  // تعديل دالة callback لزيادة عدد المشاهدات
  void _onHymnChangedCallback(int index, String title) {
    try {
      // تنفيذ زيادة عدد المشاهدات
      if (index >= 0 && index < _hymns.length) {
        final hymnId = _hymns[index].id;
        print(
            '📊 زيادة عدد مشاهدات الترنيمة في AlbumDetails: $title (ID: $hymnId)');

        // استخدام HymnsCubit لزيادة عدد المشاهدات
        context.read<HymnsCubit>().incrementHymnViews(hymnId);
      } else {
        print('⚠️ فهرس غير صالح في callback زيادة المشاهدات: $index');
      }
    } catch (e) {
      print('❌ خطأ في زيادة عدد المشاهدات: $e');
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

      // تحديث سياق الألبوم
      if (mounted && !_disposed) {
        context.read<HymnsCubit>().setCurrentPlaylistType('album');
        context.read<HymnsCubit>().setCurrentPlaylistId(widget.albumName);
        print(
            '📋 تم تحديث سياق الألبوم عند استئناف التطبيق: ${widget.albumName}');
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // حفظ سياق الألبوم عند إيقاف التطبيق
      if (mounted && !_disposed) {
        context.read<HymnsCubit>().setCurrentPlaylistType('album');
        context.read<HymnsCubit>().setCurrentPlaylistId(widget.albumName);
        context.read<HymnsCubit>().saveStateOnAppClose();
        print('💾 تم حفظ سياق الألبوم عند إيقاف التطبيق: ${widget.albumName}');
      }
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

    // حفظ سياق الألبوم قبل الخروج من الصفحة
    if (!_disposed) {
      context.read<HymnsCubit>().setCurrentPlaylistType('album');
      context.read<HymnsCubit>().setCurrentPlaylistId(widget.albumName);
      context.read<HymnsCubit>().saveStateOnAppClose();
      print('💾 تم حفظ سياق الألبوم عند الخروج من الصفحة: ${widget.albumName}');
    }

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
                    errorWidget: (context, error, stackTrace) => Container(
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

        // Music player without fixed container height
        MusicPlayerWidget(
            key: ValueKey('music_player_portrait'),
            audioService: widget.audioService),

        // إضافة مسافة بين مشغل الترانيم والإعلان
        SizedBox(height: 8),

        // Ad banner without fixed height - will only take space if ad is loaded
        AdBanner(
          key: ValueKey('album_ad_banner_portrait'),
          cacheKey: 'album_details_${widget.albumName}_portrait',
          audioService: widget.audioService,
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
                              errorWidget: (context, error, stackTrace) =>
                                  Container(
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Music player - 75% of width
            Expanded(
              flex: 75,
              child: MusicPlayerWidget(
                  key: ValueKey('music_player_landscape'),
                  audioService: widget.audioService),
            ),
            // إضافة مسافة بين المشغل والإعلان
            SizedBox(width: 8),
            // Ad - 25% of width, will only take space if ad is loaded
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

              // FIX: Remove the check that prevents playing a new hymn while processing a tap
              // This allows users to tap on a new hymn even if the previous tap is still being processed
              // We'll still set _isProcessingTap to true to track the state, but we won't block new taps

              // Set processing flag
              setState(() {
                _isProcessingTap = true;
              });

              // Play the hymn directly using the traditional method
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

  // تعديل دالة _playHymnFromAlbum لإصلاح مشكلة عدم تشغيل الترانيم في الألبومات
  Future<void> _playHymnFromAlbum(HymnsModel hymn, int index) async {
    if (_disposed) return;

    try {
      print('🎵 تشغيل ترنيمة من الألبوم: ${hymn.songName} (ID: ${hymn.id})');

      // تعيين سياق قائمة التشغيل
      context.read<HymnsCubit>().setCurrentPlaylistType('album');
      context.read<HymnsCubit>().setCurrentPlaylistId(widget.albumName);
      print('📋 تم تعيين سياق الألبوم: ${widget.albumName}');

      // زيادة عدد المشاهدات يدوياً
      try {
        context.read<HymnsCubit>().incrementHymnViews(hymn.id);
        print(
            '📊 تمت زيادة عدد مشاهدات الترنيمة يدوياً: ${hymn.songName} (ID: ${hymn.id})');
      } catch (e) {
        print('⚠️ خطأ في زيادة عدد المشاهدات يدوياً: $e');
      }

      // إعداد قائمة التشغيل
      List<String> urls = [];
      List<String> titles = [];

      for (var doc in _hymns) {
        var data = doc.data() as Map<String, dynamic>;
        String url = data['songUrl'] ?? '';
        String title = data['songName'] ?? '';

        if (url.isNotEmpty && title.isNotEmpty) {
          urls.add(url);
          titles.add(title);
        }
      }

      if (urls.isEmpty) {
        print('⚠️ لا توجد ترانيم صالحة للتشغيل');
        return;
      }

      try {
        // إيقاف التشغيل الحالي بأمان
        await widget.audioService.stop();
        print('⏹️ تم إيقاف التشغيل الحالي');

        // إضافة تأخير صغير للتأكد من إغلاق الاتصالات السابقة
        await Future.delayed(Duration(milliseconds: 300));
      } catch (e) {
        print('⚠️ خطأ في إيقاف التشغيل الحالي: $e');
        // استمر رغم الخطأ
      }

      // إضافة مؤشر تحميل
      setState(() {
        _isProcessingTap = true;
      });

      // تعيين قائمة التشغيل
      await widget.audioService.setPlaylist(urls, titles);
      print('📋 تم تعيين قائمة التشغيل: ${titles.length} ترنيمة');

      // تشغيل الترنيمة بدون زيادة عدد المشاهدات
      try {
        await widget.audioService.play(index, hymn.songName);
        print('▶️ تم بدء تشغيل الترنيمة: ${hymn.songName}');

        // تحديث مؤشر التشغيل الحالي
        if (mounted && !_disposed) {
          setState(() {
            _currentPlayingIndex = index;
          });
        }
      } catch (e) {
        print('❌ خطأ في تشغيل الترنيمة: $e');

        // عرض رسالة للمستخدم
        if (mounted && !_disposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('جاري محاولة تشغيل الترنيمة...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        // محاولة ثانية بعد تأخير قصير
        await Future.delayed(Duration(milliseconds: 800));

        try {
          await widget.audioService.play(index, hymn.songName);
          print('▶️ نجحت المحاولة الثانية لتشغيل الترنيمة: ${hymn.songName}');

          // تحديث مؤشر التشغيل الحالي
          if (mounted && !_disposed) {
            setState(() {
              _currentPlayingIndex = index;
            });
          }
        } catch (e2) {
          print('❌ فشلت المحاولة الثانية لتشغيل الترنيمة: $e2');

          if (mounted && !_disposed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'حدث خطأ أثناء تشغيل الترنيمة. يرجى المحاولة مرة أخرى.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }

      // حفظ آخر ترنيمة تم تشغيلها
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'lastPlayedHymn_${widget.albumName}', hymn.songName);
      } catch (e) {
        print('⚠️ خطأ في حفظ آخر ترنيمة: $e');
      }

      print('✅ تم تشغيل الترنيمة من الألبوم بنجاح');
    } catch (e) {
      print('❌ خطأ في تشغيل الترنيمة من الألبوم: $e');

      if (mounted && !_disposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('حدث خطأ أثناء تشغيل الترنيمة. يرجى المحاولة مرة أخرى.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // إعادة تعيين علامة المعالجة بعد تأخير أطول للسماح باكتمال العملية
      Future.delayed(Duration(milliseconds: 1000), () {
        if (mounted && !_disposed) {
          setState(() {
            _isProcessingTap = false;
          });
        } else {
          _isProcessingTap = false;
        }
      });
    }
  }
}
