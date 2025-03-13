import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class Myaudioservice {
  static final Myaudioservice _instance = Myaudioservice._internal();
  factory Myaudioservice() => _instance;
  Myaudioservice._internal();

  final AudioPlayer _player = AudioPlayer();
  final cacheManager = DefaultCacheManager();

  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<int?> currentIndexNotifier = ValueNotifier(null);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration?> durationNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isShufflingNotifier = ValueNotifier(false);
  final ValueNotifier<String?> currentTitleNotifier = ValueNotifier(null);

  // ✅ نظام التكرار بثلاثة أوضاع
  final ValueNotifier<int> repeatModeNotifier =
      ValueNotifier(0); // 0 = لا تكرار، 1 = تكرار ترنيمة، 2 = تكرار القائمة

  List<String> _playlist = [];
  List<String> _titles = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Future<void> init() async {
    _player.playerStateStream.listen((state) {
      isPlayingNotifier.value = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _handleCompletion();
      }
    });

    _player.positionStream.listen((position) {
      positionNotifier.value = position;
    });

    _player.durationStream.listen((duration) {
      durationNotifier.value = duration;
    });

    await startBackgroundService();
  }

  Future<void> startBackgroundService() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'audio_service',
        initialNotificationTitle: 'تشغيل الترنيمة',
        initialNotificationContent: 'التطبيق يعمل في الخلفية',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    service.startService();
  }

  static void onStart(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      service.on('stopService').listen((event) {
        service.stopSelf();
      });
    }
  }

  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  void setPlaylist(List<String> urls, List<String> titles) {
    _playlist = urls;
    _titles = titles;
  }

  Future<void> play(int index, String title) async {
    if (index < 0 || index >= _playlist.length) return;

    _currentIndex = index;
    currentIndexNotifier.value = index;
    currentTitleNotifier.value = title;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastPlayedIndex', index);
    await prefs.setString('lastPlayedTitle', title);

    String url = _playlist[index];

    try {
      final fileInfo = await cacheManager.getFileFromCache(url);
      if (fileInfo == null || !fileInfo.file.existsSync()) {
        final file = await cacheManager.downloadFile(url);
        await _player.setFilePath(file.file.path);
      } else {
        await _player.setFilePath(fileInfo.file.path);
      }
      await _player.play();
      isPlayingNotifier.value = true; // تحديث حالة التشغيل
      _isPlaying = true;
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  void pause() {
    _player.pause();
    isPlayingNotifier.value = false; // تحديث حالة التشغيل
  }

  void togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
      isPlayingNotifier.value = false; // تحديث حالة التشغيل
    } else {
      await _player.play();
      isPlayingNotifier.value = true; // تحديث حالة التشغيل
    }
  }

  void playPrevious() {
    if (_currentIndex > 0) {
      _currentIndex--;
      play(_currentIndex, _titles[_currentIndex]);
    }
  }

  void playNext() {
    if (isShufflingNotifier.value) {
      _currentIndex =
          (DateTime.now().millisecondsSinceEpoch % _playlist.length);
    } else if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
    } else if (repeatModeNotifier.value == 2) {
      _currentIndex = 0;
    } else {
      return;
    }
    play(_currentIndex, _titles[_currentIndex]);
  }

  void _handleCompletion() {
    if (repeatModeNotifier.value == 1) {
      play(_currentIndex, _titles[_currentIndex]); // تكرار نفس الترنيمة
    } else {
      playNext();
    }
  }

  void resume() async {
    if (!_player.playing) {
      await _player.play();
      isPlayingNotifier.value = true;
    }
  }

  void seek(Duration position) async {
    await _player.seek(position);
    positionNotifier.value = position;
  }

  void toggleRepeat() {
    repeatModeNotifier.value =
        (repeatModeNotifier.value + 1) % 3; // 0 → 1 → 2 → 0
    switch (repeatModeNotifier.value) {
      case 0:
        _player.setLoopMode(LoopMode.off); // لا تكرار
        break;
      case 1:
        _player.setLoopMode(LoopMode.one); // تكرار ترنيمة واحدة
        break;
      case 2:
        _player.setLoopMode(LoopMode.all); // تكرار القائمة
        break;
    }
    repeatModeNotifier.notifyListeners(); // ✅ تحديث الزر
  }

  void toggleShuffle() {
    isShufflingNotifier.value = !isShufflingNotifier.value;
    _player.setShuffleModeEnabled(isShufflingNotifier.value);
  }

  void handleAppLifecycleState(AppLifecycleState state) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (state == AppLifecycleState.detached) {
      if (_player.playing) {
        await prefs.setInt('lastPosition', _player.position.inSeconds);
      }
    }
  }

  void dispose() {
    _player.dispose();
    isPlayingNotifier.dispose();
    currentIndexNotifier.dispose();
    positionNotifier.dispose();
    durationNotifier.dispose();
    isShufflingNotifier.dispose();
    currentTitleNotifier.dispose();
    repeatModeNotifier.dispose();
  }
}
