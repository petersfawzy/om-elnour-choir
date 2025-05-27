import 'package:flutter/material.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';

class ExpandedMusicPlayer extends StatefulWidget {
  final MyAudioService audioService;
  final VoidCallback onCollapse;
  final String? albumName;
  final String? category;
  final String? albumImageUrl;
  final VoidCallback? onFavoriteChanged;

  const ExpandedMusicPlayer({
    Key? key,
    required this.audioService,
    required this.onCollapse,
    this.albumName,
    this.category,
    this.albumImageUrl,
    this.onFavoriteChanged,
  }) : super(key: key);

  @override
  State<ExpandedMusicPlayer> createState() => _ExpandedMusicPlayerState();
}

class _ExpandedMusicPlayerState extends State<ExpandedMusicPlayer>
    with TickerProviderStateMixin {
  double _dragStartPosition = 0;
  bool _isDraggingHorizontally = false;
  bool _disposed = false;
  String? _albumName;
  String? _category;
  String? _albumImageUrl;
  String? _youtubeUrl;
  String? _hymnId;
  String? _currentTitle;
  bool _isFavorite = false;
  bool _isCheckingFavorite = false;

  // إضافة متغير لتخزين معلومات الترانيم المحملة مسبقًا
  final Map<String, Map<String, dynamic>> _hymnDetailsCache = {};

  // Animation controllers for swipe animations
  late AnimationController _swipeAnimationController;
  late AnimationController _albumImageController;
  late Animation<double> _swipeAnimation;
  late Animation<double> _albumImageAnimation;
  late Animation<Offset> _slideAnimation;

  // Track swipe direction
  bool _isSwipingLeft = false;
  bool _isSwipingRight = false;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _swipeAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _albumImageController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    // Initialize animations
    _swipeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _swipeAnimationController,
      curve: Curves.easeInOut,
    ));

    _albumImageAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _albumImageController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(0.3, 0),
    ).animate(CurvedAnimation(
      parent: _swipeAnimationController,
      curve: Curves.easeInOut,
    ));

    // استخدام القيم المقدمة من الخارج إذا كانت متوفرة
    _albumName = widget.albumName;
    _category = widget.category;
    _albumImageUrl = widget.albumImageUrl;
    _currentTitle = widget.audioService.currentTitleNotifier.value;

    // تأخير إضافة المستمعين لتجنب مشاكل التزامن
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        widget.audioService.currentTitleNotifier.addListener(_onTitleChanged);
        widget.audioService.positionNotifier.addListener(_safeUpdateUI);
        widget.audioService.durationNotifier.addListener(_safeUpdateUI);
        widget.audioService.isPlayingNotifier.addListener(_safeUpdateUI);
        widget.audioService.isLoadingNotifier.addListener(_safeUpdateUI);

        // جلب معلومات الترنيمة بشكل آمن
        _fetchHymnDetails();
      }
    });
  }

  // دالة خاصة للاستجابة لتغيير الترنيمة
  void _onTitleChanged() {
    if (!_disposed && mounted) {
      final newTitle = widget.audioService.currentTitleNotifier.value;
      if (newTitle != _currentTitle) {
        _currentTitle = newTitle;
        _fetchHymnDetails();
        // Add animation when title changes
        _triggerTitleChangeAnimation();
      }
    }
  }

  // Animation when title changes
  void _triggerTitleChangeAnimation() {
    _albumImageController.forward().then((_) {
      if (mounted && !_disposed) {
        _albumImageController.reverse();
      }
    });
  }

  // دالة آمنة لتحديث واجهة المستخدم
  void _safeUpdateUI() {
    if (!_disposed && mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchHymnDetails() async {
    if (_disposed || !mounted) return;

    try {
      final currentTitle = widget.audioService.currentTitleNotifier.value;
      if (currentTitle == null || currentTitle.isEmpty) return;

      // التحقق من وجود معلومات الترنيمة في الذاكرة المؤقتة
      if (_hymnDetailsCache.containsKey(currentTitle)) {
        final cachedDetails = _hymnDetailsCache[currentTitle]!;
        if (mounted) {
          setState(() {
            _albumName = cachedDetails['albumName'] as String?;
            _category = cachedDetails['category'] as String?;
            _youtubeUrl = cachedDetails['youtubeUrl'] as String?;
            _hymnId = cachedDetails['hymnId'] as String?;
            _albumImageUrl = cachedDetails['albumImageUrl'] as String?;
          });

          // التحقق من حالة المفضلة
          if (_hymnId != null) {
            _checkFavoriteStatus();
          }
        }
        return;
      }

      // البحث عن الترنيمة في Firestore مع تحسين الاستعلام
      final hymnSnapshot = await FirebaseFirestore.instance
          .collection('hymns')
          .where('songName', isEqualTo: currentTitle)
          .limit(1)
          .get(
              GetOptions(source: Source.cache)); // محاولة الحصول من الكاش أولاً

      if (_disposed || !mounted) return;

      if (hymnSnapshot.docs.isNotEmpty) {
        final hymnDoc = hymnSnapshot.docs.first;
        final hymnData = hymnDoc.data();
        final albumName = hymnData['songAlbum'] as String?;
        final category = hymnData['songCategory'] as String?;
        final youtubeUrl = hymnData['youtubeUrl'] as String?;
        final hymnId = hymnDoc.id;
        final existingAlbumImage = hymnData['albumImageUrl'] as String?;

        // تخزين المعلومات الأساسية
        _hymnDetailsCache[currentTitle] = {
          'albumName': albumName,
          'category': category,
          'youtubeUrl': youtubeUrl,
          'hymnId': hymnId,
          'albumImageUrl': existingAlbumImage,
        };

        if (mounted) {
          setState(() {
            _albumName = albumName;
            _category = category;
            _youtubeUrl = youtubeUrl;
            _hymnId = hymnId;
            if (existingAlbumImage != null && existingAlbumImage.isNotEmpty) {
              _albumImageUrl = existingAlbumImage;
            }
          });

          // التحقق من حالة المفضلة
          _checkFavoriteStatus();
        }

        // إذا لم تكن هناك صورة ألبوم محفوظة مع الترنيمة، ابحث عنها
        if ((existingAlbumImage == null || existingAlbumImage.isEmpty) &&
            albumName != null &&
            albumName.isNotEmpty) {
          // البحث عن صورة الألبوم بشكل غير متزامن
          FirebaseFirestore.instance
              .collection('albums')
              .where('name', isEqualTo: albumName)
              .limit(1)
              .get(GetOptions(source: Source.cache))
              .then((albumSnapshot) {
            if (_disposed || !mounted) return;

            if (albumSnapshot.docs.isNotEmpty) {
              final albumData = albumSnapshot.docs.first.data();
              final imageUrl = albumData['image'] as String?;

              if (imageUrl != null && imageUrl.isNotEmpty) {
                // تحديث الذاكرة المؤقتة بصورة الألبوم
                if (_hymnDetailsCache.containsKey(currentTitle)) {
                  _hymnDetailsCache[currentTitle]!['albumImageUrl'] = imageUrl;
                }

                if (mounted) {
                  setState(() {
                    _albumImageUrl = imageUrl;
                  });
                }
              }
            }
          }).catchError((e) {
            print('❌ خطأ في جلب صورة الألبوم: $e');
          });
        }
      }
    } catch (e) {
      print('❌ خطأ في جلب معلومات الترنيمة: $e');
    }
  }

  Future<void> _checkFavoriteStatus() async {
    if (_hymnId == null || _isCheckingFavorite || _disposed || !mounted) return;

    setState(() {
      _isCheckingFavorite = true;
    });

    try {
      final isFavorite = await _checkIfFavorite(_hymnId!);
      if (mounted && !_disposed) {
        setState(() {
          _isFavorite = isFavorite;
          _isCheckingFavorite = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في التحقق من حالة المفضلة: $e');
      if (mounted && !_disposed) {
        setState(() {
          _isCheckingFavorite = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;

    // Dispose animation controllers
    _swipeAnimationController.dispose();
    _albumImageController.dispose();

    widget.audioService.currentTitleNotifier.removeListener(_onTitleChanged);
    widget.audioService.positionNotifier.removeListener(_safeUpdateUI);
    widget.audioService.durationNotifier.removeListener(_safeUpdateUI);
    widget.audioService.isPlayingNotifier.removeListener(_safeUpdateUI);
    widget.audioService.isLoadingNotifier.removeListener(_safeUpdateUI);

    super.dispose();
  }

  Future<bool> _checkIfFavorite(String hymnId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final favoriteSnapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: user.uid)
          .where('hymnId', isEqualTo: hymnId)
          .limit(1)
          .get();

      return favoriteSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ خطأ في التحقق من حالة المفضلة: $e');
      return false;
    }
  }

  Future<void> _toggleFavorite() async {
    if (_hymnId == null || _isCheckingFavorite) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
      );
      return;
    }

    setState(() {
      _isCheckingFavorite = true;
    });

    try {
      if (_isFavorite) {
        // إزالة من المفضلة
        final favoriteRef = await FirebaseFirestore.instance
            .collection('favorites')
            .where('userId', isEqualTo: user.uid)
            .where('hymnId', isEqualTo: _hymnId)
            .limit(1)
            .get();

        if (favoriteRef.docs.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('favorites')
              .doc(favoriteRef.docs.first.id)
              .delete();

          setState(() {
            _isFavorite = false;
            _isCheckingFavorite = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تمت إزالة الترنيمة من المفضلة')),
          );
        }
      } else {
        // إضافة إلى المفضلة
        final currentTitle = widget.audioService.currentTitleNotifier.value;
        if (currentTitle != null) {
          await FirebaseFirestore.instance.collection('favorites').add({
            'userId': user.uid,
            'hymnId': _hymnId,
            'songName': currentTitle,
            'songUrl': '', // يمكن إضافة URL الصوت هنا
            'dateAdded': FieldValue.serverTimestamp(),
          });

          setState(() {
            _isFavorite = true;
            _isCheckingFavorite = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تمت إضافة الترنيمة إلى المفضلة')),
          );
        }
      }

      // إشعار الصفحة الرئيسية بالتغيير
      if (widget.onFavoriteChanged != null) {
        widget.onFavoriteChanged!();
      }
    } catch (e) {
      print('❌ خطأ في تحديث المفضلة: $e');
      setState(() {
        _isCheckingFavorite = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحديث المفضلة')),
      );
    }
  }

  // Handle swipe animations
  void _handleSwipeStart(DragStartDetails details) {
    _isDraggingHorizontally = true;
    _dragStartPosition = details.globalPosition.dx;
  }

  void _handleSwipeUpdate(DragUpdateDetails details) {
    if (!_isDraggingHorizontally) return;

    final currentPosition = details.globalPosition.dx;
    final difference = currentPosition - _dragStartPosition;

    // Determine swipe direction
    if (difference > 20) {
      _isSwipingRight = true;
      _isSwipingLeft = false;
    } else if (difference < -20) {
      _isSwipingLeft = true;
      _isSwipingRight = false;
    }

    // Update animation progress based on swipe distance
    final progress = (difference.abs() / 100).clamp(0.0, 1.0);
    _swipeAnimationController.value = progress;
  }

  void _handleSwipeEnd(DragEndDetails details) {
    if (!_isDraggingHorizontally) return;

    // Reset animation
    _swipeAnimationController.reverse();

    // Execute action based on swipe direction and velocity
    if (details.primaryVelocity != null) {
      if (details.primaryVelocity! > 500 || _isSwipingRight) {
        // Swipe right - previous hymn
        _animateAndPlayPrevious();
      } else if (details.primaryVelocity! < -500 || _isSwipingLeft) {
        // Swipe left - next hymn
        _animateAndPlayNext();
      }
    }

    // Reset swipe states
    _isDraggingHorizontally = false;
    _isSwipingLeft = false;
    _isSwipingRight = false;
  }

  void _animateAndPlayNext() {
    _albumImageController.forward().then((_) {
      widget.audioService.playNext();
      if (mounted && !_disposed) {
        _albumImageController.reverse();
      }
    });
  }

  void _animateAndPlayPrevious() {
    _albumImageController.forward().then((_) {
      widget.audioService.playPrevious();
      if (mounted && !_disposed) {
        _albumImageController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    try {
      // التحقق من اتجاه الشاشة
      final isLandscape =
          MediaQuery.of(context).orientation == Orientation.landscape;
      // الحصول على أبعاد الشاشة
      final screenSize = MediaQuery.of(context).size;

      return Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: GestureDetector(
          onVerticalDragStart: (details) {
            _dragStartPosition = details.globalPosition.dy;
          },
          onVerticalDragUpdate: (details) {
            // إذا كان السحب لأسفل كافيًا، طي المشغل
            if (details.globalPosition.dy - _dragStartPosition > 100) {
              widget.onCollapse();
            }
          },
          onHorizontalDragStart: _handleSwipeStart,
          onHorizontalDragUpdate: _handleSwipeUpdate,
          onHorizontalDragEnd: _handleSwipeEnd,
          child: SafeArea(
            child: isLandscape
                ? _buildLandscapeLayout(screenSize)
                : Stack(
                    children: [
                      // المحتوى الرئيسي
                      Positioned.fill(
                        bottom:
                            60, // إضافة هامش سفلي للمحتوى لتجنب تداخله مع الإعلان
                        child: _buildPortraitLayout(),
                      ),

                      // الإعلان في الأسفل (فقط في الوضع الرأسي)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: AdBanner(
                          key: ValueKey('expanded_player_portrait_ad'),
                          cacheKey: 'expanded_music_player_portrait',
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );
    } catch (e) {
      // في حالة حدوث خطأ، نعرض واجهة بسيطة للطي
      print('❌ خطأ في بناء المشغل الموسع: $e');
      return Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'حدث خطأ في عرض المشغل',
                  style: TextStyle(color: AppColors.appamber, fontSize: 18),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: widget.onCollapse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.appamber,
                    foregroundColor: Colors.black,
                  ),
                  child: Text('العودة'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // تخطيط للوضع الرأسي (العادي)
  Widget _buildPortraitLayout() {
    return Column(
      children: [
        // شريط علوي مع زر للطي
        _buildHeader(),

        // صورة الألبوم مع الأنيميشن
        _buildAnimatedAlbumArt(),

        // معلومات الأغنية
        _buildSongInfo(),

        // شريط التقدم
        _buildProgressBar(),

        // أزرار التحكم
        _buildControlButtons(),

        // معلومات إضافية
        _buildAdditionalInfo(),
      ],
    );
  }

  // تخطيط للوضع الأفقي - الآن يأخذ حجم الشاشة كمعامل
  Widget _buildLandscapeLayout(Size screenSize) {
    // تحديد حجم الخط بناءً على عرض الشاشة
    final titleFontSize = screenSize.width * 0.022; // ~22px على شاشة 1000px
    final subtitleFontSize = screenSize.width * 0.016; // ~16px على شاشة 1000px

    return Row(
      children: [
        // الجانب الأيسر: صورة الألبوم والإعلان
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // زر العودة في الأعلى
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                  child: IconButton(
                    icon: Icon(Icons.keyboard_arrow_down,
                        color: AppColors.appamber, size: 24),
                    onPressed: widget.onCollapse,
                  ),
                ),
              ),

              // صورة الألبوم مع الأنيميشن
              Expanded(
                flex: 3,
                child: _buildAnimatedAlbumArt(),
              ),

              // الإعلان تحت الصورة
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: AdBanner(
                    key: ValueKey('expanded_player_landscape_ad'),
                    cacheKey: 'expanded_music_player_landscape',
                  ),
                ),
              ),
            ],
          ),
        ),

        // الجانب الأيمن: معلومات وأزرار التحكم
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // زر القلب في الأعلى
                Align(
                  alignment: Alignment.topRight,
                  child: _buildFavoriteButton(),
                ),

                // معلومات الأغنية والتحكم
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              // اسم الترنيمة
                              Text(
                                widget.audioService.currentTitleNotifier
                                        .value ??
                                    'لا توجد ترنيمة',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.appamber,
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 8),

                              // اسم الألبوم
                              if (_albumName != null)
                                Text(
                                  _albumName!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.appamber.withOpacity(0.7),
                                    fontSize: subtitleFontSize,
                                  ),
                                ),
                              SizedBox(height: 4),

                              // التصنيف
                              if (_category != null)
                                Text(
                                  _category!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.appamber.withOpacity(0.7),
                                    fontSize: subtitleFontSize,
                                  ),
                                ),

                              // شريط التقدم
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12.0),
                                child: _buildProgressBar(),
                              ),

                              // أزرار التحكم
                              _buildControlButtons(),

                              // زر يوتيوب
                              if (_youtubeUrl != null &&
                                  _youtubeUrl!.isNotEmpty) ...[
                                SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.play_circle_outline,
                                        color: Colors.white),
                                    label: Text('مشاهدة على يوتيوب'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                    ),
                                    onPressed: () async {
                                      try {
                                        if (await canLaunch(_youtubeUrl!)) {
                                          await launch(_youtubeUrl!);
                                        }
                                      } catch (e) {
                                        print('❌ خطأ في فتح الرابط: $e');
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.keyboard_arrow_down,
                color: AppColors.appamber, size: 30),
            onPressed: widget.onCollapse,
          ),
          Spacer(), // بدلاً من Expanded مع النص
          _buildFavoriteButton(),
        ],
      ),
    );
  }

  Widget _buildFavoriteButton() {
    if (_isCheckingFavorite) {
      return Container(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.appamber),
        ),
      );
    }

    return IconButton(
      icon: Icon(
        _isFavorite ? Icons.favorite : Icons.favorite_border,
        color: _isFavorite ? Colors.red : AppColors.appamber,
        size: 24,
      ),
      onPressed: _toggleFavorite,
    );
  }

  Widget _buildAnimatedAlbumArt() {
    return Expanded(
      flex: 5,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: AnimatedBuilder(
          animation: _albumImageAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _albumImageAnimation.value,
              child: AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: _isSwipingLeft
                        ? Offset(-_slideAnimation.value.dx * 100, 0)
                        : _isSwipingRight
                            ? Offset(_slideAnimation.value.dx * 100, 0)
                            : Offset.zero,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            // الصورة الرئيسية
                            _albumImageUrl != null && _albumImageUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: _albumImageUrl!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[800],
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  AppColors.appamber),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Image.asset(
                                      'assets/images/logo.png',
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),

                            // مؤشر السحب
                            if (_isDraggingHorizontally)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: (_isSwipingLeft
                                            ? Colors.blue
                                            : Colors.green)
                                        .withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      _isSwipingLeft
                                          ? Icons.skip_next
                                          : Icons.skip_previous,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSongInfo() {
    final currentTitle =
        widget.audioService.currentTitleNotifier.value ?? 'لا توجد ترنيمة';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.appamber,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 8),
          if (_albumName != null)
            Text(
              _albumName!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.appamber.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          SizedBox(height: 4),
          if (_category != null)
            Text(
              _category!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.appamber.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          // تم إزالة النص الإرشادي من هنا
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final position = widget.audioService.positionNotifier.value;
    final duration =
        widget.audioService.durationNotifier.value ?? Duration.zero;

    // التأكد من أن الموضع لا يتجاوز المدة الإجمالية
    double maxDuration = duration.inSeconds.toDouble();
    double currentPosition = position.inSeconds.toDouble();

    if (maxDuration > 0 && currentPosition > maxDuration) {
      currentPosition = maxDuration;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min, // تقييد الحجم
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: AppColors.appamber,
              inactiveTrackColor: AppColors.appamber.withOpacity(0.3),
              thumbColor: AppColors.appamber,
              overlayColor: AppColors.appamber.withOpacity(0.3),
            ),
            child: Slider(
              min: 0,
              max: maxDuration > 0 ? maxDuration : 1.0,
              value:
                  currentPosition.clamp(0, maxDuration > 0 ? maxDuration : 1.0),
              onChanged: (value) {
                widget.audioService.seek(Duration(seconds: value.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: TextStyle(
                    color: AppColors.appamber.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    color: AppColors.appamber.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    final isPlaying = widget.audioService.isPlayingNotifier.value;
    final isLoading = widget.audioService.isLoadingNotifier.value;
    final repeatMode = widget.audioService.repeatModeNotifier.value;
    final isShuffling = widget.audioService.isShufflingNotifier.value;

    // تحديد حجم الأزرار بناءً على اتجاه الشاشة
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final mainButtonSize = isLandscape ? 56.0 : 64.0;
    final mainIconSize = isLandscape ? 28.0 : 32.0;
    final secondaryIconSize = isLandscape ? 24.0 : 28.0;
    final skipIconSize = isLandscape ? 36.0 : 40.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // زر التكرار
          IconButton(
            icon: Icon(
              repeatMode == 1 ? Icons.repeat_one : Icons.repeat,
              color: repeatMode > 0
                  ? AppColors.appamber
                  : AppColors.appamber.withOpacity(0.5),
              size: secondaryIconSize,
            ),
            onPressed: widget.audioService.toggleRepeat,
          ),

          // زر السابق مع أنيميشن
          IconButton(
            icon: Icon(Icons.skip_previous,
                color: AppColors.appamber, size: skipIconSize),
            onPressed: _animateAndPlayPrevious,
          ),

          // زر تشغيل/إيقاف مؤقت
          isLoading
              ? Container(
                  width: mainButtonSize,
                  height: mainButtonSize,
                  decoration: BoxDecoration(
                    color: AppColors.appamber.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: mainButtonSize * 0.5,
                      height: mainButtonSize * 0.5,
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.appamber),
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: widget.audioService.togglePlayPause,
                  child: Container(
                    width: mainButtonSize,
                    height: mainButtonSize,
                    decoration: BoxDecoration(
                      color: AppColors.appamber,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.black,
                        size: mainIconSize,
                      ),
                    ),
                  ),
                ),

          // زر التالي مع أنيميشن
          IconButton(
            icon: Icon(Icons.skip_next,
                color: AppColors.appamber, size: skipIconSize),
            onPressed: _animateAndPlayNext,
          ),

          // زر الخلط
          IconButton(
            icon: Icon(
              Icons.shuffle,
              color: isShuffling
                  ? AppColors.appamber
                  : AppColors.appamber.withOpacity(0.5),
              size: secondaryIconSize,
            ),
            onPressed: widget.audioService.toggleShuffle,
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // إضافة زر مشاهدة على يوتيوب إذا كان متاحًا
            if (_youtubeUrl != null && _youtubeUrl!.isNotEmpty) ...[
              ElevatedButton.icon(
                icon: Icon(Icons.play_circle_outline, color: Colors.white),
                label: Text('مشاهدة على يوتيوب'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () async {
                  try {
                    if (await canLaunch(_youtubeUrl!)) {
                      await launch(_youtubeUrl!);
                    }
                  } catch (e) {
                    print('❌ خطأ في فتح الرابط: $e');
                  }
                },
              ),
              SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
