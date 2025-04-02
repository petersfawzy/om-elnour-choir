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
    super.dispose();
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

          // ⏳ **عرض شريط الوقت والمدة**
          ValueListenableBuilder<Duration>(
            valueListenable: widget.audioService.positionNotifier,
            builder: (context, position, child) {
              double maxDuration = widget
                      .audioService.durationNotifier.value?.inSeconds
                      .toDouble() ??
                  0;
              double currentPosition = position.inSeconds.toDouble();

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
                      ValueListenableBuilder<Duration?>(
                        valueListenable: widget.audioService.durationNotifier,
                        builder: (context, duration, child) {
                          return Text(
                            formatDuration(duration ?? Duration.zero),
                            style: TextStyle(color: AppColors.appamber),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              );
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
                  return IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: AppColors.appamber,
                    ),
                    onPressed: widget.audioService.togglePlayPause,
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
