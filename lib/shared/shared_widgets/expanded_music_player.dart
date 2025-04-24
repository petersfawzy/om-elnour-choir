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

  const ExpandedMusicPlayer({
    Key? key,
    required this.audioService,
    required this.onCollapse,
    this.albumName,
    this.category,
    this.albumImageUrl,
  }) : super(key: key);

  @override
  State<ExpandedMusicPlayer> createState() => _ExpandedMusicPlayerState();
}

class _ExpandedMusicPlayerState extends State<ExpandedMusicPlayer> {
  double _dragStartPosition = 0;
  bool _isDraggingHorizontally = false;
  bool _disposed = false;
  String? _albumName;
  String? _category;
  String? _albumImageUrl;
  String? _youtubeUrl;
  String? _hymnId;
  String? _currentTitle;

  // إضافة متغير لتخزين معلومات الترانيم المحملة مسبقًا
  final Map<String, Map<String, dynamic>> _hymnDetailsCache = {};

  @override
  void initState() {
    super.initState();

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
      }
    }
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
        setState(() {
          _albumName = cachedDetails['albumName'] as String?;
          _category = cachedDetails['category'] as String?;
          _youtubeUrl = cachedDetails['youtubeUrl'] as String?;
          _hymnId = cachedDetails['hymnId'] as String?;
          _albumImageUrl = cachedDetails['albumImageUrl'] as String?;
        });
        return;
      }

      // البحث عن الترنيمة في Firestore
      final hymnSnapshot = await FirebaseFirestore.instance
          .collection('hymns')
          .where('songName', isEqualTo: currentTitle)
          .limit(1)
          .get();

      if (_disposed || !mounted) return;

      if (hymnSnapshot.docs.isNotEmpty) {
        final hymnDoc = hymnSnapshot.docs.first;
        final hymnData = hymnDoc.data();
        final albumName = hymnData['songAlbum'] as String?;
        final category = hymnData['songCategory'] as String?;
        final youtubeUrl = hymnData['youtubeUrl'] as String?;
        final hymnId = hymnDoc.id;

        // تخزين المعلومات الأساسية
        _hymnDetailsCache[currentTitle] = {
          'albumName': albumName,
          'category': category,
          'youtubeUrl': youtubeUrl,
          'hymnId': hymnId,
          'albumImageUrl': null,
        };

        setState(() {
          _albumName = albumName;
          _category = category;
          _youtubeUrl = youtubeUrl;
          _hymnId = hymnId;
        });

        // إذا كان هناك اسم ألبوم، ابحث عن صورة الألبوم
        if (albumName != null && albumName.isNotEmpty) {
          final albumSnapshot = await FirebaseFirestore.instance
              .collection('albums')
              .where('name', isEqualTo: albumName)
              .limit(1)
              .get();

          if (_disposed || !mounted) return;

          if (albumSnapshot.docs.isNotEmpty) {
            final albumData = albumSnapshot.docs.first.data();
            final imageUrl = albumData['image'] as String?;

            // تحديث الذاكرة المؤقتة بصورة الألبوم
            if (_hymnDetailsCache.containsKey(currentTitle)) {
              _hymnDetailsCache[currentTitle]!['albumImageUrl'] = imageUrl;
            }

            setState(() {
              _albumImageUrl = imageUrl;
            });
          }
        }
      }
    } catch (e) {
      print('❌ خطأ في جلب معلومات الترنيمة: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;

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
    if (_hymnId == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
      );
      return;
    }

    try {
      final isFavorite = await _checkIfFavorite(_hymnId!);

      if (isFavorite) {
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

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تمت إضافة الترنيمة إلى المفضلة')),
          );
        }
      }

      // تحديث واجهة المستخدم
      setState(() {});
    } catch (e) {
      print('❌ خطأ في تحديث المفضلة: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحديث المفضلة')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      // التحقق من اتجاه الشاشة
      final isLandscape =
          MediaQuery.of(context).orientation == Orientation.landscape;

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
          onHorizontalDragStart: (details) {
            _isDraggingHorizontally = true;
            _dragStartPosition = details.globalPosition.dx;
          },
          onHorizontalDragUpdate: (details) {
            // فقط متابعة السحب، لا نفعل شيئًا هنا
          },
          onHorizontalDragEnd: (details) {
            if (!_isDraggingHorizontally) return;

            // إذا كان السحب إلى اليمين، تشغيل الأغنية السابقة
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 0) {
              widget.audioService.playPrevious();
            }
            // إذا كان السحب إلى اليسار، تشغيل الأغنية التالية
            else if (details.primaryVelocity != null &&
                details.primaryVelocity! < 0) {
              widget.audioService.playNext();
            }

            _isDraggingHorizontally = false;
          },
          child: Stack(
            children: [
              // المحتوى الرئيسي
              Positioned.fill(
                bottom: 60, // إضافة هامش سفلي للمحتوى لتجنب تداخله مع الإعلان
                child: SafeArea(
                  child: isLandscape
                      ? _buildLandscapeLayout()
                      : _buildPortraitLayout(),
                ),
              ),

              // الإعلان في الأسفل
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AdBanner(
                  key: ValueKey('expanded_player_ad'),
                  cacheKey: 'expanded_music_player',
                ),
              ),
            ],
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

        // صورة الألبوم
        _buildAlbumArt(),

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

  // تخطيط للوضع الأفقي
  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // الجانب الأيسر: صورة الألبوم
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // زر العودة في الأعلى
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: Icon(Icons.keyboard_arrow_down,
                        color: AppColors.appamber, size: 30),
                    onPressed: widget.onCollapse,
                  ),
                ),

                // صورة الألبوم
                Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 8),
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
                      child: _albumImageUrl != null &&
                              _albumImageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _albumImageUrl!,
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
                              errorWidget: (context, url, error) => Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // الجانب الأيمن: معلومات وأزرار التحكم
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // زر القلب في الأعلى
                Align(
                  alignment: Alignment.topRight,
                  child: FutureBuilder<bool>(
                    future: _hymnId != null
                        ? _checkIfFavorite(_hymnId!)
                        : Future.value(false),
                    builder: (context, snapshot) {
                      final isFavorite = snapshot.data ?? false;
                      return IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : AppColors.appamber,
                          size: 24,
                        ),
                        onPressed: () => _toggleFavorite(),
                      );
                    },
                  ),
                ),

                // معلومات الأغنية
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // اسم الترنيمة
                        Text(
                          widget.audioService.currentTitleNotifier.value ??
                              'لا توجد ترنيمة',
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

                        // اسم الألبوم
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

                        // التصنيف
                        if (_category != null)
                          Text(
                            _category!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.appamber.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),

                        // شريط التقدم
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: _buildProgressBar(),
                        ),

                        // أزرار التحكم
                        _buildControlButtons(),

                        // زر يوتيوب
                        if (_youtubeUrl != null && _youtubeUrl!.isNotEmpty) ...[
                          SizedBox(height: 16),
                          ElevatedButton.icon(
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
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // بعد دالة _buildLandscapeLayout() وقبل دالة _buildAlbumArt()، أضف تعريف دالة _buildHeader():

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
          Expanded(
            child: Center(
              child: Text(
                'الترنيمة الحالية',
                style: TextStyle(
                  color: AppColors.appamber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          FutureBuilder<bool>(
            future: _hymnId != null
                ? _checkIfFavorite(_hymnId!)
                : Future.value(false),
            builder: (context, snapshot) {
              final isFavorite = snapshot.data ?? false;
              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : AppColors.appamber,
                  size: 24,
                ),
                onPressed: () => _toggleFavorite(),
              );
            },
          ),
        ],
      ),
    );
  }

  // تعديل دالة _buildAlbumArt لاستخدام صورة اللوجو كصورة افتراضية
  Widget _buildAlbumArt() {
    return Expanded(
      flex: 5,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
            child: _albumImageUrl != null && _albumImageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: _albumImageUrl!,
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
                    errorWidget: (context, url, error) => Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  )
                : Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                  ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
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
              size: 28,
            ),
            onPressed: widget.audioService.toggleRepeat,
          ),

          // زر السابق
          IconButton(
            icon:
                Icon(Icons.skip_previous, color: AppColors.appamber, size: 40),
            onPressed: widget.audioService.playPrevious,
          ),

          // زر تشغيل/إيقاف مؤقت
          isLoading
              ? Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.appamber.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
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
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.appamber,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.black,
                        size: 32,
                      ),
                    ),
                  ),
                ),

          // زر التالي
          IconButton(
            icon: Icon(Icons.skip_next, color: AppColors.appamber, size: 40),
            onPressed: widget.audioService.playNext,
          ),

          // زر الخلط
          IconButton(
            icon: Icon(
              Icons.shuffle,
              color: isShuffling
                  ? AppColors.appamber
                  : AppColors.appamber.withOpacity(0.5),
              size: 28,
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
