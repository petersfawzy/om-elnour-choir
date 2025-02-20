import 'package:just_audio/just_audio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final DefaultCacheManager _cacheManager = DefaultCacheManager();

  AudioService._internal();

  bool _isPlaying = false;
  int? _currentIndex;
  List<String> _playlist = [];
  List<String> _titles = []; // ✅ قائمة أسماء الترانيم
  bool _isRepeating = false;
  bool _isShuffling = false;

  ValueNotifier<int?> currentIndexNotifier = ValueNotifier<int?>(null);
  ValueNotifier<String?> currentTitleNotifier = ValueNotifier<String?>(null);
  ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  ValueNotifier<Duration> positionNotifier =
      ValueNotifier<Duration>(Duration.zero);
  ValueNotifier<Duration> durationNotifier =
      ValueNotifier<Duration>(Duration.zero);
  ValueNotifier<bool> isRepeatingNotifier = ValueNotifier<bool>(false);
  ValueNotifier<bool> isShufflingNotifier = ValueNotifier<bool>(false);

  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;

  /// ✅ **ضبط قائمة التشغيل بحيث تشمل الروابط والعناوين**
  void setPlaylist(List<String> urls, List<String> titles) {
    _playlist = urls;
    _titles = titles;
  }

  Future<void> play(int index, String title) async {
    if (_playlist.isEmpty || index < 0 || index >= _playlist.length) return;

    if (_currentIndex == index && _isPlaying) return;

    _currentIndex = index;
    currentIndexNotifier.value = index;
    currentTitleNotifier.value = title; // ✅ إظهار اسم الترنيمة الصحيح
    isPlayingNotifier.value = true;
    _isPlaying = true;

    try {
      final file = await _cacheManager.getSingleFile(_playlist[index]);
      await _audioPlayer.setFilePath(file.path);
      _audioPlayer.play();

      _audioPlayer.durationStream.listen((duration) {
        durationNotifier.value = duration ?? Duration.zero;
      });

      _audioPlayer.positionStream.listen((position) {
        positionNotifier.value = position;
      });

      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          playNext();
        }
      });
    } catch (e) {
      print("❌ Error playing audio: $e");
    }
  }

  void pause() {
    _audioPlayer.pause();
    _isPlaying = false;
    isPlayingNotifier.value = false;
  }

  void resume() {
    _audioPlayer.play();
    _isPlaying = true;
    isPlayingNotifier.value = true;
  }

  void stop() {
    _audioPlayer.stop();
    _isPlaying = false;
    currentIndexNotifier.value = null;
    currentTitleNotifier.value = null;
    isPlayingNotifier.value = false;
    positionNotifier.value = Duration.zero;
    durationNotifier.value = Duration.zero;
  }

  void seek(Duration position) {
    _audioPlayer.seek(position);
  }

  void toggleRepeat() {
    _isRepeating = !_isRepeating;
    isRepeatingNotifier.value = _isRepeating;
    _audioPlayer.setLoopMode(_isRepeating ? LoopMode.one : LoopMode.off);
  }

  void toggleShuffle() {
    _isShuffling = !_isShuffling;
    isShufflingNotifier.value = _isShuffling;
    _audioPlayer.setShuffleModeEnabled(_isShuffling);
  }

  void playNext() {
    if (_playlist.isEmpty || _currentIndex == null) return;
    int nextIndex = _isShuffling
        ? (DateTime.now().millisecondsSinceEpoch % _playlist.length)
        : (_currentIndex! + 1) % _playlist.length;
    play(nextIndex, _titles[nextIndex]); // ✅ تمرير اسم الترنيمة الصحيح
  }

  void playPrevious() {
    if (_playlist.isEmpty || _currentIndex == null) return;
    int prevIndex = (_currentIndex! - 1 + _playlist.length) % _playlist.length;
    play(prevIndex, _titles[prevIndex]); // ✅ تمرير اسم الترنيمة الصحيح
  }

  /// ✅ **إيقاف الترانيم فقط عند غلق التطبيق بالكامل**
  void handleAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      stop();
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
