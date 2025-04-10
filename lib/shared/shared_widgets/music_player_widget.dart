import 'package:flutter/material.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';

class MusicPlayerWidget extends StatefulWidget {
  final MyAudioService audioService;

  const MusicPlayerWidget({super.key, required this.audioService});

  @override
  _MusicPlayerWidgetState createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends State<MusicPlayerWidget> {
  @override
  void initState() {
    super.initState();

    // 🔄 تحديث الواجهة تلقائيًا عند تغيير بيانات التشغيل
    widget.audioService.currentTitleNotifier.addListener(_updateUI);
    widget.audioService.positionNotifier.addListener(_updateUI);
    widget.audioService.durationNotifier.addListener(_updateUI);
    widget.audioService.isPlayingNotifier.addListener(_updateUI);
    widget.audioService.isLoadingNotifier.addListener(_updateUI);
  }

  void _updateUI() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.audioService.currentTitleNotifier.removeListener(_updateUI);
    widget.audioService.positionNotifier.removeListener(_updateUI);
    widget.audioService.durationNotifier.removeListener(_updateUI);
    widget.audioService.isPlayingNotifier.removeListener(_updateUI);
    widget.audioService.isLoadingNotifier.removeListener(_updateUI);
    super.dispose();
  }

  // تعديل دالة _handlePlayPause للتعامل مع زر التشغيل/الإيقاف بشكل أفضل
  void _handlePlayPause() {
    print('🎮 تم الضغط على زر التشغيل/الإيقاف');

    if (widget.audioService.isPlayingNotifier.value) {
      print('⏸️ إيقاف التشغيل مؤقتًا');
      widget.audioService.togglePlayPause();
    } else {
      // التحقق من وجود عنوان ترنيمة حالي
      final currentTitle = widget.audioService.currentTitleNotifier.value;
      final currentIndex = widget.audioService.currentIndexNotifier.value;

      print(
          '▶️ محاولة التشغيل، العنوان الحالي: $currentTitle، المؤشر الحالي: $currentIndex');

      if (currentTitle != null &&
          currentTitle.isNotEmpty &&
          currentIndex >= 0) {
        // استخدام togglePlayPause لاستئناف التشغيل من نفس الموضع
        widget.audioService.togglePlayPause();
      } else {
        print('⚠️ لا توجد ترنيمة حالية للتشغيل');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      color: AppColors.backgroundColor,
      child: Column(
        children: [
          // 🎵 **عرض اسم الترنيمة الحالية**
          ValueListenableBuilder<String?>(
            valueListenable: widget.audioService.currentTitleNotifier,
            builder: (context, currentTitle, child) {
              return Text(
                currentTitle ?? "لا يوجد تشغيل حالي",
                style: TextStyle(color: AppColors.appamber, fontSize: 18),
                textAlign: TextAlign.center,
              );
            },
          ),

          // إضافة مؤشر التحميل
          ValueListenableBuilder<bool>(
            valueListenable: widget.audioService.isLoadingNotifier,
            builder: (context, isLoading, child) {
              return isLoading
                  ? Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.grey[700],
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.appamber),
                      ),
                    )
                  : SizedBox(height: 4);
            },
          ),

          // ⏳ **عرض شريط الوقت والمدة**
          ValueListenableBuilder<Duration>(
            valueListenable: widget.audioService.positionNotifier,
            builder: (context, position, child) {
              return ValueListenableBuilder<Duration?>(
                  valueListenable: widget.audioService.durationNotifier,
                  builder: (context, duration, child) {
                    double maxDuration = duration?.inSeconds.toDouble() ?? 0;
                    double currentPosition = position.inSeconds.toDouble();

                    // تأكد من أن الموضع الحالي لا يتجاوز المدة الإجمالية
                    if (maxDuration > 0 && currentPosition > maxDuration) {
                      currentPosition = maxDuration;
                    }

                    return Column(
                      children: [
                        Slider(
                          value: maxDuration > 0 ? currentPosition : 0,
                          min: 0,
                          max: maxDuration > 0 ? maxDuration : 1,
                          onChanged: maxDuration > 0
                              ? (value) {
                                  widget.audioService
                                      .seek(Duration(seconds: value.toInt()));
                                }
                              : null,
                          activeColor: AppColors.appamber,
                          inactiveColor: Colors.grey,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatDuration(position),
                              style: TextStyle(color: AppColors.appamber),
                            ),
                            Text(
                              formatDuration(duration ?? Duration.zero),
                              style: TextStyle(color: AppColors.appamber),
                            ),
                          ],
                        ),
                      ],
                    );
                  });
            },
          ),

          // 🎛 **أزرار التحكم بالموسيقى**
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
                  // تعطيل زر التشغيل أثناء التحميل
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
                      color: repeatMode > 0 ? AppColors.appamber : Colors.grey,
                    ),
                    onPressed: widget.audioService.toggleRepeat,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    if (duration == Duration.zero) {
      return "00:00"; // عرض صفر عندما تكون المدة فارغة
    }
    return "${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds.remainder(60))}";
  }
}
