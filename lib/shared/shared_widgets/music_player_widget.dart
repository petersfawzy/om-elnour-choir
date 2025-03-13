import 'package:flutter/material.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';

class MusicPlayerWidget extends StatelessWidget {
  final Myaudioservice audioService;

  const MusicPlayerWidget({super.key, required this.audioService});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10),
      color: AppColors.backgroundColor,
      child: Column(
        children: [
          ValueListenableBuilder<String?>(
            valueListenable: audioService.currentTitleNotifier,
            builder: (context, currentTitle, child) {
              return Text(
                currentTitle ?? "No hymn playing",
                style: TextStyle(color: Colors.amber, fontSize: 18),
                textAlign: TextAlign.center,
              );
            },
          ),
          ValueListenableBuilder<Duration>(
            valueListenable: audioService.positionNotifier,
            builder: (context, position, child) {
              double maxDuration =
                  audioService.durationNotifier.value?.inSeconds.toDouble() ??
                      1;
              double currentPosition = position.inSeconds.toDouble();

              currentPosition = currentPosition.clamp(0, maxDuration);

              return Column(
                children: [
                  Slider(
                    value: currentPosition,
                    min: 0,
                    max: maxDuration > 0 ? maxDuration : 1,
                    onChanged: (value) {
                      audioService.seek(Duration(seconds: value.toInt()));
                    },
                    activeColor: Colors.amber,
                    inactiveColor: Colors.grey,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(position),
                          style: TextStyle(color: Colors.amber)),
                      ValueListenableBuilder<Duration?>(
                        valueListenable: audioService.durationNotifier,
                        builder: (context, duration, child) {
                          return Text(
                            formatDuration(duration ?? Duration.zero),
                            style: TextStyle(color: Colors.amber),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              /// 🔀 زر التشغيل العشوائي (Shuffle)
              ValueListenableBuilder<bool>(
                valueListenable: audioService.isShufflingNotifier,
                builder: (context, isShuffling, child) {
                  return IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color: isShuffling ? Colors.amber : Colors.grey,
                    ),
                    onPressed: audioService.toggleShuffle,
                  );
                },
              ),

              /// ⏮️ زر السابق
              IconButton(
                icon: Icon(Icons.skip_previous, color: Colors.amber),
                onPressed: audioService.playPrevious,
              ),

              /// ▶️ زر التشغيل والإيقاف المؤقت (في المنتصف)
              ValueListenableBuilder<bool>(
                valueListenable: audioService.isPlayingNotifier,
                builder: (context, isPlaying, child) {
                  return IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.amber,
                    ),
                    onPressed: () {
                      audioService
                          .togglePlayPause(); // استخدام togglePlayPause فقط
                    },
                  );
                },
              ),

              /// ⏭️ زر التالي
              IconButton(
                icon: Icon(Icons.skip_next, color: Colors.amber),
                onPressed: audioService.playNext,
              ),

              /// 🔁 زر التكرار (Repeat)
              ValueListenableBuilder<int>(
                valueListenable: audioService.repeatModeNotifier,
                builder: (context, repeatMode, child) {
                  IconData repeatIcon;
                  Color repeatColor = Colors.grey;

                  switch (repeatMode) {
                    case 1:
                      repeatIcon = Icons.repeat_one; // 🔂 تكرار ترنيمة واحدة
                      repeatColor = Colors.amber;
                      break;
                    case 2:
                      repeatIcon = Icons.repeat; // 🔁 تكرار القائمة
                      repeatColor = Colors.amber;
                      break;
                    default:
                      repeatIcon = Icons.repeat; // ⏹️ لا تكرار
                      repeatColor = Colors.grey;
                  }

                  return IconButton(
                    icon: Icon(repeatIcon, color: repeatColor),
                    onPressed: audioService.toggleRepeat,
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
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
