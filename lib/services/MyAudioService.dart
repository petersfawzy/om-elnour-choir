import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyAudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  final ValueNotifier<String?> currentTitleNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> currentIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isShufflingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> repeatModeNotifier = ValueNotifier<int>(0);

  List<String> _playlist = [];
  List<String> _titles = [];

  MyAudioService() {
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      isPlayingNotifier.value = state.playing;
    });

    _audioPlayer.positionStream.listen((position) {
      positionNotifier.value = position;
    });

    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        durationNotifier.value = duration;
      }
    });

    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null) {
        currentIndexNotifier.value = index;
      }
    });
  }

  Future<void> setPlaylist(List<String> urls, List<String> titles) async {
    _playlist = urls;
    _titles = titles;
    print('✅ تم تحديث قائمة التشغيل: ${_playlist.length} ترنيمة');
  }

  Future<void> play(int index, String title) async {
    if (index < 0 || index >= _playlist.length) return;

    try {
      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(_playlist[index])),
      );
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
      currentTitleNotifier.value = title;
      currentIndexNotifier.value = index;
    } catch (e) {
      print('❌ خطأ في تشغيل الترنيمة: $e');
    }
  }

  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> playNext() async {
    int nextIndex = currentIndexNotifier.value + 1;
    if (nextIndex >= _playlist.length) {
      nextIndex = 0;
    }
    await play(nextIndex, _titles[nextIndex]);
  }

  Future<void> playPrevious() async {
    int prevIndex = currentIndexNotifier.value - 1;
    if (prevIndex < 0) {
      prevIndex = _playlist.length - 1;
    }
    await play(prevIndex, _titles[prevIndex]);
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> toggleShuffle() async {
    isShufflingNotifier.value = !isShufflingNotifier.value;
    if (isShufflingNotifier.value) {
      _playlist.shuffle();
      _titles.shuffle();
    }
  }

  Future<void> toggleRepeat() async {
    repeatModeNotifier.value = (repeatModeNotifier.value + 1) % 3;
  }

  Future<void> restorePlaybackState() async {
    final prefs = await SharedPreferences.getInstance();
    String? lastTitle = prefs.getString('lastPlayedTitle');
    int? lastPosition = prefs.getInt('lastPosition');
    bool wasPlaying = prefs.getBool('wasPlaying') ?? false;

    if (lastTitle != null && lastTitle.isNotEmpty) {
      currentTitleNotifier.value = lastTitle;
      if (lastPosition != null && lastPosition > 0) {
        positionNotifier.value = Duration(seconds: lastPosition);
        await _audioPlayer.seek(Duration(seconds: lastPosition));
      }
      if (wasPlaying) {
        await _audioPlayer.play();
      }
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    isPlayingNotifier.value = false;
  }

  Future<void> dispose() async {
    await _audioPlayer.dispose();
    currentTitleNotifier.dispose();
    positionNotifier.dispose();
    durationNotifier.dispose();
    isPlayingNotifier.dispose();
    currentIndexNotifier.dispose();
    isShufflingNotifier.dispose();
    repeatModeNotifier.dispose();
  }
}
