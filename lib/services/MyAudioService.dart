import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'dart:math' as Math;

class MyAudioService {
  // قنوات التحكم المحسنة
  static const MethodChannel _notificationChannel =
      MethodChannel('com.egypt.redcherry.omelnourchoir/app');
  static const MethodChannel _mediaButtonChannel =
      MethodChannel('com.egypt.redcherry.omelnourchoir/media_buttons');

  // استخدام DefaultCacheManager العادي
  final DefaultCacheManager _cacheManager = DefaultCacheManager();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // قوائم التشغيل
  List<String> _playlist = [];
  List<String> _titles = [];
  List<String?> _artworkUrls = [];

  // الملفات المخزنة مؤقتاً
  final Map<String, String> _cachedFiles = {};

  // قائمة انتظار التحميل
  final List<_DownloadQueueItem> _downloadQueue = [];
  int _activeDownloads = 0;
  final int _maxConcurrentDownloads = 3;

  // مراقبات الحالة
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> positionNotifier =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration?> durationNotifier =
      ValueNotifier<Duration?>(null);
  final ValueNotifier<String?> currentTitleNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<int> currentIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isShufflingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> repeatModeNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> downloadProgressNotifier =
      ValueNotifier<double>(0.0);

  // متغيرات التحكم
  bool _isRestoringPosition = false;
  bool _shouldResumeAfterNavigation = false;
  bool _isResumeInProgress = false;
  bool _preventStopDuringNavigation = true;
  bool _wasPlayingBeforeInterruption = false;
  AudioSession? _audioSession;
  bool _isInitialized = false;
  Timer? _resumeTimer;
  bool _isNavigating = false;
  Function(int, String)? _onHymnChangedCallback;
  bool _isChangingTrack = false;
  Timer? _debounceTimer;
  int _recoveryAttempts = 0;
  DateTime? _lastErrorTime;
  bool _headphonesConnected = false;
  bool _wasPlayingBeforeDisconnect = false;
  StreamSubscription? _headphoneEventSubscription;
  bool _autoPlayPauseEnabled = true;
  bool _isDisposed = false;
  bool _isRecoveryInProgress = false;
  int _maxRetryAttempts = 5;
  String? _tempDirPath;
  final Map<String, DateTime> _failedUrls = {};
  final List<Function?> _playlistContextCallbacks = List.filled(5, null);
  String? _lastIncrementedHymnId;
  DateTime? _lastIncrementTime;
  bool _preventStateRestoration = false;
  bool _playbackStarted = false;
  bool _isPlayAttemptInProgress = false;

  // متغيرات AudioService المحسنة
  bool _audioServiceEnabled = false;
  MyAudioServiceHandler? _audioHandler;

  // متغيرات إضافية في بداية الكلاس
  Timer? _positionUpdateTimer;

  // Constructor
  MyAudioService() {
    _initAudioService();
    _initTempDir();
    _setupMediaButtonListener();
    _setupNotificationListener();
  }

  // إعداد مستمع الإشعارات المحسن
  void _setupNotificationListener() {
    _notificationChannel.setMethodCallHandler((call) async {
      print('🔔 تم استلام أمر من الإشعار: ${call.method}');

      try {
        switch (call.method) {
          case 'mediaButtonPressed':
            final action = call.arguments['action'] as String?;
            await _handleMediaAction(action);
            break;
          case 'notificationDismissed':
            print('🗑️ تم إخفاء الإشعار');
            break;
        }
      } catch (e) {
        print('❌ خطأ في معالجة أمر الإشعار: $e');
      }
    });
  }

  // إعداد مستمع أزرار التحكم المحسن
  void _setupMediaButtonListener() {
    _mediaButtonChannel.setMethodCallHandler((call) async {
      print('🎵 تم استلام أمر من أزرار التحكم: ${call.method}');

      try {
        switch (call.method) {
          case 'mediaAction':
            final action = call.arguments as String?;
            await _handleMediaAction(action);
            break;
          case 'playPause':
            await togglePlayPause();
            break;
          case 'play':
            await play();
            break;
          case 'pause':
            await pause();
            break;
          case 'next':
            await playNext();
            break;
          case 'previous':
            await playPrevious();
            break;
          case 'stop':
            await stop();
            break;
          case 'fastForward':
            final currentPos = positionNotifier.value;
            await seek(currentPos + Duration(seconds: 10));
            break;
          case 'rewind':
            final currentPos = positionNotifier.value;
            final newPos = currentPos - Duration(seconds: 10);
            await seek(newPos > Duration.zero ? newPos : Duration.zero);
            break;
        }
        print('✅ تم تنفيذ الأمر بنجاح: ${call.method}');
      } catch (e) {
        print('❌ خطأ في تنفيذ أمر التحكم ${call.method}: $e');
      }
    });
  }

  // معالجة أوامر التحكم بالوسائط المحسنة
  Future<void> _handleMediaAction(String? action) async {
    if (action == null || _isDisposed) return;

    print('🎮 معالجة أمر التحكم: $action');

    try {
      switch (action) {
        case 'play':
          if (!isPlayingNotifier.value) {
            await play();
          }
          break;
        case 'pause':
          if (isPlayingNotifier.value) {
            await pause();
          }
          break;
        case 'play_pause':
          await togglePlayPause();
          break;
        case 'next':
          await playNext();
          break;
        case 'previous':
          await playPrevious();
          break;
        case 'stop':
          await stop();
          break;
        case 'fast_forward':
          final currentPos = positionNotifier.value;
          await seek(currentPos + Duration(seconds: 10));
          break;
        case 'rewind':
          final currentPos = positionNotifier.value;
          final newPos = currentPos - Duration(seconds: 10);
          await seek(newPos > Duration.zero ? newPos : Duration.zero);
          break;
        default:
          print('⚠️ أمر غير معروف: $action');
      }

      // تحديث حالة الإشعار بعد تنفيذ الأمر
      await _updateNotificationState();
    } catch (e) {
      print('❌ خطأ في معالجة أمر التحكم $action: $e');
    }
  }

  // عرض إشعار التحكم المحسن مع تشخيص مفصل
  Future<void> _showMediaNotification() async {
    if (_isDisposed) return;

    try {
      final title = currentTitleNotifier.value ?? 'ترنيمة';
      final artist = 'كورال أم النور';
      final isPlaying = isPlayingNotifier.value;
      final position = positionNotifier.value.inMilliseconds;
      final duration = durationNotifier.value?.inMilliseconds ?? 0;

      // تشخيص مفصل جداً لصورة الألبوم
      String? artworkUrl;
      print('🔍 فحص صورة الألبوم للترنيمة "$title":');
      print('   - الفهرس الحالي: ${currentIndexNotifier.value}');
      print('   - عدد الصور المتاحة: ${_artworkUrls.length}');
      print('   - عدد الترانيم: ${_titles.length}');

      if (currentIndexNotifier.value >= 0 &&
          currentIndexNotifier.value < _artworkUrls.length) {
        artworkUrl = _artworkUrls[currentIndexNotifier.value];
        print('   - الرابط الخام من المصفوفة: "$artworkUrl"');

        // فحوصات إضافية
        if (artworkUrl == null) {
          print('   - المشكلة: الرابط null');
        } else if (artworkUrl.isEmpty) {
          print('   - المشكلة: الرابط فارغ');
        } else if (artworkUrl == 'null') {
          print('   - المشكلة: الرابط نص "null"');
        } else if (!artworkUrl.startsWith('http')) {
          print('   - المشكلة: الرابط لا يبدأ بـ http: "$artworkUrl"');
        } else {
          print('   ✅ الرابط يبدو صحيحاً: "$artworkUrl"');
        }

        // التحقق من صحة الرابط
        if (artworkUrl != null &&
            artworkUrl.isNotEmpty &&
            artworkUrl != 'null' &&
            artworkUrl.startsWith('http')) {
          print('✅ صورة الألبوم صالحة للاستخدام: $artworkUrl');
        } else {
          print('❌ صورة الألبوم غير صالحة، سيتم تعيينها إلى null');
          artworkUrl = null;
        }
      } else {
        print(
            '❌ فهرس خارج النطاق: ${currentIndexNotifier.value} من ${_artworkUrls.length}');
        artworkUrl = null;
      }

      // طباعة النتيجة النهائية
      print(
          '🖼️ الصورة النهائية التي سيتم إرسالها: ${artworkUrl ?? "لا توجد صورة"}');

      final canSkipPrevious =
          currentIndexNotifier.value > 0 || isShufflingNotifier.value;
      final canSkipNext = currentIndexNotifier.value < _playlist.length - 1 ||
          isShufflingNotifier.value ||
          repeatModeNotifier.value == 2;

      print('🎵 عرض إشعار للترنيمة: "$title"');
      print('🎵 حالة التشغيل: $isPlaying');
      print('🎵 الموضع: ${position}ms من ${duration}ms');
      print('🖼️ رابط الصورة النهائي المرسل: ${artworkUrl ?? "لا توجد صورة"}');

      try {
        // تحديث metadata أولاً مع صورة الألبوم
        if (duration > 0) {
          await _notificationChannel.invokeMethod('updateMediaMetadata', {
            'title': title,
            'artist': artist,
            'duration': duration,
            'artworkUrl': artworkUrl ?? '',
          });
          print('📝 تم تحديث Metadata مع الصورة');
        }

        await _notificationChannel.invokeMethod('showMediaNotification', {
          'title': title,
          'artist': artist,
          'artworkUrl': artworkUrl ?? '',
          'isPlaying': isPlaying,
          'position': position,
          'duration': duration,
          'canSkipPrevious': canSkipPrevious,
          'canSkipNext': canSkipNext,
          'repeatMode': repeatModeNotifier.value,
          'isShuffling': isShufflingNotifier.value,
        });

        // تحديث الموضع فوراً بعد عرض الإشعار
        if (duration > 0) {
          await _notificationChannel
              .invokeMethod('updateNotificationPosition', {
            'position': position,
            'duration': duration,
          });
        }

        print('✅ تم عرض إشعار التحكم المحسن: "$title"');
        print('✅ حالة التشغيل: $isPlaying');
        print('✅ الموضع: ${position}ms/${duration}ms');
        print('✅ الصورة: ${artworkUrl != null ? "موجودة" : "لا توجد"}');
      } catch (e) {
        print('❌ خطأ في عرض إشعار التحكم: $e');
        // Fallback to Android-only notification
        try {
          await _notificationChannel.invokeMethod('showMediaNotification', {
            'title': title,
            'isPlaying': isPlaying,
            'artworkUrl': artworkUrl ?? '',
          });
        } catch (e2) {
          print('❌ خطأ في عرض الإشعار البديل: $e2');
        }
      }
    } catch (e) {
      print('❌ خطأ في عرض إشعار التحكم: $e');
    }
  }

  // تحديث حالة الإشعار
  Future<void> _updateNotificationState() async {
    if (_isDisposed) return;

    try {
      final isPlaying = isPlayingNotifier.value;
      final position = positionNotifier.value.inMilliseconds;
      final duration = durationNotifier.value?.inMilliseconds ?? 0;

      // تحديث حالة التشغيل أولاً
      await _notificationChannel.invokeMethod('updatePlaybackState', {
        'isPlaying': isPlaying,
        'position': position,
      });

      // تحديث موضع الإشعار إذا كان هناك مدة صالحة
      if (duration > 0 && position >= 0) {
        await _notificationChannel.invokeMethod('updateNotificationPosition', {
          'position': position,
          'duration': duration,
        });

        print(
            '📍 تم تحديث موضع الإشعار: ${position}ms / ${duration}ms (${(position / duration * 100).toStringAsFixed(1)}%)');
      }

      print(
          '✅ تم تحديث حالة وموضع الإشعار - Position: ${position}ms, Duration: ${duration}ms, Playing: $isPlaying');
    } catch (e) {
      print('❌ خطأ في تحديث حالة الإشعار: $e');
    }
  }

  // إخفاء إشعار التحكم
  Future<void> _hideMediaNotification() async {
    if (_isDisposed) return;

    try {
      await _notificationChannel.invokeMethod('hideMediaNotification');
      print('✅ تم إخفاء إشعار التحكم');
    } catch (e) {
      print('❌ خطأ في إخفاء إشعار التحكم: $e');
    }
  }

  // الحفاظ على الإشعار مرئياً أثناء تغيير الترنيمة
  Future<void> _keepNotificationVisible() async {
    if (_isDisposed) return;

    try {
      await _notificationChannel.invokeMethod('keepNotificationVisible');
      print('✅ تم الحفاظ على الإشعار مرئياً أثناء التغيير');
    } catch (e) {
      print('❌ خطأ في الحفاظ على الإشعار: $e');
    }
  }

  // تمكين AudioService المحسن
  Future<void> enableAudioService() async {
    try {
      print('🔄 محاولة تمكين AudioService...');

      if (!AudioService.running) {
        print('⚠️ AudioService غير مهيأ، محاولة تهيئته...');

        // محاولة تهيئة AudioService
        try {
          _audioHandler = MyAudioServiceHandler(this);
          await AudioService.init(
            builder: () => _audioHandler!,
            config: AudioServiceConfig(
              androidNotificationChannelId:
                  'com.egypt.redcherry.omelnourchoir.audio',
              androidNotificationChannelName: 'تشغيل الترانيم',
              androidNotificationChannelDescription: 'التحكم في تشغيل الترانيم',
              androidNotificationOngoing: false, // Changed to false
              androidStopForegroundOnPause: true, // Changed to true
              androidNotificationIcon: 'drawable/ic_notification',
              fastForwardInterval: Duration(seconds: 10),
              rewindInterval: Duration(seconds: 10),
              androidShowNotificationBadge: true,
            ),
          );

          _audioServiceEnabled = true;
          print('✅ تم تمكين AudioService بنجاح');
        } catch (e) {
          print('❌ فشل في تهيئة AudioService: $e');
          _audioServiceEnabled = false;
          return;
        }
      } else {
        if (!_audioServiceEnabled) {
          _audioHandler = MyAudioServiceHandler(this);
          _audioServiceEnabled = true;
          print('✅ تم تمكين AudioService مع handler موجود');
        }
      }

      // تحديث الحالة الأولية
      if (_audioServiceEnabled) {
        // _updateAudioServiceState();
        await _setupLockScreenControls();

        // بدء timer لتحديث الموضع
        _startPositionUpdates();
      }
    } catch (e) {
      print('⚠️ فشل في تمكين AudioService: $e');
      _audioServiceEnabled = false;
    }
  }

  // دالة بدء تحديث الموضع
  void _startPositionUpdates() {
    _positionUpdateTimer?.cancel();

    _positionUpdateTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      // تحديث الموضع باستمرار من المشغل مباشرة
      if (!_isRestoringPosition && !_isChangingTrack) {
        final currentPosition = _audioPlayer.position;
        positionNotifier.value = currentPosition;

        // تحديث الإشعار والموضع باستمرار أثناء التشغيل
        if (isPlayingNotifier.value) {
          _updateNotificationState();
        }
      }
    });

    print('✅ تم بدء تحديث الموضع الدوري كل 500ms مع تحديث الإشعار');
  }

  // إعداد التحكم من شاشة القفل المحسن
  Future<void> _setupLockScreenControls() async {
    try {
      if (_audioSession != null) {
        await _audioSession!.setActive(true);
        print('✅ تم تفعيل التحكم من شاشة القفل');
      }

      // تفعيل استقبال أوامر الوسائط من الأندرويد
      await _notificationChannel.invokeMethod('enableMediaButtonReceiver');
      print('✅ تم تفعيل استقبال أوامر الوسائط');
    } catch (e) {
      print('⚠️ خطأ في إعداد التحكم من شاشة القفل: $e');
    }
  }

  // تحديث حالة AudioService
  void _updateAudioServiceState() {
    if (!_audioServiceEnabled || _audioHandler == null) return;

    try {
      // _updateMediaItem();
      // _updatePlaybackState();
    } catch (e) {
      print('⚠️ خطأ في تحديث حالة AudioService: $e');
    }
  }

  // تحديث MediaItem
  void _updateMediaItem() {
    if (!_audioServiceEnabled || _audioHandler == null) return;

    try {
      final title = currentTitleNotifier.value ?? 'ترنيمة';
      final artworkUrl = currentIndexNotifier.value >= 0 &&
              currentIndexNotifier.value < _artworkUrls.length
          ? _artworkUrls[currentIndexNotifier.value]
          : null;

      final mediaItem = MediaItem(
        id: currentIndexNotifier.value.toString(),
        album: "أم النور",
        title: title,
        artist: "كورال أم النور",
        duration: durationNotifier.value,
        artUri: artworkUrl != null ? Uri.parse(artworkUrl) : null,
        playable: true,
        extras: {
          'index': currentIndexNotifier.value,
          'canSkipNext': currentIndexNotifier.value < _playlist.length - 1,
          'canSkipPrevious': currentIndexNotifier.value > 0,
        },
      );

      // استخدام الطريقة الصحيحة لتحديث MediaItem
      _audioHandler!.mediaItem.add(mediaItem);
      print('📱 تم تحديث MediaItem: $title');
    } catch (e) {
      print('⚠️ خطأ في تحديث MediaItem: $e');
    }
  }

  // تحديث PlaybackState
  void _updatePlaybackState() {
    if (!_audioServiceEnabled || _audioHandler == null) return;

    try {
      final controls = <MediaControl>[];

      // إضافة الأزرار حسب الحالة
      if (currentIndexNotifier.value > 0 || isShufflingNotifier.value) {
        controls.add(MediaControl.skipToPrevious);
      }

      if (isPlayingNotifier.value) {
        controls.add(MediaControl.pause);
      } else {
        controls.add(MediaControl.play);
      }

      if (currentIndexNotifier.value < _playlist.length - 1 ||
          isShufflingNotifier.value ||
          repeatModeNotifier.value == 2) {
        controls.add(MediaControl.skipToNext);
      }

      controls.add(MediaControl.stop);

      final playbackState = PlaybackState(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.playPause,
        },
        androidCompactActionIndices: controls.length >= 3 ? [0, 1, 2] : [0, 1],
        processingState: isLoadingNotifier.value
            ? AudioProcessingState.loading
            : AudioProcessingState.ready,
        playing: isPlayingNotifier.value,
        updatePosition: positionNotifier.value,
        bufferedPosition: positionNotifier.value,
        speed: isPlayingNotifier.value ? 1.0 : 0.0,
        queueIndex: currentIndexNotifier.value,
        shuffleMode: isShufflingNotifier.value
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: _getAudioServiceRepeatMode(),
      );

      // تحديث الحالة مع ضمان عدم الإخفاء
      _audioHandler!.playbackState.add(playbackState);

      // تحديث الإشعار أيضاً
      if (currentTitleNotifier.value != null) {
        _showMediaNotification();
      }

      print(
          '📱 تم تحديث PlaybackState - Playing: ${isPlayingNotifier.value}, Position: ${positionNotifier.value.inSeconds}s');
    } catch (e) {
      print('⚠️ خطأ في تحديث PlaybackState: $e');
    }
  }

  // تحويل وضع التكرار
  AudioServiceRepeatMode _getAudioServiceRepeatMode() {
    switch (repeatModeNotifier.value) {
      case 1:
        return AudioServiceRepeatMode.one;
      case 2:
        return AudioServiceRepeatMode.all;
      default:
        return AudioServiceRepeatMode.none;
    }
  }

  // تسجيل callback لزيادة عدد المشاهدات
  void registerHymnChangedCallback(Function(int, String)? callback) {
    _onHymnChangedCallback = callback;
    print(
        '📊 ${callback == null ? "إلغاء تسجيل" : "تسجيل"} callback لزيادة عدد المشاهدات');
  }

  // تسجيل callback لسياق قائمة التشغيل
  void registerPlaylistContextCallback(
      Function(List<Map<String, dynamic>>)? callback) {
    // يمكن إضافة منطق لحفظ callback إذا كان مطلوباً
    print(
        '📋 ${callback == null ? "إلغاء تسجيل" : "تسجيل"} callback لسياق قائمة التشغيل');

    // في الوقت الحالي، نحن لا نحتاج لحفظ هذا callback
    // لأن MyAudioService لا يحتاج لإرسال معلومات سياق قائمة التشغيل
    // ولكن يمكن إضافة هذا المنطق لاحقاً إذا كان مطلوباً
  }

  // تهيئة مسار الدليل المؤقت
  Future<void> _initTempDir() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _tempDirPath = tempDir.path;
      print('✅ تم تهيئة مسار الدليل المؤقت: $_tempDirPath');
    } catch (e) {
      print('❌ خطأ في تهيئة مسار الدليل المؤقت: $e');
    }
  }

  // تهيئة خدمة الصوت
  Future<void> _initAudioService() async {
    if (_isInitialized || _isDisposed) return;

    try {
      await Future.delayed(Duration(milliseconds: 100));
      isLoadingNotifier.value = false;

      await _initAudioPlayer();
      await Future.wait([
        _setupAudioFocusHandling(),
        _loadAutoPlayPauseSettings(),
      ]).catchError((e) {
        print('⚠️ خطأ في تهيئة بعض المكونات: $e');
      });

      try {
        _setupHeadphoneDetection();
      } catch (e) {
        print('⚠️ تم تجاهل خطأ إعداد اكتشاف سماعات الرأس: $e');
      }

      Future.microtask(() {
        if (!_isDisposed) {
          performPeriodicCacheCleanup();
        }
      });

      _isInitialized = true;
      print('✅ تم تهيئة خدمة الصوت بنجاح');

      Future.microtask(() {
        if (!_isDisposed) {
          enableAudioService();
        }
      });

      if (!_preventStateRestoration) {
        Future.microtask(() {
          if (!_isDisposed) {
            restorePlaybackState();
          }
        });
      } else {
        _preventStateRestoration = false;
      }
    } catch (e) {
      print('❌ خطأ في تهيئة خدمة الصوت: $e');
      if (!_isDisposed) {
        Future.delayed(Duration(seconds: 2), () {
          _initAudioService();
        });
      }
    }
  }

  // إعداد التعامل مع تركيز الصوت
  Future<void> _setupAudioFocusHandling() async {
    if (_isDisposed) return;

    try {
      _audioSession = await AudioSession.instance;
      await _audioSession?.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      _audioSession?.becomingNoisyEventStream.listen((_) {
        if (_isDisposed) return;
        print('🎧 تم فصل سماعات الرأس أو تغيير حالة الصوت');
        if (isPlayingNotifier.value) {
          _wasPlayingBeforeInterruption = true;
          pause();
        }
      });

      _audioSession?.interruptionEventStream.listen((event) {
        if (_isDisposed) return;

        if (event.begin) {
          print('📞 بدأت مقاطعة الصوت');
          if (isPlayingNotifier.value) {
            _wasPlayingBeforeInterruption = true;
            pause();
          }
        } else {
          print('📞 انتهت مقاطعة الصوت');
          if (_wasPlayingBeforeInterruption &&
              event.type == AudioInterruptionType.pause) {
            play();
            _wasPlayingBeforeInterruption = false;
          }
        }
      });

      print('✅ تم إعداد التعامل مع تركيز الصوت بنجاح');
    } catch (e) {
      print('❌ خطأ في إعداد التعامل مع تركيز الصوت: $e');
      rethrow;
    }
  }

  // إعداد اكتشاف سماعات الرأس
  Future<void> _setupHeadphoneDetection() async {
    if (_isDisposed) return;

    try {
      print('🔄 جاري إعداد اكتشاف سماعات الرأس...');

      bool isSimulator = false;
      try {
        isSimulator =
            await _notificationChannel.invokeMethod('isSimulator') ?? false;
      } catch (e) {
        isSimulator = true;
      }

      if (isSimulator) {
        print('⚠️ تم اكتشاف بيئة محاكاة، تعطيل ميزات اكتشاف سماعات الرأس');
        return;
      }

      const EventChannel headphoneEventsChannel =
          EventChannel('com.egypt.redcherry.omelnourchoir/headphone_events');

      try {
        _headphoneEventSubscription = headphoneEventsChannel
            .receiveBroadcastStream()
            .listen(_handleHeadphoneStateChange, onError: (error) {
          print('⚠️ خطأ في مراقبة حالة سماعات الرأس: $error');
        });
        print('✅ تم إعداد مراقبة حالة سماعات الرأس بنجاح');
      } catch (e) {
        print('⚠️ فشل في إعداد مراقبة سماعات الرأس: $e');
      }

      try {
        _headphonesConnected = await checkHeadphoneStatus();
        print(
            '🎧 حالة سماعات الرأس عند بدء التشغيل: ${_headphonesConnected ? "متصلة" : "غير متصلة"}');
      } catch (e) {
        print('⚠️ فشل في التحقق من حالة سماعات الرأس: $e');
      }
    } catch (e) {
      print('❌ خطأ في إعداد اكتشاف سماعات الرأس: $e');
    }
  }

  // معالجة تغييرات حالة سماعات الرأس
  void _handleHeadphoneStateChange(dynamic event) {
    if (_isDisposed || !_autoPlayPauseEnabled) return;

    print('🎧 تغيير حالة سماعات الرأس: $event');

    if (event == 'connected') {
      _headphonesConnected = true;
      if (_wasPlayingBeforeDisconnect && isPaused) {
        resume();
        _wasPlayingBeforeDisconnect = false;
      }
    } else if (event == 'disconnected') {
      _headphonesConnected = false;
      if (isPlayingNotifier.value) {
        _wasPlayingBeforeDisconnect = true;
        pause();
      }
    }
  }

  // تحميل إعدادات التشغيل التلقائي
  Future<void> _loadAutoPlayPauseSettings() async {
    if (_isDisposed) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _autoPlayPauseEnabled = prefs.getBool('auto_play_pause_enabled') ?? true;
      print(
          '⚙️ تم تحميل إعدادات التشغيل التلقائي: ${_autoPlayPauseEnabled ? "ممكّن" : "معطّل"}');
    } catch (e) {
      print('❌ خطأ في تحميل إعدادات التشغيل التلقائي: $e');
    }
  }

  // التحقق من حالة سماعات الرأس
  Future<bool> checkHeadphoneStatus() async {
    if (_isDisposed) return false;

    try {
      bool isSimulator = false;
      try {
        isSimulator =
            await _notificationChannel.invokeMethod('isSimulator') ?? false;
      } catch (e) {
        isSimulator = true;
      }

      if (isSimulator) return false;

      final bool? isConnected =
          await _notificationChannel.invokeMethod('checkHeadphoneStatus');
      return isConnected ?? false;
    } catch (e) {
      print("⚠️ فشل في التحقق من حالة سماعات الرأس: $e");
      return false;
    }
  }

  // تهيئة مشغل الصوت
  Future<void> _initAudioPlayer() async {
    if (_isDisposed) return;

    if (_audioPlayer.playerState.processingState != ProcessingState.idle) {
      print('⚠️ مشغل الصوت مهيأ بالفعل');
      return;
    }

    try {
      await _audioPlayer.stop();
      isLoadingNotifier.value = false;

      // مراقبة تغييرات حالة التشغيل
      _audioPlayer.playerStateStream.listen((state) {
        if (_isDisposed) return;

        print('🎵 تغيرت حالة التشغيل: ${state.playing ? 'يعمل' : 'متوقف'}');
        isPlayingNotifier.value = state.playing;
        isLoadingNotifier.value =
            state.processingState == ProcessingState.loading ||
                state.processingState == ProcessingState.buffering;

        _wasPlayingBeforeInterruption = state.playing;

        // تحديث AudioService فوراً
        if (_audioServiceEnabled) {
          _updateAudioServiceState();
        }

        // تحديث الإشعار
        if (currentTitleNotifier.value != null) {
          _showMediaNotification();
        }

        if (state.processingState == ProcessingState.ready) {
          _isChangingTrack = false;
        }
      });

      // مراقبة تغييرات الموضع
      _audioPlayer.positionStream.listen((position) {
        if (_isDisposed) return;
        if (!_isRestoringPosition) {
          positionNotifier.value = position;

          // تحديث الإشعار كل ثانية
          if (position.inSeconds % 1 == 0 && isPlayingNotifier.value) {
            _updateNotificationState();
          }
        }
      });

      // مراقبة تغييرات المدة
      _audioPlayer.durationStream.listen((duration) {
        if (_isDisposed) return;
        durationNotifier.value = duration;
        _updateMediaItem();
      });

      // مراقبة انتهاء التشغيل
      _audioPlayer.processingStateStream.listen((state) {
        if (_isDisposed) return;

        if (state == ProcessingState.completed) {
          print('🎵 الترنيمة انتهت، وضع التكرار: ${repeatModeNotifier.value}');

          if (repeatModeNotifier.value == 1) {
            _audioPlayer.seek(Duration.zero);
            _audioPlayer.play();
          } else {
            int nextIndex = (currentIndexNotifier.value + 1) % _playlist.length;
            if (_onHymnChangedCallback != null &&
                nextIndex >= 0 &&
                nextIndex < _titles.length) {
              _onHymnChangedCallback!(nextIndex, _titles[nextIndex]);
            }
            playNext();
          }
        }
      });

      _audioPlayer.playbackEventStream.listen(
        (event) {
          if (_isDisposed) return;
          if (event.processingState == ProcessingState.idle) {
            print('🎵 حالة المشغل: خامل');
          }
        },
        onError: (error) {
          if (_isDisposed) return;
          print('❌ خطأ في حدث التشغيل: $error');
          _handlePlaybackError();
        },
      );

      print('✅ تم تهيئة مشغل الصوت بنجاح');
    } catch (e) {
      print('❌ خطأ في تهيئة مشغل الصوت: $e');
      rethrow;
    }
  }

  // معالجة أخطاء التشغيل
  Future<void> _handlePlaybackError() async {
    if (_isDisposed || _isRecoveryInProgress) return;

    _isRecoveryInProgress = true;
    _recoveryAttempts++;

    try {
      if (_recoveryAttempts <= _maxRetryAttempts) {
        print('🔄 محاولة إعادة تهيئة مشغل الصوت');
        await _audioPlayer.stop();
        await Future.delayed(Duration(milliseconds: 500));
        await _initAudioPlayer();

        if (_wasPlayingBeforeInterruption) {
          if (currentIndexNotifier.value >= 0 &&
              currentIndexNotifier.value < _playlist.length &&
              currentTitleNotifier.value != null) {
            await playFromBeginning(
                currentIndexNotifier.value, currentTitleNotifier.value!);
          }
        }
      }
    } catch (e) {
      print('❌ فشلت محاولة التعافي: $e');
    } finally {
      _isRecoveryInProgress = false;
    }
  }

  // تعيين قائمة التشغيل مع تشخيص مفصل
  Future<void> setPlaylist(List<String> urls, List<String> titles,
      [List<String?> artworkUrls = const []]) async {
    if (_isDisposed) return;

    if (urls.isEmpty || titles.isEmpty || urls.length != titles.length) {
      print(
          '❌ قائمة تشغيل غير صالحة - URLs: ${urls.length}, Titles: ${titles.length}');
      return;
    }

    try {
      _wasPlayingBeforeInterruption = isPlayingNotifier.value;
      List<String> sanitizedUrls = urls.map(_sanitizeUrl).toList();

      _playlist = sanitizedUrls;
      _titles = titles;

      // تشخيص مفصل لصور الألبوم
      print('🔍 تحليل صور الألبوم في setPlaylist:');
      print('   - عدد الترانيم: ${urls.length}');
      print('   - عدد الصور المرسلة: ${artworkUrls.length}');

      if (artworkUrls.isNotEmpty && artworkUrls.length == urls.length) {
        _artworkUrls = artworkUrls;
        print('✅ تم تعيين صور الألبوم بنجاح');

        // تشخيص إضافي للتأكد من حفظ الصور
        print('🔍 تم حفظ الصور في MyAudioService:');
        for (int i = 0; i < Math.min(3, _artworkUrls.length); i++) {
          print(
              '   [$i] ${titles[i]} -> صورة: ${_artworkUrls[i] ?? "لا توجد"}');
        }

        // طباعة تفاصيل كل صورة
        for (int i = 0; i < artworkUrls.length; i++) {
          final url = artworkUrls[i];
          print('   [$i] ${titles[i]}: ${url ?? "لا توجد صورة"}');
        }
      } else {
        _artworkUrls = List.filled(urls.length, null);
        print(
            '⚠️ لم يتم تمرير صور الألبوم أو العدد غير متطابق، تم إنشاء قائمة فارغة');
      }

      await _saveCurrentState();
      print(
          '✅ تم تعيين قائمة التشغيل: ${urls.length} ترنيمة مع ${_artworkUrls.length} صورة');
    } catch (e) {
      print('❌ خطأ في تعيين قائمة التشغيل: $e');
    }
  }

  // تشغيل الترنيمة
  Future<void> play([int? index, String? title]) async {
    if (_isDisposed) return;

    if (_isPlayAttemptInProgress) {
      print('⚠️ هناك محاولة تشغيل جارية بالفعل');
      return;
    }

    _isPlayAttemptInProgress = true;
    isLoadingNotifier.value = true;

    try {
      if (!_isInitialized) {
        _preventStateRestoration = true;
        await _initAudioService();
      }

      if (index != null) {
        print('🎵 تشغيل الترنيمة بالفهرس: $index، العنوان: $title');

        await _audioPlayer.stop();
        await Future.delayed(Duration(milliseconds: 200));

        if (index < 0 || index >= _playlist.length) {
          if (title != null && _titles.contains(title)) {
            index = _titles.indexOf(title);
          } else {
            isLoadingNotifier.value = false;
            _isPlayAttemptInProgress = false;
            return;
          }
        }

        // تحديث العنوان والفهرس فوراً
        currentIndexNotifier.value = index;
        final actualTitle = title ?? _titles[index];
        currentTitleNotifier.value = actualTitle;

        print('📝 تم تحديث العنوان إلى: "$actualTitle" (فهرس: $index)');

        _updateAudioServiceState();

        if (_onHymnChangedCallback != null) {
          Future.delayed(Duration(milliseconds: 300), () {
            if (!_isDisposed && index != null) {
              String currentHymnId = title ?? _titles[index];
              DateTime now = DateTime.now();

              if (currentHymnId == _lastIncrementedHymnId &&
                  _lastIncrementTime != null &&
                  now.difference(_lastIncrementTime!).inSeconds < 30) {
                return;
              }

              _onHymnChangedCallback!(index, currentHymnId);
              _lastIncrementedHymnId = currentHymnId;
              _lastIncrementTime = now;
            }
          });
        }

        String url = _playlist[index];
        url = _sanitizeUrl(url);
        _playbackStarted = false;

        final cachedPath = await _getCachedFile(url);
        if (cachedPath != null) {
          try {
            final fileSource = AudioSource.uri(Uri.file(cachedPath));
            await _audioPlayer.setAudioSource(fileSource, preload: true);
            await _audioPlayer.play();
          } catch (e) {
            await _playFromUrl(url);
          }
        } else {
          await _playFromUrl(url);
        }

        _saveCurrentState();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      print('❌ خطأ أثناء التشغيل: $e');
      isLoadingNotifier.value = false;
      _handlePlaybackError();
    } finally {
      _isPlayAttemptInProgress = false;
    }

    // عرض الإشعار
    _showMediaNotification();
  }

  // إيقاف مؤقت
  Future<void> pause() async {
    if (_isDisposed) return;

    print('⏸️ تم استدعاء الإيقاف المؤقت');
    await _audioPlayer.pause();
    _updateAudioServiceState();
    _updateNotificationState();
  }

  // استئناف التشغيل
  Future<void> resume() async {
    if (_isDisposed) return;

    if (!_audioPlayer.playing &&
        _audioPlayer.processingState != ProcessingState.idle) {
      await _audioPlayer.play();
      print('▶️ تم استئناف التشغيل');
    }
  }

  // إيقاف التشغيل
  Future<void> stop() async {
    if (_isDisposed) return;

    print('⏹️ تم استدعاء الإيقاف');
    await _audioPlayer.stop();

    // تحديث الحالة بدون إخفاء الإشعار إذا كان هناك ترنيمة أخرى ستبدأ
    if (_audioServiceEnabled && _audioHandler != null) {
      _audioHandler!.playbackState.add(PlaybackState(
        controls: [MediaControl.play, MediaControl.stop],
        processingState: AudioProcessingState.ready,
        playing: false,
        updatePosition: positionNotifier.value,
      ));
    }

    // إخفاء الإشعار فقط إذا لم تكن هناك ترنيمة قادمة
    if (!_isChangingTrack) {
      _hideMediaNotification();
    }
  }

  // البحث إلى موضع معين
  Future<void> seek(Duration position) async {
    if (_isDisposed) return;

    print('🔍 البحث إلى الموضع: ${position.inSeconds}s');
    await _audioPlayer.seek(position);
    _updateAudioServiceState();
    _updateNotificationState();
  }

  // تبديل التشغيل/الإيقاف
  Future<void> togglePlayPause() async {
    if (_isDisposed) return;

    print('⏯️ تبديل التشغيل/الإيقاف');

    if (_isChangingTrack) {
      print('⚠️ جاري تغيير المسار، تجاهل طلب التبديل');
      return;
    }

    try {
      if (_audioPlayer.playing) {
        await pause();
      } else {
        if (_audioPlayer.audioSource != null) {
          await play();
        } else if (_playlist.isNotEmpty &&
            currentIndexNotifier.value >= 0 &&
            currentIndexNotifier.value < _playlist.length &&
            currentTitleNotifier.value != null) {
          final url = _playlist[currentIndexNotifier.value];
          final cachedPath = await _getCachedFile(url);

          if (cachedPath != null) {
            await _audioPlayer
                .setAudioSource(AudioSource.uri(Uri.file(cachedPath)));
          } else {
            await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
          }

          final userId = _getCurrentUserId();
          final prefs = await SharedPreferences.getInstance();
          final lastPosition = prefs.getInt('lastPosition_$userId') ?? 0;

          if (lastPosition > 0) {
            await _audioPlayer.seek(Duration(seconds: lastPosition));
          }

          await play();
        }
      }

      await _saveCurrentState();
    } catch (e) {
      print('❌ خطأ في تبديل التشغيل/الإيقاف: $e');
      _handlePlaybackError();
    }
  }

  // تشغيل الترنيمة التالية
  Future<void> playNext() async {
    if (_isDisposed || _playlist.isEmpty) return;

    if (_isChangingTrack) {
      print('⚠️ جاري تغيير المسار، تجاهل طلب التشغيل التالي');
      return;
    }

    _isChangingTrack = true;
    print('⏭️ تشغيل الترنيمة التالية');

    try {
      int nextIndex;
      if (currentTitleNotifier.value == null ||
          currentIndexNotifier.value < 0) {
        nextIndex = 0;
      } else if (isShufflingNotifier.value) {
        nextIndex = _getRandomIndex();
      } else {
        nextIndex = (currentIndexNotifier.value + 1) % _playlist.length;
      }

      if (nextIndex < 0 || nextIndex >= _playlist.length) {
        nextIndex = 0;
      }

      // إيقاف التشغيل الحالي فوراً
      await _audioPlayer.stop();

      // تحديث الفهرس والعنوان فوراً
      currentIndexNotifier.value = nextIndex;
      currentTitleNotifier.value = _titles[nextIndex];

      // استدعاء callback لزيادة المشاهدات
      if (_onHymnChangedCallback != null &&
          nextIndex >= 0 &&
          nextIndex < _titles.length) {
        String nextTitle = _titles[nextIndex];
        DateTime now = DateTime.now();

        if (nextTitle != _lastIncrementedHymnId ||
            _lastIncrementTime == null ||
            now.difference(_lastIncrementTime!).inSeconds >= 30) {
          _onHymnChangedCallback!(nextIndex, nextTitle);
          _lastIncrementedHymnId = nextTitle;
          _lastIncrementTime = now;
        }
      }

      // تشغيل الترنيمة الجديدة مباشرة
      String url = _playlist[nextIndex];
      url = _sanitizeUrl(url);

      // محاولة التشغيل من الكاش أولاً
      final cachedPath = await _getCachedFile(url);
      if (cachedPath != null) {
        await _audioPlayer
            .setAudioSource(AudioSource.uri(Uri.file(cachedPath)));
        await _audioPlayer.play();
        print('✅ تم تشغيل الترنيمة التالية من الكاش');
      } else {
        // التشغيل من الرابط مباشرة
        await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
        await _audioPlayer.play();
        print('✅ تم تشغيل الترنيمة التالية من الرابط');

        // تخزين في الكاش في الخلفية
        _cacheFileInBackground(url);
      }

      _saveCurrentState();
      _showMediaNotification();
    } catch (e) {
      print('❌ خطأ في تشغيل الترنيمة التالية: $e');
      isLoadingNotifier.value = false;
    } finally {
      _isChangingTrack = false;
    }
  }

  // تشغيل الترنيمة السابقة
  Future<void> playPrevious() async {
    if (_isDisposed || _playlist.isEmpty) return;

    if (_isChangingTrack) {
      print('⚠️ جاري تغيير المسار، تجاهل طلب التشغيل السابق');
      return;
    }

    _isChangingTrack = true;
    print('⏮️ تشغيل الترنيمة السابقة');

    try {
      int prevIndex;
      if (currentTitleNotifier.value == null ||
          currentIndexNotifier.value < 0) {
        prevIndex = 0;
      } else if (isShufflingNotifier.value) {
        prevIndex = _getRandomIndex();
      } else {
        prevIndex = (currentIndexNotifier.value - 1 + _playlist.length) %
            _playlist.length;
      }

      if (prevIndex < 0 || prevIndex >= _playlist.length) {
        prevIndex = 0;
      }

      // إيقاف التشغيل الحالي فوراً
      await _audioPlayer.stop();

      // تحديث الفهرس والعنوان فوراً
      currentIndexNotifier.value = prevIndex;
      currentTitleNotifier.value = _titles[prevIndex];

      // استدعاء callback لزيادة المشاهدات
      if (_onHymnChangedCallback != null &&
          prevIndex >= 0 &&
          prevIndex < _titles.length) {
        String prevTitle = _titles[prevIndex];
        DateTime now = DateTime.now();

        if (prevTitle != _lastIncrementedHymnId ||
            _lastIncrementTime == null ||
            now.difference(_lastIncrementTime!).inSeconds >= 30) {
          _onHymnChangedCallback!(prevIndex, prevTitle);
          _lastIncrementedHymnId = prevTitle;
          _lastIncrementTime = now;
        }
      }

      // تشغيل الترنيمة الجديدة مباشرة
      String url = _playlist[prevIndex];
      url = _sanitizeUrl(url);

      // محاولة التشغيل من الكاش أولاً
      final cachedPath = await _getCachedFile(url);
      if (cachedPath != null) {
        await _audioPlayer
            .setAudioSource(AudioSource.uri(Uri.file(cachedPath)));
        await _audioPlayer.play();
        print('✅ تم تشغيل الترنيمة السابقة من الكاش');
      } else {
        // التشغيل من الرابط مباشرة
        await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
        await _audioPlayer.play();
        print('✅ تم تشغيل الترنيمة السابقة من الرابط');

        // تخزين في الكاش في الخلفية
        _cacheFileInBackground(url);
      }

      _saveCurrentState();
      _showMediaNotification();
    } catch (e) {
      print('❌ خطأ في تشغيل الترنيمة السابقة: $e');
      isLoadingNotifier.value = false;
    } finally {
      _isChangingTrack = false;
    }
  }

  // دالة مساعدة للحصول على فهرس عشوائي
  int _getRandomIndex() {
    if (_playlist.length <= 1) return 0;

    int randomIndex;
    do {
      randomIndex =
          (DateTime.now().millisecondsSinceEpoch % _playlist.length).toInt();
    } while (randomIndex == currentIndexNotifier.value);

    return randomIndex;
  }

  // تبديل وضع التشغيل العشوائي
  Future<void> toggleShuffle() async {
    if (_isDisposed) return;

    isShufflingNotifier.value = !isShufflingNotifier.value;
    await _saveCurrentState();
    _updateAudioServiceState();
  }

  // تبديل وضع التكرار
  Future<void> toggleRepeat() async {
    if (_isDisposed) return;

    repeatModeNotifier.value = (repeatModeNotifier.value + 1) % 3;
    await _saveCurrentState();
    _updateAudioServiceState();
  }

  // حفظ الحالة الحالية
  Future<void> _saveCurrentState() async {
    if (_isDisposed) return;

    try {
      final userId = _getCurrentUserId();
      final prefs = await SharedPreferences.getInstance();

      if (currentTitleNotifier.value != null) {
        await prefs.setString(
            'lastPlayedTitle_$userId', currentTitleNotifier.value!);
      }
      await prefs.setInt('lastPlayedIndex_$userId', currentIndexNotifier.value);

      final currentPosition = positionNotifier.value.inSeconds;
      await prefs.setInt('lastPosition_$userId', currentPosition);

      await prefs.setBool('wasPlaying_$userId', isPlayingNotifier.value);
      await prefs.setStringList('lastPlaylist_$userId', _playlist);
      await prefs.setStringList('lastTitles_$userId', _titles);

      final artworkUrlsToSave = _artworkUrls.map((url) => url ?? '').toList();
      await prefs.setStringList('lastArtworkUrls_$userId', artworkUrlsToSave);

      await prefs.setInt('repeatMode_$userId', repeatModeNotifier.value);
      await prefs.setBool('isShuffling_$userId', isShufflingNotifier.value);

      print('✅ تم حفظ حالة التشغيل بنجاح');
    } catch (e) {
      print('❌ خطأ في حفظ حالة التشغيل: $e');
    }
  }

  // حفظ الحالة عند إغلاق التطبيق
  Future<void> saveStateOnAppClose() async {
    if (_isDisposed) return;

    print('💾 حفظ الحالة عند إغلاق التطبيق...');
    await _saveCurrentState();
  }

  // استعادة حالة التشغيل
  Future<void> restorePlaybackState() async {
    if (_isDisposed) return;

    try {
      final userId = _getCurrentUserId();
      final prefs = await SharedPreferences.getInstance();

      repeatModeNotifier.value = prefs.getInt('repeatMode_$userId') ?? 0;
      isShufflingNotifier.value = prefs.getBool('isShuffling_$userId') ?? false;

      final lastPlaylist = prefs.getStringList('lastPlaylist_$userId');
      final lastTitles = prefs.getStringList('lastTitles_$userId');

      if (lastPlaylist == null ||
          lastTitles == null ||
          lastPlaylist.isEmpty ||
          lastPlaylist.length != lastTitles.length) {
        print('⚠️ لم يتم العثور على قائمة تشغيل سابقة');
        return;
      }

      _playlist = lastPlaylist;
      _titles = lastTitles;

      final lastArtworkUrls = prefs.getStringList('lastArtworkUrls_$userId');
      if (lastArtworkUrls != null &&
          lastArtworkUrls.length == lastPlaylist.length) {
        _artworkUrls =
            lastArtworkUrls.map((url) => url.isEmpty ? null : url).toList();
        print(
            '✅ تم استعادة ${_artworkUrls.length} صورة ألبوم من التخزين المحلي');
      } else {
        _artworkUrls = List.filled(lastPlaylist.length, null);
        print(
            '⚠️ لم يتم العثور على صور الألبوم المحفوظة، تم إنشاء قائمة فارغة');
      }

      final lastTitle = prefs.getString('lastPlayedTitle_$userId');
      final lastIndex = prefs.getInt('lastPlayedIndex_$userId') ?? 0;
      final lastPosition = prefs.getInt('lastPosition_$userId') ?? 0;
      final wasPlaying = prefs.getBool('wasPlaying_$userId') ?? false;

      if (lastTitle == null || lastIndex < 0 || lastIndex >= _playlist.length) {
        return;
      }

      currentTitleNotifier.value = lastTitle;
      currentIndexNotifier.value = lastIndex;
      _updateAudioServiceState();

      _isRestoringPosition = true;

      if (lastPosition > 0) {
        positionNotifier.value = Duration(seconds: lastPosition);
      }

      try {
        await prepareHymnAtPosition(lastIndex, lastTitle,
            lastPosition > 0 ? Duration(seconds: lastPosition) : Duration.zero);

        _isRestoringPosition = false;
        _wasPlayingBeforeInterruption =
            false; // تغيير هذا لمنع التشغيل التلقائي

        // عدم التشغيل التلقائي عند فتح التطبيق
        // if (wasPlaying) {
        //   await Future.delayed(Duration(milliseconds: 500));
        //   await play();
        // }

        print('✅ تم استعادة حالة التشغيل بدون تشغيل تلقائي');
      } catch (e) {
        _isRestoringPosition = false;
        print('❌ خطأ في إعداد مصدر الصوت: $e');
        _handlePlaybackError();
      }
    } catch (e) {
      _isRestoringPosition = false;
      print('❌ خطأ في استعادة حالة التشغيل: $e');
    }
  }

  // تحضير الترنيمة في موضع معين
  Future<void> prepareHymnAtPosition(
      int index, String title, Duration position) async {
    if (_isDisposed || index < 0 || index >= _playlist.length) return;

    try {
      currentIndexNotifier.value = index;
      currentTitleNotifier.value = title;
      _updateAudioServiceState();

      _isRestoringPosition = true;
      positionNotifier.value = position;

      await _audioPlayer.stop();

      String url = _playlist[index];
      url = _sanitizeUrl(url);

      final cachedPath = await _getCachedFile(url);

      if (cachedPath != null) {
        await _audioPlayer.setAudioSource(
          AudioSource.uri(Uri.file(cachedPath)),
          initialPosition: position,
          preload: true,
        );
      } else {
        await _audioPlayer.setAudioSource(
          AudioSource.uri(Uri.parse(url)),
          initialPosition: position,
          preload: true,
        );
      }

      _isRestoringPosition = false;
    } catch (e) {
      _isRestoringPosition = false;
      print('❌ خطأ في تحضير الترنيمة: $e');
      _handlePlaybackError();
    }
  }

  // تنظيف URL
  String _sanitizeUrl(String url) {
    try {
      if (url.contains('%')) {
        try {
          Uri.parse(url);
          return url;
        } catch (e) {
          final decodedUrl = Uri.decodeFull(url);
          final encodedUrl = Uri.encodeFull(decodedUrl);
          return encodedUrl;
        }
      }
      return url;
    } catch (e) {
      return url;
    }
  }

  // تشغيل من البداية
  Future<void> playFromBeginning(int index, String title) async {
    if (_isDisposed) return;

    // الحفاظ على MediaSession نشط أثناء تغيير الترنيمة
    if (_audioServiceEnabled && _audioHandler != null) {
      final loadingState = PlaybackState(
        controls: [MediaControl.stop],
        processingState: AudioProcessingState.loading,
        playing: false,
        updatePosition: Duration.zero,
      );
      _audioHandler!.playbackState.add(loadingState);
    }

    isLoadingNotifier.value = true;
    downloadProgressNotifier.value = 0.0;

    try {
      if (index < 0 || index >= _playlist.length) {
        if (_titles.contains(title)) {
          index = _titles.indexOf(title);
        } else {
          isLoadingNotifier.value = false;
          return;
        }
      }

      currentIndexNotifier.value = index;
      currentTitleNotifier.value = title;
      _updateAudioServiceState();
      _playbackStarted = false;

      String url = _playlist[index];
      url = _sanitizeUrl(url);

      await _audioPlayer.stop();
      await Future.delayed(Duration(milliseconds: 200));

      try {
        final tempFile = await _downloadToTempFile(url, highPriority: true);

        if (tempFile != null) {
          final fileSource = AudioSource.uri(Uri.file(tempFile));
          await _audioPlayer.setAudioSource(fileSource, preload: true);
          await _audioPlayer.play();
          print('✅ تم تشغيل الترنيمة من الملف المؤقت');
          return;
        }

        final audioSource = AudioSource.uri(Uri.parse(url));
        await _audioPlayer.setAudioSource(audioSource, preload: true);
        await _audioPlayer.play();
        print('✅ تم تشغيل الترنيمة من الرابط مباشرة');
      } catch (e) {
        try {
          await _audioPlayer.setUrl(url);
          await _audioPlayer.play();
          print('✅ تم تشغيل الترنيمة باستخدام setUrl');
        } catch (e2) {
          try {
            await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)),
                preload: false);
            await Future.delayed(Duration(milliseconds: 300));
            await _audioPlayer.play();
            print('✅ تم تشغيل الترنيمة بعد تأخير');
          } catch (e3) {
            isLoadingNotifier.value = false;
            throw e3;
          }
        }
      }

      _cacheFileInBackground(url);
      _saveCurrentState();
      print('✅ تم إكمال playFromBeginning بنجاح');
    } catch (e) {
      print('❌ خطأ في playFromBeginning: $e');
      isLoadingNotifier.value = false;
      _handlePlaybackError();
      throw e;
    }
  }

  // تشغيل من URL
  Future<void> _playFromUrl(String url) async {
    try {
      isLoadingNotifier.value = true;
      downloadProgressNotifier.value = 0.0;

      if (_cachedFiles.containsKey(url)) {
        final cachedPath = _cachedFiles[url];
        if (cachedPath != null) {
          final file = File(cachedPath);
          if (await file.exists()) {
            final fileSource = AudioSource.uri(Uri.file(cachedPath));
            await _audioPlayer.setAudioSource(fileSource, preload: true);
            await _audioPlayer.play();
            return;
          } else {
            _cachedFiles.remove(url);
          }
        }
      }

      try {
        final audioSource = AudioSource.uri(Uri.parse(url));
        await _audioPlayer.setAudioSource(audioSource, preload: false);
        await _audioPlayer.play();
        _cacheFileInBackground(url);
        return;
      } catch (e) {
        final tempFile = await _downloadToTempFile(url, highPriority: true);
        if (tempFile != null) {
          final fileSource = AudioSource.uri(Uri.file(tempFile));
          await _audioPlayer.setAudioSource(fileSource, preload: false);
          await _audioPlayer.play();
          return;
        }
      }

      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (e) {
      print('❌ فشلت جميع محاولات التشغيل: $e');
      isLoadingNotifier.value = false;
      downloadProgressNotifier.value = 0.0;
      _failedUrls[url] = DateTime.now();
      _handlePlaybackError();
    }
  }

  // الحصول على الملف المخزن مؤقتًا
  Future<String?> _getCachedFile(String url) async {
    try {
      if (_cachedFiles.containsKey(url)) {
        final cachedPath = _cachedFiles[url];
        if (cachedPath != null) {
          final file = File(cachedPath);
          if (await file.exists()) {
            return cachedPath;
          } else {
            _cachedFiles.remove(url);
          }
        }
      }

      try {
        final fileInfo = await _cacheManager.getFileFromCache(url);
        if (fileInfo != null) {
          _cachedFiles[url] = fileInfo.file.path;
          return fileInfo.file.path;
        }
      } catch (e) {
        print('خطأ في الوصول إلى الكاش: $e');
      }

      return null;
    } catch (e) {
      print('خطأ في البحث عن الملف المخزن مؤقتًا: $e');
      return null;
    }
  }

  // تخزين الملف في الخلفية
  void _cacheFileInBackground(String url) {
    if (_isDisposed) return;

    Future.delayed(Duration(milliseconds: 300), () async {
      if (_isDisposed) return;

      try {
        final fileInfo = await _cacheManager.getFileFromCache(url);
        if (fileInfo != null) {
          _cachedFiles[url] = fileInfo.file.path;
          return;
        }

        final tempFile = await _downloadToTempFile(url);
        if (tempFile != null) {
          return;
        }

        final fileInfo2 = await _cacheManager.downloadFile(url, key: url);
        _cachedFiles[url] = fileInfo2.file.path;
      } catch (e) {
        print('❌ خطأ في تخزين الملف في الذاكرة المؤقتة: $e');
      }
    });
  }

  // تنزيل إلى ملف مؤقت
  Future<String?> _downloadToTempFile(String url,
      {bool highPriority = false}) async {
    if (_isDisposed || _tempDirPath == null) return null;

    final cachedPath = await _getCachedFile(url);
    if (cachedPath != null) {
      return cachedPath;
    }

    if (highPriority) {
      return await _downloadFile(url, true);
    }

    final completer = Completer<String?>();
    _downloadQueue.add(_DownloadQueueItem(
        url: url, priority: highPriority ? 1 : 0, completer: completer));

    _downloadQueue.sort((a, b) => b.priority.compareTo(a.priority));
    _processDownloadQueue();

    return completer.future;
  }

  // معالجة قائمة انتظار التحميل
  void _processDownloadQueue() async {
    if (_isDisposed) return;

    while (_activeDownloads < _maxConcurrentDownloads &&
        _downloadQueue.isNotEmpty) {
      final item = _downloadQueue.removeAt(0);
      _activeDownloads++;

      _downloadFile(item.url, item.priority > 0).then((result) {
        _activeDownloads--;
        item.completer.complete(result);
        _processDownloadQueue();
      });
    }
  }

  // تنزيل الملف
  Future<String?> _downloadFile(String url, bool highPriority) async {
    if (_isDisposed || _tempDirPath == null) return null;

    try {
      final fileName = 'hymn_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final filePath = '$_tempDirPath/$fileName';

      if (_cachedFiles.containsKey(url) && _cachedFiles[url]!.isNotEmpty) {
        final existingPath = _cachedFiles[url]!;
        final file = File(existingPath);
        if (await file.exists()) {
          return existingPath;
        }
      }

      final httpClient = HttpClient();
      httpClient.connectionTimeout = Duration(seconds: 10);
      final request = await httpClient.getUrl(Uri.parse(url));

      if (highPriority) {
        request.headers.add('Priority', 'high');
      }

      final response = await request.close();

      if (response.statusCode != 200) {
        print('❌ فشل تنزيل الملف: ${response.statusCode}');
        return null;
      }

      final file = File(filePath);
      final sink = file.openWrite();

      final totalSize = response.contentLength;
      int downloadedBytes = 0;
      int lastProgressUpdate = 0;

      await response.forEach((bytes) {
        sink.add(bytes);
        downloadedBytes += bytes.length;

        if (totalSize > 0) {
          final progress = downloadedBytes / totalSize;
          final currentTime = DateTime.now().millisecondsSinceEpoch;

          if (currentTime - lastProgressUpdate > 200) {
            downloadProgressNotifier.value = progress;
            lastProgressUpdate = currentTime;
          }
        }
      });

      await sink.flush();
      await sink.close();

      _cachedFiles[url] = filePath;
      downloadProgressNotifier.value = 0.0;

      return filePath;
    } catch (e) {
      print('❌ خطأ في تنزيل الملف: $e');
      return null;
    }
  }

  // تنظيف دوري للكاش
  Future<void> performPeriodicCacheCleanup() async {
    if (_isDisposed) return;

    try {
      final tempDir = Directory(_tempDirPath ?? '');
      if (await tempDir.exists()) {
        int totalSize = 0;
        int fileCount = 0;

        await for (final entity in tempDir.list()) {
          if (entity is File && entity.path.contains('hymn_')) {
            final stat = await entity.stat();
            totalSize += stat.size;
            fileCount++;
          }
        }

        final sizeInMB = totalSize / (1024 * 1024);
        if (sizeInMB > 200 || fileCount > 100) {
          print(
              '🧹 حجم الكاش الحالي: ${sizeInMB.toStringAsFixed(2)} ميجابايت، عدد الملفات: $fileCount');

          final currentlyUsedFiles = _cachedFiles.values.toSet();
          final files = <FileSystemEntity>[];

          await for (final entity in tempDir.list()) {
            if (entity is File &&
                entity.path.contains('hymn_') &&
                !currentlyUsedFiles.contains(entity.path)) {
              files.add(entity);
            }
          }

          final fileInfoList = <Map<String, dynamic>>[];
          for (final entity in files) {
            if (entity is File) {
              final stat = await entity.stat();
              fileInfoList.add({
                'file': entity,
                'modified': stat.modified,
              });
            }
          }

          fileInfoList.sort((a, b) => a['modified'].compareTo(b['modified']));
          final sortedFiles =
              fileInfoList.map((info) => info['file'] as File).toList();
          final filesToDelete =
              sortedFiles.take((sortedFiles.length / 2).ceil()).toList();

          for (final file in filesToDelete) {
            try {
              await file.delete();
            } catch (e) {
              print('⚠️ فشل في حذف الملف: ${file.path}');
            }
          }

          print('✅ تم تنظيف ${filesToDelete.length} ملف من الكاش');
        }
      }
    } catch (e) {
      print('❌ خطأ في تنظيف الكاش الدوري: $e');
    }
  }

  // الحصول على معرف المستخدم الحالي
  String _getCurrentUserId() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return user?.uid ?? 'guest';
    } catch (e) {
      print('⚠️ خطأ في الحصول على معرف المستخدم: $e');
      return 'guest';
    }
  }

  // مسح بيانات المستخدم
  Future<void> clearUserData() async {
    if (_isDisposed) return;

    try {
      print('🧹 جاري مسح بيانات المستخدم...');

      await stop();

      _playlist = [];
      _titles = [];
      _artworkUrls = [];

      currentIndexNotifier.value = 0;
      currentTitleNotifier.value = null;
      positionNotifier.value = Duration.zero;
      durationNotifier.value = null;

      final prefs = await SharedPreferences.getInstance();
      final userId = _getCurrentUserId();

      await prefs.remove('lastPlayedTitle_$userId');
      await prefs.remove('lastPlayedIndex_$userId');
      await prefs.remove('lastPosition_$userId');
      await prefs.remove('wasPlaying_$userId');
      await prefs.remove('lastPlaylist_$userId');
      await prefs.remove('lastTitles_$userId');
      await prefs.remove('lastArtworkUrls_$userId');
      await prefs.remove('repeatMode_$userId');
      await prefs.remove('isShuffling_$userId');

      print('✅ تم مسح بيانات المستخدم بنجاح');
    } catch (e) {
      print('❌ خطأ في مسح بيانات المستخدم: $e');
    }
  }

  // تنظيف الموارد
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    try {
      print('🧹 تنظيف موارد مشغل الصوت...');

      // إيقاف timer تحديث الموضع
      _positionUpdateTimer?.cancel();
      _positionUpdateTimer = null;

      if (_resumeTimer != null) {
        _resumeTimer!.cancel();
        _resumeTimer = null;
      }
      if (_debounceTimer != null) {
        _debounceTimer!.cancel();
        _debounceTimer = null;
      }

      if (_headphoneEventSubscription != null) {
        await _headphoneEventSubscription!.cancel();
        _headphoneEventSubscription = null;
      }

      try {
        await saveStateOnAppClose();
      } catch (e) {
        print('⚠️ تم تجاهل خطأ أثناء حفظ الحالة: $e');
      }

      try {
        if (_audioPlayer.playing) {
          await _audioPlayer.pause();
        }
        await Future.delayed(Duration(milliseconds: 100));
        await _audioPlayer.stop();
        await Future.delayed(Duration(milliseconds: 300));
        await _audioPlayer.dispose();
      } catch (e) {
        print('⚠️ تم تجاهل خطأ أثناء إيقاف وتحرير المشغل: $e');
      }

      try {
        if (_audioSession != null) {
          await _audioSession!.setActive(false);
        }
      } catch (e) {
        print('⚠️ تم تجاهل خطأ أثناء تنظيف جلسة الصوت: $e');
      }

      try {
        _cachedFiles.clear();
      } catch (e) {
        print('⚠️ تم تجاهل خطأ أثناء تنظيف الكاش المؤقت: $e');
      }

      _hideMediaNotification();

      print('✅ تم تنظيف موارد مشغل الصوت بنجاح');
    } catch (e) {
      print('❌ خطأ في تنظيف موارد مشغل الصوت: $e');
    }
  }

  // Getters للوصول إلى الحالة الحالية
  bool get isPlaying => isPlayingNotifier.value;
  bool get isPaused => !isPlayingNotifier.value;
  bool get isLoading => isLoadingNotifier.value;
  Duration get position => positionNotifier.value;
  Duration? get duration => durationNotifier.value;
  String? get currentTitle => currentTitleNotifier.value;
  int get currentIndex => currentIndexNotifier.value;
  bool get isShuffling => isShufflingNotifier.value;
  int get repeatMode => repeatModeNotifier.value;
  double get downloadProgress => downloadProgressNotifier.value;
  bool get isDisposed => _isDisposed;
  bool get isInitialized => _isInitialized;
  bool get headphonesConnected => _headphonesConnected;
  bool get wasPlayingBeforeInterruption => _wasPlayingBeforeInterruption;
  bool get isNavigating => _isNavigating;
  bool get isChangingTrack => _isChangingTrack;
  bool get isRecoveryInProgress => _isRecoveryInProgress;
  bool get isRestoringPosition => _isRestoringPosition;
  bool get isResumeInProgress => _isResumeInProgress;
  bool get preventStopDuringNavigation => _preventStopDuringNavigation;
  int get playlistLength => _playlist.length;
  List<String> get playlist => List.unmodifiable(_playlist);
  List<String> get titles => List.unmodifiable(_titles);
  List<String?> get artworkUrls => List.unmodifiable(_artworkUrls);
  bool get audioServiceEnabled => _audioServiceEnabled;
  bool get autoPlayPauseEnabled => _autoPlayPauseEnabled;

  // تنسيق الوقت
  String formatDuration(Duration? duration) {
    if (duration == null) return '00:00';

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  // تحديث AudioService من الخارج
  void updateAudioServiceState() {
    if (_audioServiceEnabled && _audioHandler != null) {
      _updateMediaItem();
      _updatePlaybackState();
      print('🔄 تم تحديث حالة AudioService');
    }
  }

  // دوال إضافية للتحكم
  void savePlaybackState() {
    if (_isDisposed) return;
    _wasPlayingBeforeInterruption = isPlayingNotifier.value;
  }

  void startNavigation() {
    if (_isDisposed) return;
    _isNavigating = true;
    savePlaybackState();
  }

  void setPreventStopDuringNavigation(bool prevent) {
    if (_isDisposed) return;
    _preventStopDuringNavigation = prevent;
  }

  void setPreventStateRestoration(bool prevent) {
    _preventStateRestoration = prevent;
  }

  Future<void> toggleAutoPlayPause() async {
    if (_isDisposed) return;

    try {
      _autoPlayPauseEnabled = !_autoPlayPauseEnabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_play_pause_enabled', _autoPlayPauseEnabled);
    } catch (e) {
      print('❌ خطأ في تغيير إعدادات التشغيل التلقائي: $e');
    }
  }

  Future<void> resumePlaybackAfterNavigation() async {
    if (_isDisposed) return;

    if (_resumeTimer != null) {
      _resumeTimer!.cancel();
      _resumeTimer = null;
    }

    _isNavigating = false;

    if (_isResumeInProgress) {
      return;
    }

    _isResumeInProgress = true;

    try {
      if (currentTitleNotifier.value != null && _wasPlayingBeforeInterruption) {
        if (_audioPlayer.processingState == ProcessingState.idle) {
          if (_playlist.isNotEmpty &&
              currentIndexNotifier.value < _playlist.length) {
            try {
              await playFromBeginning(
                  currentIndexNotifier.value, currentTitleNotifier.value!);
              _wasPlayingBeforeInterruption = false;
            } catch (e) {
              print('❌ خطأ في إعادة تحميل المصدر: $e');
            }
          }
        } else if (!_audioPlayer.playing) {
          await play();
          _wasPlayingBeforeInterruption = false;
        }
      }
    } catch (e) {
      print('❌ خطأ في استئناف التشغيل بعد الانتقال: $e');
    } finally {
      _isResumeInProgress = false;
    }
  }
}

// AudioService Handler محسن للتحكم الكامل
class MyAudioServiceHandler extends BaseAudioHandler {
  final MyAudioService _audioService;

  MyAudioServiceHandler(this._audioService) {
    print('🔗 تم إنشاء MyAudioServiceHandler للتحكم الكامل');

    // إعداد الاستماع لتغييرات الحالة
    _audioService.isPlayingNotifier.addListener(_updateFromAudioService);
    _audioService.positionNotifier.addListener(_updateFromAudioService);
    _audioService.currentTitleNotifier.addListener(_updateFromAudioService);
  }

  void _updateFromAudioService() {
    if (_audioService.isDisposed) return;

    try {
      // تحديث MediaItem
      final title = _audioService.currentTitleNotifier.value ?? 'ترنيمة';
      final artworkUrl = _audioService.currentIndexNotifier.value >= 0 &&
              _audioService.currentIndexNotifier.value <
                  _audioService.artworkUrls.length
          ? _audioService.artworkUrls[_audioService.currentIndexNotifier.value]
          : null;

      final mediaItem = MediaItem(
        id: _audioService.currentIndexNotifier.value.toString(),
        album: "أم النور",
        title: title,
        artist: "كورال أم النور",
        duration: _audioService.durationNotifier.value,
        artUri: artworkUrl != null ? Uri.parse(artworkUrl) : null,
        playable: true,
      );

      this.mediaItem.add(mediaItem);

      // تحديث PlaybackState
      final playbackState = PlaybackState(
        controls: [
          if (_audioService.currentIndexNotifier.value > 0)
            MediaControl.skipToPrevious,
          if (_audioService.isPlayingNotifier.value)
            MediaControl.pause
          else
            MediaControl.play,
          if (_audioService.currentIndexNotifier.value <
              _audioService.playlistLength - 1)
            MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.playPause,
        },
        androidCompactActionIndices: [0, 1, 2],
        processingState: _audioService.isLoadingNotifier.value
            ? AudioProcessingState.loading
            : AudioProcessingState.ready,
        playing: _audioService.isPlayingNotifier.value,
        updatePosition: _audioService.positionNotifier.value,
        bufferedPosition: _audioService.positionNotifier.value,
        speed: _audioService.isPlayingNotifier.value ? 1.0 : 0.0,
        queueIndex: _audioService.currentIndexNotifier.value,
      );

      this.playbackState.add(playbackState);

      print(
          '📱 Handler: تم تحديث MediaItem والPlaybackState - ${title}, Playing: ${_audioService.isPlayingNotifier.value}');
    } catch (e) {
      print('⚠️ خطأ في تحديث Handler: $e');
    }
  }

  // تشغيل
  @override
  Future<void> play() async {
    print('🎵 AudioService Handler: play استدعيت من شاشة القفل/الإشعارات');
    try {
      await _audioService.play();
      print('✅ AudioService Handler: تم تنفيذ play بنجاح');
    } catch (e) {
      print('❌ AudioService Handler: خطأ في play: $e');
    }
  }

  // إيقاف مؤقت
  @override
  Future<void> pause() async {
    print('⏸️ AudioService Handler: pause استدعيت من شاشة القفل/الإشعارات');
    try {
      await _audioService.pause();
      print('✅ AudioService Handler: تم تنفيذ pause بنجاح');
    } catch (e) {
      print('❌ AudioService Handler: خطأ في pause: $e');
    }
  }

  // التالي
  @override
  Future<void> skipToNext() async {
    print(
        '⏭️ AudioService Handler: skipToNext استدعيت من شاشة القفل/الإشعارات');
    try {
      await _audioService.playNext();
      print('✅ AudioService Handler: تم تنفيذ skipToNext بنجاح');
    } catch (e) {
      print('❌ AudioService Handler: خطأ في skipToNext: $e');
    }
  }

  // السابق
  @override
  Future<void> skipToPrevious() async {
    print(
        '⏮️ AudioService Handler: skipToPrevious استدعيت من شاشة القفل/الإشعارات');
    try {
      await _audioService.playPrevious();
      print('✅ AudioService Handler: تم تنفيذ skipToPrevious بنجاح');
    } catch (e) {
      print('❌ AudioService Handler: خطأ في skipToPrevious: $e');
    }
  }

  // البحث
  @override
  Future<void> seek(Duration position) async {
    print('🔍 AudioService Handler: seek استدعيت: ${position.inSeconds}s');
    try {
      await _audioService.seek(position);
      print('✅ AudioService Handler: تم تنفيذ seek بنجاح');
    } catch (e) {
      print('❌ AudioService Handler: خطأ في seek: $e');
    }
  }

  // إيقاف
  @override
  Future<void> stop() async {
    print('⏹️ AudioService Handler: stop استدعيت من شاشة القفل/الإشعارات');
    try {
      await _audioService.stop();
      print('✅ AudioService Handler: تم تنفيذ stop بنجاح');
    } catch (e) {
      print('❌ AudioService Handler: خطأ في stop: $e');
    }
  }

  // تنظيف الموارد
  void dispose() {
    try {
      _audioService.isPlayingNotifier.removeListener(_updateFromAudioService);
      _audioService.positionNotifier.removeListener(_updateFromAudioService);
      _audioService.currentTitleNotifier
          .removeListener(_updateFromAudioService);
      print('✅ تم تنظيف موارد AudioService Handler');
    } catch (e) {
      print('⚠️ خطأ في تنظيف Handler: $e');
    }
  }
}

// فئة عنصر قائمة انتظار التحميل
class _DownloadQueueItem {
  final String url;
  final int priority;
  final Completer<String?> completer;

  _DownloadQueueItem({
    required this.url,
    required this.priority,
    required this.completer,
  });
}
