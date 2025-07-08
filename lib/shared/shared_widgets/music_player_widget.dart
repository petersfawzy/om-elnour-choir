import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/expanded_music_player.dart';

class MusicPlayerWidget extends StatefulWidget {
  final MyAudioService audioService;
  final VoidCallback? onFavoriteChanged;

  const MusicPlayerWidget({
    super.key,
    required this.audioService,
    this.onFavoriteChanged,
  });

  @override
  _MusicPlayerWidgetState createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends State<MusicPlayerWidget> {
  bool _isExpanded = false;
  double _dragStartPosition = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    // تأخير إضافة المستمعين لتجنب مشاكل التزامن
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        widget.audioService.currentTitleNotifier.addListener(_safeUpdateUI);
        widget.audioService.positionNotifier.addListener(_safeUpdateUI);
        widget.audioService.durationNotifier.addListener(_safeUpdateUI);
        widget.audioService.isPlayingNotifier.addListener(_safeUpdateUI);
        widget.audioService.isLoadingNotifier.addListener(_safeUpdateUI);
      }
    });
  }

  // دالة آمنة لتحديث واجهة المستخدم
  void _safeUpdateUI() {
    if (!_disposed && mounted) {
      setState(() {});
      _updateNowPlayingInfo(); // أضف هذا السطر هنا
    }
  }

  @override
  void dispose() {
    _disposed = true;

    widget.audioService.currentTitleNotifier.removeListener(_safeUpdateUI);
    widget.audioService.positionNotifier.removeListener(_safeUpdateUI);
    widget.audioService.durationNotifier.removeListener(_safeUpdateUI);
    widget.audioService.isPlayingNotifier.removeListener(_safeUpdateUI);
    widget.audioService.isLoadingNotifier.removeListener(_safeUpdateUI);

    super.dispose();
  }

  void _handlePlayPause() {
    try {
      widget.audioService.togglePlayPause();
    } catch (e) {
      print('❌ خطأ في تشغيل/إيقاف الترنيمة: $e');
    }
  }

  void _expandPlayer() {
    if (_disposed) return;

    try {
      final currentTitle = widget.audioService.currentTitleNotifier.value;
      if (currentTitle == null) return;

      // استخدام Navigator بدلاً من تغيير الحالة داخلياً
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              ExpandedMusicPlayer(
            audioService: widget.audioService,
            onCollapse: () => Navigator.of(context).pop(),
            onFavoriteChanged: widget.onFavoriteChanged,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOut;
            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      );
    } catch (e) {
      print('❌ خطأ في توسيع المشغل: $e');
    }
  }

  Future<void> _updateNowPlayingInfo() async {
    try {
      final currentTitle = widget.audioService.currentTitleNotifier.value ?? '';
      final duration = widget.audioService.durationNotifier.value;
      final position = widget.audioService.positionNotifier.value;
      final isPlaying = widget.audioService.isPlayingNotifier.value;

      print(
          'DEBUG: duration=$duration, position=$position, isPlaying=$isPlaying, title=$currentTitle');

      if (currentTitle.isEmpty || (duration?.inSeconds ?? 0) < 2) {
        print('⚠️ تجاهل إرسال معلومات التشغيل: العنوان فارغ أو المدة قصيرة');
        return;
      }

      print(
          '🔊 إرسال معلومات التشغيل: title=$currentTitle, duration=${duration?.inSeconds}, position=${position.inSeconds}, isPlaying=$isPlaying');

      const artist = 'كورال أم النور';
      const platform =
          MethodChannel('com.egypt.redcherry.omelnourchoir/media_control');
      await platform.invokeMethod('updateNowPlayingInfo', {
        'title': currentTitle,
        'artist': artist,
        'duration': duration!.inSeconds.toDouble(),
        'position': position.inSeconds.toDouble(),
        'isPlaying': isPlaying,
      });
    } catch (e) {
      print('❌ خطأ في إرسال معلومات التشغيل إلى iOS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final currentTitle = widget.audioService.currentTitleNotifier.value;

      // التحقق من اتجاه الشاشة
      final isLandscape =
          MediaQuery.of(context).orientation == Orientation.landscape;
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final playerHeight = isLandscape ? screenHeight * 0.25 : 100.0;

      return GestureDetector(
        onVerticalDragStart: (details) {
          _dragStartPosition = details.globalPosition.dy;
        },
        onVerticalDragUpdate: (details) {
          if (_dragStartPosition - details.globalPosition.dy > 20) {
            _expandPlayer();
          }
        },
        onTap: currentTitle != null ? _expandPlayer : null,
        child: Container(
          width: double.infinity,
          height: playerHeight,
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.backgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: Offset(0, -2),
              ),
            ],
            border: Border(
              top: BorderSide(
                color: AppColors.appamber.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: currentTitle == null
              ? Center(
                  child: Text(
                    'اختر ترنيمة لبدء التشغيل',
                    style: TextStyle(
                      color: AppColors.appamber,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // مؤشر السحب لأعلى
                    Container(
                      width: 40,
                      height: 4,
                      margin: EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: AppColors.appamber.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // عرض اسم الترنيمة الحالية
                    Text(
                      currentTitle,
                      style: TextStyle(
                        color: AppColors.appamber,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // مؤشر التحميل
                    widget.audioService.isLoadingNotifier.value
                        ? Container(
                            margin: EdgeInsets.symmetric(vertical: 2),
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.grey[700],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.appamber),
                            ),
                          )
                        : SizedBox(height: 2),
                    // شريط التقدم
                    _buildProgressBar(isLandscape),
                    // أزرار التحكم
                    Expanded(
                      child: _buildFullControls(isLandscape),
                    ),
                  ],
                ),
        ),
      );
    } catch (e) {
      print('❌ خطأ في بناء مشغل الموسيقى: $e');
      return Container(
        height: 80,
        color: AppColors.backgroundColor,
        child: Center(
          child: Text(
            'حدث خطأ في تحميل المشغل',
            style: TextStyle(color: AppColors.appamber),
          ),
        ),
      );
    }
  }

  // أزرار التحكم الكاملة
  Widget _buildFullControls(bool isLandscape) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: widget.audioService.isShufflingNotifier,
          builder: (context, isShuffling, child) {
            return IconButton(
              icon: Icon(
                Icons.shuffle,
                color: isShuffling ? AppColors.appamber : Colors.grey,
                size: 20,
              ),
              onPressed: widget.audioService.toggleShuffle,
              padding: EdgeInsets.all(4),
              constraints: BoxConstraints(),
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.skip_previous, color: AppColors.appamber, size: 24),
          onPressed: widget.audioService.playPrevious,
          padding: EdgeInsets.all(4),
          constraints: BoxConstraints(),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: widget.audioService.isPlayingNotifier,
          builder: (context, isPlaying, child) {
            return ValueListenableBuilder<bool>(
              valueListenable: widget.audioService.isLoadingNotifier,
              builder: (context, isLoading, child) {
                return isLoading
                    ? Container(
                        width: 36,
                        height: 36,
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.appamber),
                          strokeWidth: 2,
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: AppColors.appamber,
                          size: 30,
                        ),
                        onPressed: _handlePlayPause,
                        padding: EdgeInsets.all(4),
                        constraints: BoxConstraints(),
                      );
              },
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.skip_next, color: AppColors.appamber, size: 24),
          onPressed: widget.audioService.playNext,
          padding: EdgeInsets.all(4),
          constraints: BoxConstraints(),
        ),
        ValueListenableBuilder<int>(
          valueListenable: widget.audioService.repeatModeNotifier,
          builder: (context, repeatMode, child) {
            return IconButton(
              icon: Icon(
                repeatMode == 1 ? Icons.repeat_one : Icons.repeat,
                color: repeatMode > 0 ? AppColors.appamber : Colors.grey,
                size: 20,
              ),
              onPressed: widget.audioService.toggleRepeat,
              padding: EdgeInsets.all(4),
              constraints: BoxConstraints(),
            );
          },
        ),
      ],
    );
  }

  // شريط التقدم
  Widget _buildProgressBar(bool isLandscape) {
    try {
      final position = widget.audioService.positionNotifier.value;
      final duration =
          widget.audioService.durationNotifier.value ?? Duration.zero;

      double maxDuration = duration.inSeconds.toDouble();
      double currentPosition = position.inSeconds.toDouble();

      if (maxDuration > 0 && currentPosition > maxDuration) {
        currentPosition = maxDuration;
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2, // تقليل سمك المسار
              thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: 5), // تقليل حجم المؤشر
              overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: AppColors.appamber,
              inactiveTrackColor: Colors.grey.withOpacity(0.3),
              thumbColor: AppColors.appamber,
            ),
            child: Slider(
              value:
                  maxDuration > 0 ? currentPosition.clamp(0, maxDuration) : 0,
              min: 0,
              max: maxDuration > 0 ? maxDuration : 1,
              onChanged: maxDuration > 0
                  ? (value) {
                      widget.audioService
                          .seek(Duration(seconds: value.toInt()));
                    }
                  : null,
            ),
          ),
          // عرض الوقت في كلا الوضعين
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: TextStyle(color: AppColors.appamber, fontSize: 10),
                ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(color: AppColors.appamber, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      );
    } catch (e) {
      print('❌ خطأ في بناء شريط التقدم: $e');
      return SizedBox(height: 6);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    if (duration == Duration.zero) {
      return "00:00";
    }
    return "${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds.remainder(60))}";
  }
}
