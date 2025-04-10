import 'package:flutter/material.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/expanded_music_player.dart';

class MusicPlayerWidget extends StatefulWidget {
  final MyAudioService audioService;

  const MusicPlayerWidget({super.key, required this.audioService});

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

  @override
  Widget build(BuildContext context) {
    try {
      // التحقق مما إذا كانت هناك أغنية حالية
      final currentTitle = widget.audioService.currentTitleNotifier.value;
      if (currentTitle == null) {
        return SizedBox.shrink(); // عدم عرض المشغل إذا لم تكن هناك أغنية
      }

      // النسخة المدمجة من المشغل
      return GestureDetector(
        onVerticalDragStart: (details) {
          _dragStartPosition = details.globalPosition.dy;
        },
        onVerticalDragUpdate: (details) {
          if (_dragStartPosition - details.globalPosition.dy > 30) {
            _expandPlayer();
          }
        },
        onTap: _expandPlayer,
        child: Container(
          padding: const EdgeInsets.all(10),
          color: AppColors.backgroundColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // عرض اسم الترنيمة الحالية
              Text(
                currentTitle,
                style: TextStyle(color: AppColors.appamber, fontSize: 18),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // مؤشر التحميل
              widget.audioService.isLoadingNotifier.value
                  ? Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.grey[700],
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.appamber),
                      ),
                    )
                  : SizedBox(height: 4),

              // شريط التقدم
              _buildProgressBar(),

              // أزرار التحكم
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.audioService.isShufflingNotifier,
                    builder: (context, isShuffling, child) {
                      return IconButton(
                        icon: Icon(
                          Icons.shuffle,
                          color: isShuffling ? AppColors.appamber : Colors.grey,
                        ),
                        onPressed: widget.audioService.toggleShuffle,
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_previous, color: AppColors.appamber),
                    onPressed: widget.audioService.playPrevious,
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.audioService.isPlayingNotifier,
                    builder: (context, isPlaying, child) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: widget.audioService.isLoadingNotifier,
                        builder: (context, isLoading, child) {
                          return isLoading
                              ? Container(
                                  width: 48,
                                  height: 48,
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.appamber),
                                    strokeWidth: 2,
                                  ),
                                )
                              : IconButton(
                                  icon: Icon(
                                    isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: AppColors.appamber,
                                  ),
                                  onPressed: _handlePlayPause,
                                );
                        },
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_next, color: AppColors.appamber),
                    onPressed: widget.audioService.playNext,
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: widget.audioService.repeatModeNotifier,
                    builder: (context, repeatMode, child) {
                      return IconButton(
                        icon: Icon(
                          repeatMode == 1 ? Icons.repeat_one : Icons.repeat,
                          color:
                              repeatMode > 0 ? AppColors.appamber : Colors.grey,
                        ),
                        onPressed: widget.audioService.toggleRepeat,
                      );
                    },
                  ),
                ],
              ),

              // مؤشر السحب لأعلى
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(top: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.keyboard_arrow_up,
                      color: AppColors.appamber.withOpacity(0.5),
                      size: 18,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'اضغط للتوسيع',
                      style: TextStyle(
                        color: AppColors.appamber.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
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

  Widget _buildProgressBar() {
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
              trackHeight: 3,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: TextStyle(color: AppColors.appamber, fontSize: 12),
              ),
              Text(
                _formatDuration(duration),
                style: TextStyle(color: AppColors.appamber, fontSize: 12),
              ),
            ],
          ),
        ],
      );
    } catch (e) {
      print('❌ خطأ في بناء شريط التقدم: $e');
      return SizedBox(height: 20);
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
