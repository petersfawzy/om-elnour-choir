import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner_wrapper.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:om_elnour_choir/shared/shared_widgets/general_hymns_list.dart';
import 'package:om_elnour_choir/shared/shared_widgets/music_player_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class CategoryHymns extends StatefulWidget {
  final String categoryName;
  final MyAudioService audioService;

  const CategoryHymns({
    Key? key,
    required this.categoryName,
    required this.audioService,
  }) : super(key: key);

  @override
  _CategoryHymnsState createState() => _CategoryHymnsState();
}

class _CategoryHymnsState extends State<CategoryHymns>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _disposed = false;
  String? _errorMessage;
  List<HymnsModel> _hymns = [];
  StreamSubscription? _hymnsSubscription;
  bool _isProcessingTap = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Register the callback for view count increments
    print('🔄 تسجيل callback لزيادة عدد المشاهدات في CategoryHymns');
    //widget.audioService.registerHymnChangedCallback(_onHymnChangedCallback);

    // تسجيل سياق قائمة التشغيل عند بدء الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_disposed) {
        // تعيين سياق التصنيف - تحقق مما إذا كان السياق الحالي مختلفًا
        final currentType = context.read<HymnsCubit>().currentPlaylistType;
        final currentId = context.read<HymnsCubit>().currentPlaylistId;

        if (currentType != 'category' || currentId != widget.categoryName) {
          context.read<HymnsCubit>().setCurrentPlaylistType('category');
          context.read<HymnsCubit>().setCurrentPlaylistId(widget.categoryName);
          print(
              '📋 تم تسجيل سياق التصنيف عند بدء الصفحة: ${widget.categoryName}');
        } else {
          print('ℹ️ سياق التصنيف لم يتغير: ${widget.categoryName}');
        }

        // حفظ سياق التصنيف في التخزين المؤقت
        context.read<HymnsCubit>().saveStateOnAppClose();
      }
    });

    _initializeData();
  }

  // Callback method for view count increments
  /*void _onHymnChangedCallback(int index, String title) {
    if (_disposed) return;

    print('📊 تم استدعاء callback في CategoryHymns للترنيمة: $title');

    // البحث عن الترنيمة في قائمتنا
    int hymnIndex = _hymns.indexWhere((h) => h.songName == title);

    if (hymnIndex != -1) {
      // زيادة عدد المشاهدات باستخدام HymnsCubit
      final hymnId = _hymns[hymnIndex].id;
      context.read<HymnsCubit>().incrementHymnViews(hymnId);
      print('📊 تم زيادة عدد المشاهدات للترنيمة: $title (ID: $hymnId) من CategoryHymns');
    } else {
      // محاولة البحث بالتطابق الجزئي إذا فشل التطابق الدقيق
      for (int i = 0; i < _hymns.length; i++) {
        if (title.contains(_hymns[i].songName) ||
            _hymns[i].songName.contains(title)) {
          final hymnId = _hymns[i].id;
          context.read<HymnsCubit>().incrementHymnViews(hymnId);
          print('📊 تم زيادة عدد المشاهدات للترنيمة بالتطابق الجزئي: ${_hymns[i].songName} (ID: $hymnId)');
          break;
        }
      }
    }
  }*/

  Future<void> _initializeData() async {
    try {
      await _loadHymns();
      await _loadLastPlayedHymn();

      if (mounted && !_disposed) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في تهيئة تفاصيل التصنيف: $e');
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
      // تحديث سياق التصنيف
      if (mounted && !_disposed) {
        // تحقق مما إذا كان السياق الحالي مختلفًا
        final currentType = context.read<HymnsCubit>().currentPlaylistType;
        final currentId = context.read<HymnsCubit>().currentPlaylistId;

        if (currentType != 'category' || currentId != widget.categoryName) {
          context.read<HymnsCubit>().setCurrentPlaylistType('category');
          context.read<HymnsCubit>().setCurrentPlaylistId(widget.categoryName);
          print(
              '📋 تم تحديث سياق التصنيف عند استئناف التطبيق: ${widget.categoryName}');
        }
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App went to background or is about to be closed
      if (mounted && !_disposed) {
        // حفظ سياق التصنيف
        context.read<HymnsCubit>().setCurrentPlaylistType('category');
        context.read<HymnsCubit>().setCurrentPlaylistId(widget.categoryName);
        context.read<HymnsCubit>().saveStateOnAppClose();
        print(
            '💾 تم حفظ سياق التصنيف عند إيقاف التطبيق: ${widget.categoryName}');
      }
    }
  }

  /// ✅ Load hymns from Firestore
  Future<void> _loadHymns() async {
    try {
      print('🔄 تحميل ترانيم التصنيف: ${widget.categoryName}');

      // Cancel any existing subscription
      await _hymnsSubscription?.cancel();

      // Create new subscription
      _hymnsSubscription = FirebaseFirestore.instance
          .collection('hymns')
          .where('songCategory', isEqualTo: widget.categoryName)
          .snapshots()
          .listen(
        (snapshot) {
          if (mounted && !_disposed) {
            List<HymnsModel> loadedHymns = snapshot.docs.map((doc) {
              final data = doc.data();
              return HymnsModel(
                id: doc.id,
                songName: data['songName'] ?? '',
                songUrl: data['songUrl'] ?? '',
                songCategory: data['songCategory'] ?? '',
                songAlbum: data['songAlbum'] ?? '',
                views: data['views'] ?? 0,
                dateAdded: (data['dateAdded'] as Timestamp).toDate(),
                youtubeUrl: data['youtubeUrl'],
              );
            }).toList();

            setState(() {
              _hymns = loadedHymns;
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          print('❌ خطأ في تدفق الترانيم: $error');
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
      print('❌ خطأ في تحميل الترانيم: $e');
      rethrow;
    }
  }

  /// ✅ Load last played hymn in category
  Future<void> _loadLastPlayedHymn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? lastPlayedHymn =
          prefs.getString('lastPlayedHymn_${widget.categoryName}');

      if (lastPlayedHymn != null && mounted && !_disposed) {
        int index = _hymns.indexWhere((h) => h.songName == lastPlayedHymn);

        if (index != -1) {
          print('✅ تم العثور على آخر ترنيمة تم تشغيلها: $lastPlayedHymn');
        }
      }
    } catch (e) {
      print('❌ خطأ في تحميل آخر ترنيمة تم تشغيلها: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);

    // إلغاء تسجيل الـ callback بشكل صري��
    print('🔄 إلغاء تسجيل callback زيادة عدد المشاهدات في CategoryHymns');
    //widget.audioService.registerHymnChangedCallback(null);

    // حفظ سياق التصنيف قبل الخروج من الصفحة
    if (!_disposed) {
      context.read<HymnsCubit>().setCurrentPlaylistType('category');
      context.read<HymnsCubit>().setCurrentPlaylistId(widget.categoryName);
      context.read<HymnsCubit>().saveStateOnAppClose();
      print(
          '💾 تم حفظ سياق التصنيف عند الخروج من الصفحة: ${widget.categoryName}');
    }

    // Cancel subscriptions
    _hymnsSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text(
          widget.categoryName,
          style: TextStyle(color: AppColors.appamber),
        ),
        leading: BackBtn(),
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingView()
            : _errorMessage != null
                ? _buildErrorView()
                : Column(
                    children: [
                      // Hymns list
                      Expanded(
                        child: GeneralHymnsList(
                          hymnsCubit: context.read<HymnsCubit>(),
                          hymns: _hymns,
                          playlistType: 'category',
                          playlistId: widget.categoryName,
                        ),
                      ),

                      // Music player and ad
                      if (isLandscape)
                        // In landscape mode: show player and ad side by side
                        Container(
                          height: MediaQuery.of(context).size.height * 0.25,
                          child: Row(
                            children: [
                              // Music player - 70% of width
                              Expanded(
                                flex: 70,
                                child: MusicPlayerWidget(
                                    audioService: widget.audioService),
                              ),
                              // Ad - 30% of width
                              Expanded(
                                flex: 30,
                                child: AdBannerWrapper(
                                  cacheKey:
                                      'category_${widget.categoryName}_landscape',
                                  audioService: widget.audioService,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        // In portrait mode: show player and ad stacked
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Music player
                            MusicPlayerWidget(
                                audioService: widget.audioService),
                            // Ad
                            Container(
                              height: 50, // Fixed height for ad
                              child: AdBannerWrapper(
                                cacheKey:
                                    'category_${widget.categoryName}_portrait',
                                audioService: widget.audioService,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
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
}
