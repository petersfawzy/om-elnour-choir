import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class MyAudioService {
  // استخدام DefaultCacheManager العادي بدون تخصيص
  final DefaultCacheManager _cacheManager = DefaultCacheManager();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Playlists
  List<String> _playlist = [];
  List<String> _titles = [];
  List<String?> _artworkUrls = [];

  // Cached files
  final Map<String, String> _cachedFiles = {};

  // Download queue for better management
  final List<_DownloadQueueItem> _downloadQueue = [];
  int _activeDownloads = 0;
  final int _maxConcurrentDownloads = 3;

  // State notifiers
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> positionNotifier =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration?> durationNotifier =
      ValueNotifier<Duration?>(null);
  final ValueNotifier<String?> currentTitleNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<int> currentIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isShufflingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> repeatModeNotifier =
      ValueNotifier<int>(0); // 0: off, 1: one, 2: all
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> downloadProgressNotifier =
      ValueNotifier<double>(0.0);

  // Position restoration flag
  bool _isRestoringPosition = false;

  // إضافة متغير لتتبع ما إذا كان يجب استئناف التشغيل بعد الانتقال
  bool _shouldResumeAfterNavigation = false;

  // إضافة متغير لمنع الإيقاف والتشغيل المتكرر
  bool _isResumeInProgress = false;

  // إضافة متغير لمنع إيقاف التشغيل أثناء التنقل
  bool _preventStopDuringNavigation = true;

  // إضافة متغير لتتبع ما إذا كان التشغيل مستمراً قبل المقاطعة
  bool _wasPlayingBeforeInterruption = false;

  // إضافة متغير للتعامل مع جلسة الصوت
  AudioSession? _audioSession;

  // إضافة متغير لمتابعة حالة تهيئة الخدمة
  bool _isInitialized = false;

  // إضافة مؤقت للمحاولة المتكررة لاستئناف التشغيل
  Timer? _resumeTimer;

  // إضافة متغير للتعامل مع الانتقال بين الشاشات
  bool _isNavigating = false;

  // تعديل تعريف متغير الـ callback ليكون قابل للإلغاء (nullable)
  Function(int, String)? _onHymnChangedCallback;

  // إضافة متغير لمنع الضغط المتكرر على أزرار التالي/السابق
  bool _isChangingTrack = false;

  // إضافة مؤقت لمنع الضغط المتكرر
  Timer? _debounceTimer;

  // إضافة متغير لتتبع عدد محاولات التعافي من الأخطاء
  int _recoveryAttempts = 0;

  // إضافة متغير لتتبع آخر خطأ
  DateTime? _lastErrorTime;

  // إضافة متغير للتعامل مع اكتشاف سماعات الرأس
  bool _headphonesConnected = false;
  bool _wasPlayingBeforeDisconnect = false;
  StreamSubscription? _headphoneEventSubscription;
  bool _autoPlayPauseEnabled = true; // تمكين الميزة افتراضيًا

  // إضافة متغير لتتبع ما إذا كان الكائن قد تم التخلص منه
  bool _isDisposed = false;

  // إضافة متغير لتتبع ما إذا كانت عملية التعافي قيد التنفيذ
  bool _isRecoveryInProgress = false;

  // الحد الأقصى لمحاولات إعادة المحاولة
  int _maxRetryAttempts = 5; // زيادة عدد المحاولات

  // مسار الدليل المؤقت
  String? _tempDirPath;

  // إضافة متغير لتتبع URLs التي فشلت
  final Map<String, DateTime> _failedUrls = {};

  // إضافة متغير لتخزين callbacks لسياق قائمة التشغيل
  final List<Function?> _playlistContextCallbacks = List.filled(5, null);

  // إضافة متغيرات لتتبع آخر ترنيمة تم زيادة عدد مشاهداتها
  String? _lastIncrementedHymnId;
  DateTime? _lastIncrementTime;

  // إضافة متغير لمنع استعادة الحالة السابقة عند اختيار ترنيمة جديدة
  bool _preventStateRestoration = false;

  // إضافة متغير لتتبع ما إذا كان التشغيل قد بدأ فعلياً
  bool _playbackStarted = false;

  // إضافة متغير لتتبع ما إذا كان هناك محاولة تشغيل جارية
  bool _isPlayAttemptInProgress = false;

  // تعديل دالة تسجيل callback لزيادة عدد المشاهدات لتقبل قيمة null
  void registerHymnChangedCallback(Function(int, String)? callback) {
    print(
        '📊 ${callback == null ? "إلغاء تسجيل" : "تسجيل"} callback لزيادة عدد المشاهدات');

    // نفحص ما إذا كانت الـ callback الجديدة هي نفسها الـ callback الحالية
    if (_onHymnChangedCallback == callback) {
      print('⚠️ محاولة تسجيل نفس الـ callback، سيتم تجاهل الطلب');
      return;
    }

    _onHymnChangedCallback = callback;

    // طباعة معلومات تصحيح عن الـ callback
    if (callback != null) {
      print('📊 تفاصيل الـ callback: ${callback.runtimeType}');
    }
  }

  // إضافة دالة جديدة لتسجيل callback لسياق قائمة التشغيل
  void registerPlaylistContextCallback(Function callback) {
    bool registered = false;

    // البحث عن فتحة فارغة أولاً
    for (int i = 0; i < _playlistContextCallbacks.length; i++) {
      if (_playlistContextCallbacks[i] == null) {
        _playlistContextCallbacks[i] = callback;
        print('📋 تم تسجيل callback لسياق قائمة التشغيل في الفهرس: $i');
        registered = true;
        break;
      }
    }

    // إذا لم يتم العثور على فتحة فارغة، استبدل أول callback
    if (!registered) {
      _playlistContextCallbacks[0] = callback;
      print('📋 تم استبدال callback لسياق قائمة التشغيل في الفهرس: 0');
    }

    // طباعة جميع callbacks المسجلة للتصحيح
    int count = 0;
    for (var cb in _playlistContextCallbacks) {
      if (cb != null) count++;
    }
    print('📋 إجمالي callbacks المسجلة لسياق قائمة التشغيل: $count');
  }

  // تعديل منشئ MyAudioService للتأكد من استدعاء restorePlaybackState مرة واحدة فقط
  MyAudioService() {
    // استدعاء _initAudioService مرة واحدة فقط عند إنشاء الكائن
    _initAudioService();

    // تهيئة مسار الدليل المؤقت
    _initTempDir();
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

  // تعديل دالة _initAudioService لمنع استعادة الحالة السابقة عند اختيار ترنيمة جديدة
  // تعديل دالة _initAudioService لتسريع عملية التهيئة
  Future<void> _initAudioService() async {
    if (_isInitialized || _isDisposed) return;

    try {
      // تقليل التأخير الأولي
      await Future.delayed(Duration(milliseconds: 100));

      // إعادة تعيين حالة التحميل في البداية
      isLoadingNotifier.value = false;

      // تهيئة مشغل الصوت أولاً (الأولوية القصوى)
      await _initAudioPlayer();

      // تهيئة باقي المكونات بشكل متوازٍ
      await Future.wait([
        _setupAudioFocusHandling(),
        _loadAutoPlayPauseSettings(),
      ]);

      // إعداد اكتشاف سماعات الرأس (أقل أهمية)
      try {
        _setupHeadphoneDetection();
      } catch (e) {
        print('⚠️ تم تجاهل خطأ إعداد اكتشاف سماعات الرأس: $e');
      }

      // تنظيف الكاش القديم في الخلفية (غير مهم للتشغيل الفوري)
      Future.microtask(() {
        if (!_isDisposed) {
          performPeriodicCacheCleanup();
        }
      });

      // تهيئة الخدمة اكتملت
      _isInitialized = true;
      print('✅ تم تهيئة خدمة الصوت بنجاح');

      // استعادة الحالة السابقة فقط إذا لم يتم منعها
      if (!_preventStateRestoration) {
        // استعادة الحالة في الخلفية لتسريع التشغيل الأول
        Future.microtask(() {
          if (!_isDisposed) {
            restorePlaybackState();
          }
        });
      } else {
        print('⚠️ تم منع استعادة الحالة السابقة بناءً على الطلب');
        // إعادة تعيين العلامة بعد الاستخدام
        _preventStateRestoration = false;
      }
    } catch (e) {
      print('❌ خطأ في تهيئة خدمة الصوت: $e');
      // محاولة إعادة التهيئة بعد فترة أطول
      if (!_isDisposed) {
        Future.delayed(Duration(seconds: 2), () {
          _initAudioService();
        });
      }
    }
  }

  // إضافة دالة للتعامل مع تركيز الصوت
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

      // التعامل مع حدث فصل سماعات الرأس
      _audioSession?.becomingNoisyEventStream.listen((_) {
        if (_isDisposed) return;

        print('🎧 تم فصل سماعات الرأس أو تغيير حالة الصوت');
        if (isPlayingNotifier.value) {
          _wasPlayingBeforeInterruption = true;
          pause();
          print('⏸️ تم إيقاف التشغيل مؤقتًا بسبب فصل سماعات الرأس');
        }
      });

      // التعامل مع مقاطعات الصوت (مثل المكالمات)
      _audioSession?.interruptionEventStream.listen((event) {
        if (_isDisposed) return;

        if (event.begin) {
          // بدأت المقاطعة
          print('📞 بدأت مقاطعة الصوت');
          if (isPlayingNotifier.value) {
            _wasPlayingBeforeInterruption = true;
            pause();
          }
        } else {
          // انتهت المقاطعة
          print('📞 انتهت مقاطعة الصوت');
          if (_wasPlayingBeforeInterruption &&
              event.type == AudioInterruptionType.pause) {
            play();
            _wasPlayingBeforeInterruption = false;
            print('▶️ تم استئناف التشغيل بعد انتهاء المقاطعة');
          }
        }
      });

      print('✅ تم إعداد التعامل مع تركيز الصوت بنجاح');
    } catch (e) {
      print('❌ خطأ في إعداد التعامل مع تركيز الصوت: $e');
      // إعادة المحاولة لاحقاً
      rethrow;
    }
  }

  // تعديل _setupHeadphoneDetection ليكون أكثر مرونة
  Future<void> _setupHeadphoneDetection() async {
    if (_isDisposed) return;

    try {
      print('🔄 جاري إعداد اكتشاف سماعات الرأس...');

      // التحقق مما إذا كنا في بيئة محاكاة
      bool isSimulator = false;
      try {
        // محاولة استدعاء طريقة للتحقق من بيئة المحاكاة
        const MethodChannel channel =
            MethodChannel('com.egypt.redcherry.omelnourchoir/app');
        isSimulator = await channel.invokeMethod('isSimulator') ?? false;
      } catch (e) {
        // إذا فشلت الطريقة، نفترض أننا في بيئة محاكاة
        isSimulator = true;
        print('⚠️ افتراض أننا في بيئة محاكاة بسبب: $e');
      }

      if (isSimulator) {
        print('⚠️ تم اكتشاف بيئة محاكاة، تعطيل ميزات اكتشاف سماعات الرأس');
        _headphonesConnected = false;
        _headphoneEventSubscription = null;
        return;
      }

      // إنشاء قناة الأحداث استقبال تغييرات حالة سماعات الرأس
      const EventChannel headphoneEventsChannel =
          EventChannel('com.egypt.redcherry.omelnourchoir/headphone_events');

      // محاولة الاستماع لأحداث تغيير حالة سماعات الرأس مع معالجة الأخطاء
      try {
        _headphoneEventSubscription = headphoneEventsChannel
            .receiveBroadcastStream()
            .listen(_handleHeadphoneStateChange, onError: (error) {
          print('⚠️ خطأ في مراقبة حالة سماعات الرأس: $error');
          // تعيين الاشتراك إلى null لتجنب محاولة إلغائه لاحقًا
          _headphoneEventSubscription = null;
        });
        print('✅ تم إعداد مراقبة حالة سماعات الرأس بنجاح');
      } catch (e) {
        print('⚠️ فشل في إعداد مراقبة سماعات الرأس: $e');
        _headphoneEventSubscription = null;
      }

      // التحقق من حالة سماعات الرأس الحالية بأمان
      try {
        checkHeadphoneStatus().then((isConnected) {
          if (_isDisposed) return;

          _headphonesConnected = isConnected;
          print(
              '🎧 حالة سماعات الرأس عند بدء التشغيل: ${_headphonesConnected ? "متصلة" : "غير متصلة"}');
        }).catchError((e) {
          print('⚠️ فشل في التحقق من حالة سماعات الرأس: $e');
          _headphonesConnected = false;
        });
      } catch (e) {
        print('⚠️ خطأ في التحقق من حالة سماعات الرأس: $e');
        _headphonesConnected = false;
      }

      print('✅ تم إعداد اكتشاف سماعات الرأس بنجاح');
    } catch (e) {
      print('❌ خطأ في إعداد اكتشاف سماعات الرأس: $e');
      // تعيين القيم الافتراضية لضمان استمرار عمل التطبيق
      _headphonesConnected = false;
      _headphoneEventSubscription = null;
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
        print('▶️ تم استئناف التشغيل بعد إعادة توصيل سماعات الرأس');
      }
    } else if (event == 'disconnected') {
      _headphonesConnected = false;
      if (isPlayingNotifier.value) {
        _wasPlayingBeforeDisconnect = true;
        pause();
        print('⏸️ تم إيقاف التشغيل مؤقتًا بسبب فصل سماعات الرأس');
      }
    } else if (event == 'removed') {
      // سماعات الرأس لا تزال متصلة ولكن تمت إزالتها من الأذن
      if (isPlayingNotifier.value) {
        _wasPlayingBeforeDisconnect = true;
        pause();
        print('⏸️ تم إيقاف التشغيل مؤقتًا بسبب إزالة سماعات الرأس من الأذن');
      }
    }
  }

  // تحميل إعدادات التشغيل/الإيقاف التلقائي
  Future<void> _loadAutoPlayPauseSettings() async {
    if (_isDisposed) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _autoPlayPauseEnabled = prefs.getBool('auto_play_pause_enabled') ?? true;
      print(
          '⚙️ تم تحميل إعدادات التشغيل/الإيقاف التلقائي: ${_autoPlayPauseEnabled ? "ممكّن" : "معطّل"}');
    } catch (e) {
      print('❌ خطأ في تحميل إعدادات التشغيل/الإيقاف التلقائي: $e');
    }
  }

  // إضافة دالة لتبديل إعدادات التشغيل/الإيقاف التلقائي
  Future<void> toggleAutoPlayPause() async {
    if (_isDisposed) return;

    try {
      _autoPlayPauseEnabled = !_autoPlayPauseEnabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_play_pause_enabled', _autoPlayPauseEnabled);
      print(
          '⚙️ تم تغيير إعدادات التشغيل/الإيقاف التلقائي إلى: ${_autoPlayPauseEnabled ? "ممكّن" : "معطّل"}');
    } catch (e) {
      print('❌ خطأ في تغيير إعدادات التشغيل/الإيقاف التلقائي: $e');
    }
  }

  // إضافة getter لحالة تمكين التشغيل/الإيقاف التلقائي
  bool get autoPlayPauseEnabled => _autoPlayPauseEnabled;

  // تعديل checkHeadphoneStatus ليكون أكثر مرونة
  Future<bool> checkHeadphoneStatus() async {
    if (_isDisposed) return false;

    try {
      // التحقق مما إذا كنا في بيئة محاكاة
      bool isSimulator = false;
      try {
        const MethodChannel channel =
            MethodChannel('com.egypt.redcherry.omelnourchoir/app');
        isSimulator = await channel.invokeMethod('isSimulator') ?? false;
      } catch (e) {
        // إذا فشلت الطريقة، نفترض أننا في بيئة محاكاة
        isSimulator = true;
      }

      if (isSimulator) {
        // في بيئة المحاكاة، نفترض دائمًا أن سماعات الرأس غير متصلة
        return false;
      }

      const MethodChannel channel =
          MethodChannel('com.egypt.redcherry.omelnourchoir/app');
      final bool? isConnected =
          await channel.invokeMethod('checkHeadphoneStatus');
      return isConnected ?? false;
    } catch (e) {
      print("⚠️ فشل في التحقق من حالة سماعات الرأس: $e");
      // إرجاع false بدلاً من رمي استثناء
      return false;
    }
  }

  // تعديل في دالة _initAudioPlayer لضمان تشغيل الترنيمة التالية عند انتهاء الحالية
  Future<void> _initAudioPlayer() async {
    if (_isDisposed) return;

    // منع إعادة التهيئة إذا كان المشغل مهيأ بالفعل
    if (_audioPlayer.playerState.processingState != ProcessingState.idle) {
      print('⚠️ مشغل الصوت مهيأ بالفعل، تجاهل طلب إعادة التهيئة');
      return;
    }

    try {
      // تنظيف أي استماع سابق
      await _audioPlayer.stop();

      // إعادة تعيين حالة التحميل عند بدء التشغيل
      isLoadingNotifier.value = false;

      // Listen to playback state changes
      _audioPlayer.playerStateStream.listen((state) {
        if (_isDisposed) return;

        print(
            '🎵 تغيرت حالة التشغيل: ${state.playing ? 'يعمل' : 'متوقف'}, ${state.processingState}');
        isPlayingNotifier.value = state.playing;

        // تحديث حالة التحميل - فقط إظهار مؤشر التحميل عند التحميل الفعلي
        isLoadingNotifier.value =
            state.processingState == ProcessingState.loading ||
                state.processingState == ProcessingState.buffering;

        // تحديث القيمة العالمية عند تغير حالة التشغيل
        _wasPlayingBeforeInterruption = state.playing;

        // إذا انتهت عملية التحميل، نعتبر أن عملية تغيير المسار انتهت
        if (state.processingState == ProcessingState.ready) {
          _isChangingTrack = false;
        }
      });

      // Listen to position changes
      _audioPlayer.positionStream.listen((position) {
        if (_isDisposed) return;

        if (!_isRestoringPosition) {
          positionNotifier.value = position;
        }
      });

      // Listen to duration changes
      _audioPlayer.durationStream.listen((duration) {
        if (_isDisposed) return;

        durationNotifier.value = duration;
      });

      // Listen to playback completion
      _audioPlayer.processingStateStream.listen((state) {
        if (_isDisposed) return;

        if (state == ProcessingState.completed) {
          print('🎵 الترنيمة انتهت، وضع التكرار: ${repeatModeNotifier.value}');

          if (repeatModeNotifier.value == 1) {
            // Repeat current hymn
            print('🔄 تكرار الترنيمة الحالية');
            _audioPlayer.seek(Duration.zero);
            _audioPlayer.play();
          } else {
            // Play next hymn (with wrap-around) even if repeat mode is off
            print(
                '⏭️ الانتقال إلى الترنيمة التالية بعد انتهاء الترنيمة الحالية');

            // Calculate next index
            int nextIndex = (currentIndexNotifier.value + 1) % _playlist.length;

            // Call callback to increment play count before playing next hymn
            if (_onHymnChangedCallback != null &&
                nextIndex >= 0 &&
                nextIndex < _titles.length) {
              print(
                  '📊 Calling callback to increment play count for auto-next hymn: ${_titles[nextIndex]}');
              // تعديل هنا: استخدام الدالة المساعدة بدلاً من استدعاء callback مباشرة
              _onHymnChangedFromAudioService(nextIndex, _titles[nextIndex]);
            } else {
              print(
                  '⚠️ Cannot call callback for auto-next: ${_onHymnChangedCallback == null ? "callback is null" : "index out of range"}');
            }

            playNext();
          }
        }
      });

      // Listen to errors to recover from them
      _audioPlayer.playbackEventStream.listen(
        (event) {
          if (_isDisposed) return;

          // تسجيل الأحداث للتصحيح
          if (event.processingState == ProcessingState.idle) {
            print('🎵 حالة المشغل: خامل (idle)');
          }
        },
        onError: (error) {
          if (_isDisposed) return;

          print('❌ خطأ في حدث التشغيل: $error');
          // محاولة إعادة تهيئة المشغل
          _handlePlaybackError();
        },
      );

      // Restore previous playback state
      await restorePlaybackState();

      print('✅ تم تهيئة مشغل الصوت بنجاح');
    } catch (e) {
      print('❌ خطأ في تهيئة مشغل الصوت: $e');
      // إعادة المحاولة لاحقاً
      rethrow;
    }
  }

  // دالة جديدة للتعامل مع أخطاء التشغيل
  Future<void> _handlePlaybackError() async {
    if (_isDisposed || _isRecoveryInProgress) return;

    _isRecoveryInProgress = true;
    _recoveryAttempts++;
    _lastErrorTime = DateTime.now();

    print('⚠️ محاولة التعافي من الخطأ: $_recoveryAttempts');

    try {
      if (_recoveryAttempts <= _maxRetryAttempts) {
        // محاولة إعادة تهيئة المشغل
        print('🔄 محاولة إعادة تهيئة مشغل الصوت');

        // إيقاف التشغيل الحالي
        await _audioPlayer.stop();

        // إضافة تأخير قصير
        await Future.delayed(Duration(milliseconds: 500));

        // إعادة تهيئة المشغل
        await _initAudioPlayer();

        // محاولة استئناف التشغيل
        if (_wasPlayingBeforeInterruption) {
          print('▶️ محاولة استئناف التشغيل');

          // التحقق مما إذا كانت هناك ترنيمة حالية
          if (currentIndexNotifier.value >= 0 &&
              currentIndexNotifier.value < _playlist.length &&
              currentTitleNotifier.value != null) {
            await play(currentIndexNotifier.value, currentTitleNotifier.value);
            print('✅ تم استئناف التشغيل بنجاح');
          }
        }

        print('✅ تم التعافي من الخطأ بنجاح');
      } else {
        print('❌ تم تجاوز الحد الأقصى لمحاولات التعافي');
        // إعادة تعيين العداد بعد فترة
        Future.delayed(Duration(minutes: 5), () {
          if (!_isDisposed) {
            _recoveryAttempts = 0;
          }
        });
      }
    } catch (e) {
      print('❌ فشلت محاولة التعافي: $e');
    } finally {
      _isRecoveryInProgress = false;
    }
  }

  // دالة جديدة للتعافي من انقطاع التحميل
  Future<void> _recoverFromLoadingInterruption() async {
    if (_isDisposed || _isRecoveryInProgress) return;

    _isRecoveryInProgress = true;

    try {
      print('⚠️ محاولة التعافي من انقطاع التحميل...');

      // إيقاف التشغيل الحالي
      await _audioPlayer.stop();

      // إضافة تأخير قصير
      await Future.delayed(Duration(milliseconds: 500));

      // محاولة إعادة تحميل الترنيمة الحالية
      if (currentIndexNotifier.value >= 0 &&
          currentIndexNotifier.value < _playlist.length &&
          currentTitleNotifier.value != null) {
        // محاولة تحميل الملف من الكاش أولاً
        final url = _playlist[currentIndexNotifier.value];
        final cachedPath = await _getCachedFile(url);

        if (cachedPath != null) {
          print('🔄 محاولة تحميل الملف من الكاش...');
          try {
            final fileSource = AudioSource.uri(Uri.file(cachedPath));
            await _audioPlayer.setAudioSource(fileSource, preload: true);

            if (_wasPlayingBeforeInterruption) {
              await _audioPlayer.play();
            }

            print('✅ تم التعافي من انقطاع التحميل باستخدام الكاش');
            _isRecoveryInProgress = false;
            return;
          } catch (e) {
            print('❌ فشل التعافي باستخدام الكاش: $e');
          }
        }

        // محاولة تحميل الملف من الإنترنت
        print('🔄 محاولة تحميل الملف من الإنترنت...');
        try {
          // تنزيل ال��لف مباشرة إلى ملف مؤقت
          final tempFile = await _downloadToTempFile(url);

          if (tempFile != null) {
            // استخدام الملف المؤقت
            final fileSource = AudioSource.uri(Uri.file(tempFile));
            await _audioPlayer.setAudioSource(fileSource, preload: true);

            if (_wasPlayingBeforeInterruption) {
              await _audioPlayer.play();
            }

            print('✅ تم التعافي من انقطاع التحميل باستخدام ملف مؤقت');
            _isRecoveryInProgress = false;
            return;
          }

          // محاولة استخدام setUrl مباشرة
          await _audioPlayer.setUrl(url);

          if (_wasPlayingBeforeInterruption) {
            await _audioPlayer.play();
          }

          print('✅ تم التعافي من انقطاع التحميل باستخدام الإنترنت');
        } catch (e) {
          print('❌ فشل التعافي باستخدام الإنترنت: $e');

          // محاولة أخيرة باستخدام استراتيجية مختلفة
          try {
            final audioSource = AudioSource.uri(Uri.parse(url));
            await _audioPlayer.setAudioSource(audioSource, preload: false);

            if (_wasPlayingBeforeInterruption) {
              await _audioPlayer.play();
            }

            print('✅ تم التعافي من انقطاع التحميل باستخدام استراتيجية بديلة');
          } catch (e2) {
            print('❌ فشلت جميع محاولات التعافي: $e2');
            // استدعاء آلية التعافي العامة
            await _handlePlaybackError();
          }
        }
      }
    } catch (e) {
      print('❌ خطأ في التعافي من انقطاع التحميل: $e');
    } finally {
      // تأكد من إعادة تعيين علامة استعادة الموضع
      _isRestoringPosition = false;
      _isRecoveryInProgress = false;
    }
  }

  // دالة جديدة لتنزيل الملف مباشرة إلى ملف مؤقت
  // تحسين دالة _downloadToTempFile لتسريع التنزيل
  Future<String?> _downloadToTempFile(String url,
      {bool highPriority = false}) async {
    if (_isDisposed || _tempDirPath == null) return null;

    // التحقق من وجود الملف في الكاش أولاً
    final cachedPath = await _getCachedFile(url);
    if (cachedPath != null) {
      return cachedPath;
    }

    // زيادة عدد التنزيلات المتزامنة للملفات ذات الأولوية العالية
    if (highPriority) {
      // تنزيل الملف مباشرة بدلاً من إضافته للقائمة
      return await _downloadFile(url, true);
    }

    // Add to download queue for normal priority files
    final completer = Completer<String?>();
    _downloadQueue.add(_DownloadQueueItem(
        url: url, priority: highPriority ? 1 : 0, completer: completer));

    // Sort queue by priority
    _downloadQueue.sort((a, b) => b.priority.compareTo(a.priority));

    // Start processing queue
    _processDownloadQueue();

    return completer.future;
  }

  // Process download queue
  void _processDownloadQueue() async {
    if (_isDisposed) return;

    // Check if we can start new downloads
    while (_activeDownloads < _maxConcurrentDownloads &&
        _downloadQueue.isNotEmpty) {
      final item = _downloadQueue.removeAt(0);
      _activeDownloads++;

      // Start download
      _downloadFile(item.url, item.priority > 0).then((result) {
        _activeDownloads--;
        item.completer.complete(result);
        // Process next item in queue
        _processDownloadQueue();
      });
    }
  }

  // Actually download a file
  // تحسين دالة _downloadFile لتسريع التنزيل
  Future<String?> _downloadFile(String url, bool highPriority) async {
    if (_isDisposed || _tempDirPath == null) return null;

    try {
      // إنشاء اسم ملف فريد
      final fileName = 'hymn_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final filePath = '$_tempDirPath/$fileName';

      // التحقق مما إذا كان الملف موجودًا بالفعل في التخزين المؤقت
      if (_cachedFiles.containsKey(url) && _cachedFiles[url]!.isNotEmpty) {
        final existingPath = _cachedFiles[url]!;
        final file = File(existingPath);
        if (await file.exists()) {
          return existingPath;
        }
      }

      // تنزيل الملف مع الأولوية
      final httpClient = HttpClient();
      httpClient.connectionTimeout =
          Duration(seconds: 10); // تقليل مهلة الاتصال
      final request = await httpClient.getUrl(Uri.parse(url));

      // تعيين أولوية أعلى للتنزيلات المهمة
      if (highPriority) {
        request.headers.add('Priority', 'high');
      }

      final response = await request.close();

      if (response.statusCode != 200) {
        print('❌ فشل تنزيل الملف: ${response.statusCode}');
        return null;
      }

      // كتابة البيانات إلى الملف مع تتبع التقدم
      final file = File(filePath);
      final sink = file.openWrite();

      // الحصول على الحجم الإجمالي لحساب التقدم
      final totalSize = response.contentLength;
      int downloadedBytes = 0;

      // تحديث مؤشر التقدم بشكل أقل تكراراً لتحسين الأداء
      int lastProgressUpdate = 0;

      await response.forEach((bytes) {
        sink.add(bytes);
        downloadedBytes += bytes.length;

        // تحديث مؤشر التقدم بشكل أقل تكراراً
        if (totalSize > 0) {
          final progress = downloadedBytes / totalSize;
          final currentTime = DateTime.now().millisecondsSinceEpoch;

          // تحديث كل 200 مللي ثانية فقط
          if (currentTime - lastProgressUpdate > 200) {
            downloadProgressNotifier.value = progress;
            lastProgressUpdate = currentTime;
          }
        }
      });

      await sink.flush();
      await sink.close();

      print('✅ تم تنزيل الملف إلى: $filePath');

      // تخزين المسار في التخزين المؤقت
      _cachedFiles[url] = filePath;

      // إعادة تعيين مؤشر التقدم
      downloadProgressNotifier.value = 0.0;

      return filePath;
    } catch (e) {
      print('❌ خطأ في تنزيل الملف: $e');
      return null;
    }
  }

  // دالة جديدة للتحقق من صحة URL وإصلاحها إذا لزم الأمر
  String _sanitizeUrl(String url) {
    try {
      // التحقق مما إذا كانت URL قد فشلت سابقًا
      if (_failedUrls.containsKey(url)) {
        final failedTime = _failedUrls[url]!;
        // إذا كان الفشل حديثًا (خلال الساعة الماضية)، نحاول إصلاح URL
        if (DateTime.now().difference(failedTime).inHours < 1) {
          print('⚠️ تم اكتشاف URL فاشلة سابقًا، محاولة إصلاحها: $url');

          // محاولة إصلاح مشكلة الحروف العربية في URL
          // تحويل الحروف المتشابهة مثل ذ/ز، ظ/ض، إلخ
          String fixedUrl = url;

          // استبدال "لعاذر" ب "لعازر" في URL (مثال محدد للمشكلة الحالية)
          if (url.contains('%D9%84%D8%B9%D8%A7%D8%B0%D8%B1')) {
            fixedUrl = url.replaceAll('%D9%84%D8%B9%D8%A7%D8%B0%D8%B1',
                '%D9%84%D8%B9%D8%A7%D8%B2%D8%B1');
            print('🔧 تم إصلاح URL: $fixedUrl');
          }

          return fixedUrl;
        }
      }

      // إذا كانت URL تحتوي على أحرف عربية، نتأكد من أنها مشفرة بشكل صحيح
      if (url.contains('%')) {
        try {
          // محاولة فك تشفير URL للتحقق من صحتها
          Uri.parse(url);
          return url; // URL صحيحة
        } catch (e) {
          print('⚠️ URL غير صالحة، محاولة إصلاحها: $url');
          // محاولة إعادة تشفير URL
          final decodedUrl = Uri.decodeFull(url);
          final encodedUrl = Uri.encodeFull(decodedUrl);
          return encodedUrl;
        }
      }

      return url;
    } catch (e) {
      print('⚠️ خطأ في معالجة URL: $e');
      return url; // إرجاع URL الأصلية في حالة حدوث خطأ
    }
  }

  // تعديل setPlaylist لتحسين معالجة الأخطاء
  Future<void> setPlaylist(List<String> urls, List<String> titles,
      [List<String?> artworkUrls = const []]) async {
    if (_isDisposed) return;

    if (urls.isEmpty || titles.isEmpty || urls.length != titles.length) {
      print('Invalid playlist');
      return;
    }

    try {
      // حفظ حالة التشغيل قبل تغيير قائمة التشغيل
      _wasPlayingBeforeInterruption = isPlayingNotifier.value;

      // تنظيف URLs وإصلاحها إذا لزم الأمر
      List<String> sanitizedUrls = urls.map(_sanitizeUrl).toList();

      _playlist = sanitizedUrls;
      _titles = titles;

      // إذا تم توفير روابط صور، استخدمها، وإلا استخدم قائمة فارغة بنفس طول القائمة
      if (artworkUrls.isNotEmpty && artworkUrls.length == urls.length) {
        _artworkUrls = artworkUrls;
      } else {
        _artworkUrls = List.filled(urls.length, null);
      }

      // حفظ قائمة التشغيل الجديدة
      await _saveCurrentState();

      print('✅ تم تعيين قائمة التشغيل: ${urls.length} ترنيمة');
    } catch (e) {
      print('❌ خطأ في تعيين قائمة التشغيل: $e');

      // معالجة PlatformException بشكل خاص
      if (e is PlatformException && e.code == 'abort') {
        print('⚠️ تم قطع التحميل، محاولة استعادة الحالة...');
        await _recoverFromLoadingInterruption();
      }
    }
  }

  // تعديل دالة play لإضافة callback لزيادة عدد المشاهدات
  Future<void> play([int? index, String? title]) async {
    // التأكد من اكتمال التهيئة
    if (_isDisposed) return;

    // منع تنفيذ عمليات متعددة في نفس الوقت
    if (_isPlayAttemptInProgress) {
      print('⚠️ هناك محاولة تشغيل جارية بالفعل، تجاهل الطلب الجديد');
      return;
    }

    _isPlayAttemptInProgress = true;
    isLoadingNotifier.value = true; // إظهار مؤشر التحميل فوراً

    try {
      // تعديل هذا الجزء لمنع إعادة التهيئة عند اختيار ترنيمة جديدة
      if (!_isInitialized) {
        // تعيين علامة لمنع استعادة الحالة السابقة
        _preventStateRestoration = true; // هذا سيمنع استعادة الحالة السابقة
        await _initAudioService();
      }

      if (index != null) {
        print('🎵 Play called with index: $index, title: $title');

        // إيقاف التشغيل الحالي فورًا
        await _audioPlayer.stop();

        // إضافة تأخير صغير
        await Future.delayed(Duration(milliseconds: 200));

        // التحقق من صحة المؤشر
        if (index < 0 || index >= _playlist.length) {
          print(
              '⚠️ Invalid index in play: $index, playlist length: ${_playlist.length}');

          // إذا كان العنوان موجودًا في القائمة، نبحث عن الفهرس الصحيح
          if (title != null && _titles.contains(title)) {
            int correctIndex = _titles.indexOf(title);
            print('🔍 Found correct index for "$title": $correctIndex');
            index = correctIndex;
          } else {
            print('❌ Cannot play: invalid index and title not found');
            isLoadingNotifier.value = false;
            _isPlayAttemptInProgress = false;
            return;
          }
        }

        // تحديث المؤشر الحالي والعنوان مباشرة
        currentIndexNotifier.value = index;
        currentTitleNotifier.value = title ?? _titles[index];

        // Find the onHymnChangedCallback and call it when a hymn starts playing
        if (_onHymnChangedCallback != null && index != null) {
          // استدعاء callback لزيادة عدد المشاهدات عند بدء تشغيل ترنيمة
          // إضافة تأخير صغير لتجنب التكرار مع استدعاءات أخرى
          Future.delayed(Duration(milliseconds: 300), () {
            if (!_isDisposed) {
              // التحقق مما إذا كانت نفس الترنيمة قد تم زيادة عدد مشاهداتها مؤخرًا
              if (index == null) {
                print('⚠️ لا يمكن استدعاء callback: index هو قيمة فارغة');
                return;
              }

              String currentHymnId = title ?? _titles[index];
              DateTime now = DateTime.now();

              // إذا كانت نفس الترنيمة وتم زيادة عدادها خلال الـ 30 ثانية الماضية، نتجاهل الطلب
              if (currentHymnId == _lastIncrementedHymnId &&
                  _lastIncrementTime != null &&
                  now.difference(_lastIncrementTime!).inSeconds < 30) {
                print(
                    '⚠️ تم تجاهل زيادة عدد المشاهدات لنفس الترنيمة خلال 30 ثانية: $currentHymnId');
                return;
              }

              _onHymnChangedCallback!(index, currentHymnId);
              print(
                  '📊 تم استدعاء callback لزيادة عدد المشاهدات للترنيمة: $currentHymnId');

              // تحديث متغيرات التتبع
              _lastIncrementedHymnId = currentHymnId;
              _lastIncrementTime = now;
            }
          });

          // الحصول على URL للترنيمة
          String url = _playlist[index];

          // تنظيف URL وإصلاحها إذا لزم الأمر
          url = _sanitizeUrl(url);

          print('🔍 URL بعد التنظيف: $url');

          // إعادة تعيين متغير بدء التشغيل
          _playbackStarted = false;

          // محاولة تشغيل الترنيمة من الكاش أولاً إذا كانت متاحة
          final cachedPath = await _getCachedFile(url);
          if (cachedPath != null) {
            try {
              print('🎵 تشغيل الترنيمة من الكاش: $cachedPath');
              final fileSource = AudioSource.uri(Uri.file(cachedPath));
              await _audioPlayer.setAudioSource(fileSource, preload: true);
              // بدء التشغيل فورًا
              await _audioPlayer.play();
              print('✅ تم تشغيل الترنيمة من الكاش بنجاح');
            } catch (e) {
              print('❌ فشل التشغيل من الكاش: $e');
              // إذا فشل التشغيل من الكاش، استخدم الطريقة العادية
              await _playFromUrl(url);
            }
          } else {
            // إذا كانت الترنيمة غير متاحة في الكاش، استخدم الطريقة العادية
            await _playFromUrl(url);
          }

          // حفظ الحالة في الخلفية
          _saveCurrentState();

          print('Playback started successfully');
        }
      } else {
        // استئناف التشغيل
        await _audioPlayer.play();
        print('▶️ تم استئناف التشغيل');
      }
    } catch (e) {
      print('❌ خطأ أثناء التشغيل: $e');
      isLoadingNotifier.value = false;

      // معالجة PlatformException بشكل خاص
      if (e is PlatformException && e.code == 'abort') {
        print('⚠️ تم قطع التحميل، محاولة استعادة الحالة...');
        await _recoverFromLoadingInterruption();
      } else {
        // محاولة التعافي من الخطأ
        _handlePlaybackError();
      }
    } finally {
      // إعادة تعيين متغير محاولة التشغيل
      _isPlayAttemptInProgress = false;

      // لا نقوم بإخفاء مؤشر التحميل هنا، سيتم إخفاؤه عند بدء التشغيل فعلياً
      // من خلال مراقب حالة التشغيل
    }
  }

  // تعديل دالة _playFromUrl لتبدأ التشغيل فوراً وتستمر بالتحميل في الخلفية
  // تحسين دالة _playFromUrl لتسريع بدء التشغيل
  Future<void> _playFromUrl(String url) async {
    try {
      print('🎵 تشغيل الترنيمة من URL: $url');

      // إظهار مؤشر التحميل
      isLoadingNotifier.value = true;
      downloadProgressNotifier.value = 0.0;

      // تحقق إذا كان الملف موجود في الكاش المؤقت (RAM)
      if (_cachedFiles.containsKey(url)) {
        final cachedPath = _cachedFiles[url];
        if (cachedPath != null) {
          final file = File(cachedPath);
          if (await file.exists()) {
            print('🎵 استخدام الملف المخزن مؤقتاً من الذاكرة: $cachedPath');
            final fileSource = AudioSource.uri(Uri.file(cachedPath));
            await _audioPlayer.setAudioSource(fileSource, preload: true);
            await _audioPlayer.play();
            return;
          }
        }
      }

      // محاولة تشغيل الملف مباشرة من الإنترنت مع تحميل مسبق محدود
      try {
        // استخدام preload: false للبدء بالتشغيل فوراً مع استمرار التحميل
        final audioSource = AudioSource.uri(Uri.parse(url));
        await _audioPlayer.setAudioSource(audioSource, preload: false);

        // بدء التشغيل فوراً
        await _audioPlayer.play();

        // تخزين الملف في الخلفية للاستخدام المستقبلي
        _cacheFileInBackground(url);

        print('✅ تم بدء تشغيل الترنيمة مباشرة مع استمرار التحميل في الخلفية');
        return;
      } catch (e) {
        print('❌ فشل التشغيل المباشر: $e');

        // محاولة تنزيل جزء من الملف أولاً ثم التشغيل
        final tempFile = await _downloadToTempFile(url, highPriority: true);
        if (tempFile != null) {
          final fileSource = AudioSource.uri(Uri.file(tempFile));
          await _audioPlayer.setAudioSource(fileSource, preload: false);
          await _audioPlayer.play();

          print('✅ تم تشغيل الترنيمة من الملف المؤقت بنجاح');
          return;
        }
      }

      // محاولة أخيرة باستخدام setUrl مباشرة
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();

      print('✅ تم تشغيل الترنيمة باستخدام setUrl بنجاح');
    } catch (e) {
      print('❌ فشلت جميع محاولات التشغيل: $e');
      isLoadingNotifier.value = false;
      downloadProgressNotifier.value = 0.0;

      // تسجيل URL كفاشلة
      _failedUrls[url] = DateTime.now();

      // محاولة التعافي من الخطأ
      _handlePlaybackError();
    }
  }

  // تعديل دالة playFromBeginning لتحديث واجهة المستخدم فوراً وإظهار مؤشر تحميل أفضل
  Future<void> playFromBeginning(int index, String title) async {
    if (_isDisposed) return;

    // إظهار مؤشر التحميل فوراً
    isLoadingNotifier.value = true;
    downloadProgressNotifier.value = 0.0;

    try {
      print('🎵 playFromBeginning called for index: $index, title: $title');

      // التحقق من صحة المؤشر
      if (index < 0 || index >= _playlist.length) {
        print('⚠️ Invalid index: $index, playlist length: ${_playlist.length}');

        // إذا كان العنوان موجودًا في القائمة، نبحث عن الفهرس الصحيح
        if (_titles.contains(title)) {
          int correctIndex = _titles.indexOf(title);
          print('🔍 Found correct index for "$title": $correctIndex');
          index = correctIndex;
        } else {
          print('❌ Title not found in playlist, cannot play');
          isLoadingNotifier.value = false;
          return;
        }
      }

      // تحديث المؤشرات مباشرة - هذا مهم لتحديث واجهة المستخدم فوراً
      currentIndexNotifier.value = index;
      currentTitleNotifier.value = title;

      // إعادة تعيين متغير بدء التشغيل
      _playbackStarted = false;

      // الحصول على URL للترنيمة
      String url = _playlist[index];

      // تنظيف URL وإصلاحها إذا لزم الأمر
      url = _sanitizeUrl(url);

      print('🔍 URL for hymn: $url');

      // إيقاف التشغيل الحالي
      await _audioPlayer.stop();
      print('⏹️ Stopped current playback');

      // إضافة تأخير صغير
      await Future.delayed(Duration(milliseconds: 200));

      // محاولة تشغيل الترنيمة مباشرة
      try {
        // محاولة تنزيل الملف مباشرة إلى ملف مؤقت أولاً
        final tempFile = await _downloadToTempFile(url, highPriority: true);

        if (tempFile != null) {
          print('🔄 Using temporary file: $tempFile');
          final fileSource = AudioSource.uri(Uri.file(tempFile));
          await _audioPlayer.setAudioSource(fileSource, preload: true);
          await _audioPlayer.play();
          print('▶️ Started playback from temp file successfully');
          return;
        }

        print('🔄 Setting audio source directly');
        final audioSource = AudioSource.uri(Uri.parse(url));
        await _audioPlayer.setAudioSource(audioSource, preload: true);
        await _audioPlayer.play();
        print('▶️ Started playback successfully');
      } catch (e) {
        print('❌ Error setting audio source: $e');

        // محاولة بديلة باستخدام setUrl
        try {
          print('🔄 Trying alternative method: setUrl');
          await _audioPlayer.setUrl(url);
          await _audioPlayer.play();
          print('▶️ Started playback using setUrl');
        } catch (e2) {
          print('❌ All playback methods failed: $e2');

          // تسجيل URL كفاشلة
          _failedUrls[url] = DateTime.now();

          // محاولة أخيرة باستخدام طريقة مختلفة
          try {
            print('🔄 Trying final fallback method');
            // استخدام طريقة مختلفة للتشغيل
            await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)),
                preload: false);
            await Future.delayed(Duration(milliseconds: 300));
            await _audioPlayer.play();
            print('▶️ Started playback using final fallback method');
          } catch (e3) {
            print('❌ All methods failed: $e3');
            isLoadingNotifier.value = false;
            throw e3;
          }
        }
      }

      // تخزين الملف في الخلفية للاستخدام المستقبلي
      _cacheFileInBackground(url);

      // حفظ الحالة في الخلفية
      _saveCurrentState();

      print('✅ playFromBeginning completed successfully');
    } catch (e) {
      print('❌ Error in playFromBeginning: $e');
      isLoadingNotifier.value = false;

      // محاولة التعافي من الخطأ
      _handlePlaybackError();

      // إعادة رمي الخطأ للمعالجة في المستدعي
      throw e;
    }
  }

  Future<String?> _getCachedFile(String url) async {
    try {
      // Check in-memory cache first (fastest)
      if (_cachedFiles.containsKey(url)) {
        final cachedPath = _cachedFiles[url];
        if (cachedPath != null) {
          final file = File(cachedPath);
          if (await file.exists()) {
            print('Found file in memory cache: $cachedPath');
            return cachedPath;
          } else {
            // Remove invalid path from memory
            _cachedFiles.remove(url);
          }
        }
      }

      // Try to get file from disk cache
      try {
        final fileInfo = await _cacheManager.getFileFromCache(url);

        if (fileInfo != null) {
          // Store path in memory for faster access in future
          _cachedFiles[url] = fileInfo.file.path;
          print('Found file in disk cache: ${fileInfo.file.path}');
          return fileInfo.file.path;
        }
      } catch (e) {
        print('Error accessing cache: $e');
      }

      return null;
    } catch (e) {
      print('Error looking for cached file: $e');
      return null;
    }
  }

  // تعديل دالة _cacheFileInBackground لتحسين آلية التخزين المؤقت
  // تحسين دالة _cacheFileInBackground لتحسين آلية التخزين المؤقت
  void _cacheFileInBackground(String url) {
    if (_isDisposed) return;

    // تأخير تحميل الملف في الخلفية لتجنب التنافس على الموارد
    Future.delayed(Duration(milliseconds: 300), () async {
      if (_isDisposed) return;

      try {
        // التحقق مما إذا كان الملف موجودًا بالفعل في الذاكرة المؤقتة
        final fileInfo = await _cacheManager.getFileFromCache(url);
        if (fileInfo != null) {
          _cachedFiles[url] = fileInfo.file.path;
          return;
        }

        // محاولة تنزيل الملف مباشرة إلى ملف مؤقت
        final tempFile = await _downloadToTempFile(url);
        if (tempFile != null) {
          print('✅ تم تنزيل الملف مباشرة إلى: $tempFile');
          return;
        }

        // تحميل الملف بشكل تدريجي
        final fileInfo2 = await _cacheManager.downloadFile(
          url,
          key: url,
        );

        _cachedFiles[url] = fileInfo2.file.path;
        print('✅ تم تخزين الملف في الذاكرة المؤقتة: $url');
      } catch (e) {
        print('❌ خطأ في تخزين الملف في الذاكرة المؤقتة: $e');
      }
    });
  }

  Future<void> prepareHymnAtPosition(
      int index, String title, Duration position) async {
    if (_isDisposed) return;

    if (index < 0 || index >= _playlist.length) {
      print('Invalid index in prepareHymnAtPosition: $index');
      return;
    }

    try {
      print(
          'Preparing hymn: $title at index $index at position: ${position.inSeconds} seconds');

      // Update index and title
      currentIndexNotifier.value = index;
      currentTitleNotifier.value = title;

      // Set restoration flag to prevent progress bar updates during restoration
      _isRestoringPosition = true;

      // إضافة مؤقت لإعادة تعيين علامة الاستعادة بعد فترة قصيرة
      Future.delayed(Duration(milliseconds: 1000), () {
        if (!_isDisposed && _isRestoringPosition) {
          _isRestoringPosition = false;
          print('⚠️ إعادة تعيين علامة استعادة الموضع بعد انتهاء المهلة');
        }
      });

      // Update position directly in ValueNotifier to avoid flicker
      positionNotifier.value = position;

      // توقف أي تشغيل حالي
      await _audioPlayer.stop();

      // محاولة تحضير الملف بطرق مختلفة
      try {
        // محاولة تحميل الملف من الكاش أولاً
        String url = _playlist[index];

        // تنظيف URL وإصلاحها إذا لزم الأمر
        url = _sanitizeUrl(url);

        final cachedPath = await _getCachedFile(url);

        if (cachedPath != null) {
          // استخدام الملف المخزن مؤقتًا
          await _audioPlayer.setAudioSource(
            AudioSource.uri(Uri.file(cachedPath)),
            initialPosition: position,
            preload: true,
          );

          // مسح علامة الاستعادة بعد الإعداد
          _isRestoringPosition = false;
          print('✅ تم تحضير الترنيمة من الكاش بنجاح');
          return;
        }

        // محاولة تنزيل الملف مباشرة
        final tempFile = await _downloadToTempFile(url, highPriority: true);
        if (tempFile != null) {
          // استخدام الملف المؤقت
          await _audioPlayer.setAudioSource(
            AudioSource.uri(Uri.file(tempFile)),
            initialPosition: position,
            preload: true,
          );

          // مسح علامة الاستعادة بعد الإعداد
          _isRestoringPosition = false;
          print('✅ تم تحضير الترنيمة من الملف المؤقت بنجاح');
          return;
        }

        // استخدام URL مباشرة
        await _audioPlayer.setAudioSource(
          AudioSource.uri(Uri.parse(url)),
          initialPosition: position,
          preload: true,
        );
      } catch (e) {
        print('Error in primary preparation method: $e');

        // معالجة PlatformException بشكل خاص
        if (e is PlatformException && e.code == 'abort') {
          print('⚠️ تم قطع التحميل، محاولة استعادة الحالة...');
          await _recoverFromLoadingInterruption();
          _isRestoringPosition = false;
          return;
        }

        // محاولة ثانية باستخدام الملف المخزن مؤقتًا
        final cachedPath = await _getCachedFile(_playlist[index]);
        if (cachedPath != null) {
          await _audioPlayer.setAudioSource(
            AudioSource.uri(Uri.file(cachedPath)),
            initialPosition: position,
            preload: true,
          );
        } else {
          // محاولة ثالثة باستخدام setUrl مباشرة
          await _audioPlayer.setUrl(_playlist[index]);
          await _audioPlayer.seek(position);
        }
      }

      // مسح علامة الاستعادة بعد الإعداد
      _isRestoringPosition = false;

      print('Hymn prepared at specified position successfully');
    } catch (e) {
      _isRestoringPosition = false;
      print('Error preparing hymn at position: $e');

      // معالجة PlatformException بشكل خاص
      if (e is PlatformException && e.code == 'abort') {
        print('⚠️ تم قطع التحميل، محاولة استعادة الحالة...');
        await _recoverFromLoadingInterruption();
        return;
      }

      // طريقة احتياطية - محاولة أخيرة
      try {
        print('Trying final fallback preparation...');
        await _audioPlayer.setUrl(_playlist[index]);
        await _audioPlayer.seek(position);
        print('Final fallback preparation succeeded');
      } catch (e2) {
        print('All preparation methods failed: $e2');
        // تشغيل آلية التعافي من الخطأ
        _handlePlaybackError();
      }
    }
  }

  Future<void> togglePlayPause() async {
    if (_isDisposed) return;

    print('Toggle play/pause called');

    // منع التبديل إذا كان هناك عملية تغيير مسار جارية
    if (_isChangingTrack) {
      print('⚠️ جاري تغيير المسار، تجاهل طلب التبديل');
      return;
    }

    try {
      if (_audioPlayer.playing) {
        print('Pausing playback');
        await _audioPlayer.pause();
      } else {
        // If there's an audio source already set, play directly
        if (_audioPlayer.audioSource != null) {
          print('Resuming playback of current source');
          await _audioPlayer.play();
        }
        // If no audio source, try to restore last hymn
        else if (_playlist.isNotEmpty &&
            currentIndexNotifier.value >= 0 &&
            currentIndexNotifier.value < _playlist.length &&
            currentTitleNotifier.value != null) {
          print(
              'Restoring last hymn: ${currentTitleNotifier.value} at index ${currentIndexNotifier.value}');

          // محاولة تحميل الملف من الكاش أولاً
          final url = _playlist[currentIndexNotifier.value];
          final cachedPath = await _getCachedFile(url);

          if (cachedPath != null) {
            // استخدام الملف المخزن مؤقتًا
            await _audioPlayer.setAudioSource(
              AudioSource.uri(Uri.file(cachedPath)),
            );
          } else {
            // استخدام URL مباشرة
            await _audioPlayer.setAudioSource(
              AudioSource.uri(Uri.parse(url)),
            );
          }

          // استعادة آخر موضع
          final userId = _getCurrentUserId();
          final prefs = await SharedPreferences.getInstance();
          final lastPosition = prefs.getInt('lastPosition_$userId') ?? 0;

          if (lastPosition > 0) {
            await _audioPlayer.seek(Duration(seconds: lastPosition));
            print('Restored last position: $lastPosition seconds');
          }

          await _audioPlayer.play();
        } else {
          print('Cannot play: no audio source or insufficient information');

          // إذا كانت قائمة التشغيل غير فارغة، حاول تشغيل الترنيمة الأولى
          if (_playlist.isNotEmpty && _titles.isNotEmpty) {
            print('Trying to play first hymn in playlist as last resort');

            await _audioPlayer.setAudioSource(
              AudioSource.uri(Uri.parse(_playlist[0])),
            );

            currentIndexNotifier.value = 0;
            currentTitleNotifier.value = _titles[0];
            await _audioPlayer.play();
          }
        }
      }

      // حفظ الحالة بعد التبديل
      await _saveCurrentState();
      print('Toggle play/pause completed');
    } catch (e) {
      print('Error in togglePlayPause: $e');

      // معالجة PlatformException بشكل خاص
      if (e is PlatformException && e.code == 'abort') {
        print('⚠️ تم قطع التحميل، محاولة استعادة الحالة...');
        await _recoverFromLoadingInterruption();
      } else {
        // محاولة التعافي من الخطأ
        _handlePlaybackError();
      }
    }
  }

  // دالة لإيقاف التشغيل مؤقتاً (للاستخدام الخارجي)
  Future<void> pause() async {
    if (_isDisposed) return;

    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
      print('⏸️ تم إيقاف التشغيل مؤقتاً من خلال دالة pause()');
    }
  }

  // دالة لاستئناف التشغيل (للاستخدام الخارجي)
  Future<void> resume() async {
    if (_isDisposed) return;

    if (!_audioPlayer.playing &&
        _audioPlayer.processingState != ProcessingState.idle) {
      await _audioPlayer.play();
      print('▶️ تم استئناف التغيل من خلال دالة resume()');
    }
  }

  // تعديل دالة stop لمنع إيقاف التشغيل أثناء التنقل
  Future<void> stop() async {
    if (_isDisposed) return;

    // فقط إيقاف التشغيل إذا كنا لا نمنع الإيقاف أثناء التنقل
    if (!_preventStopDuringNavigation || !_isNavigating) {
      await _audioPlayer.stop();
      print('⏹️ تم إيقاف التشغيل من خلال دالة stop()');
    } else {
      // فقط إيقاف مؤقت بدلاً من الإيقاف الكامل
      print('تم تجاهل طلب الإيقاف بسبب _preventStopDuringNavigation = true');
      await pause();

      // حفظ حالة التشغيل لاستئنافها لاحقاً
      _wasPlayingBeforeInterruption = true;
    }
  }

  Future<void> seek(Duration position) async {
    if (_isDisposed) return;

    try {
      // تحديث الموضع مباشرة في ValueNotifier لتجنب التأخير في واجهة المستخدم
      positionNotifier.value = position;

      // تعيين علامة الاستعادة لفترة قصيرة فقط
      _isRestoringPosition = true;

      // الانتقال إلى الموضع المطلوب
      await _audioPlayer.seek(position);

      // إعادة تعيين علامة الاستعادة بعد فترة قصيرة
      Future.delayed(Duration(milliseconds: 200), () {
        if (!_isDisposed) {
          _isRestoringPosition = false;
        }
      });
    } catch (e) {
      print('❌ خطأ في الانتقال إلى الموضع: $e');
      _isRestoringPosition = false; // تأكد من إعادة تعيين العلامة في حالة الخطأ
    }
  }

  // تعديل دالة playNext لزيادة عدد المشاهدات عند الانتقال للترنيمة التالية
  Future<void> playNext() async {
    if (_isDisposed || _playlist.isEmpty) return;

    // منع التشغيل إذا كان هناك عملية تغيير مسار جارية
    if (_isChangingTrack) {
      print('⚠️ جاري تغيير المسار، تجاهل طلب التشغيل التالي');
      return;
    }

    _isChangingTrack = true;
    isLoadingNotifier.value = true; // إظهار مؤشر التحميل فوراً
    print('⏭️ تشغيل الترنيمة التالية');

    try {
      int nextIndex;
      // التحقق مما إذا كان هناك ترنيمة حالية
      if (currentTitleNotifier.value == null ||
          currentIndexNotifier.value < 0) {
        print('⚠️ لا توجد ترنيمة حالية، استخدام المؤشر 0');
        nextIndex = 0;
      }
      // إذا تم تفعيل وضع العشوائي
      else if (isShufflingNotifier.value) {
        nextIndex = _getRandomIndex();
        print('🔀 اختيار ترنيمة عشوائية: $nextIndex');
      }
      // الانتقال إلى الترنيمة التالية في قائمة التشغيل نفسها
      else {
        nextIndex = (currentIndexNotifier.value + 1) % _playlist.length;
        print(
            '➡️ الانتقال إلى الترنيمة التالية في القائمة: $nextIndex (من إجمالي: ${_playlist.length})');
      }

      // التحقق من صحة الفهرس
      if (nextIndex < 0 || nextIndex >= _playlist.length) {
        print('⚠️ فهرس غير صالح: $nextIndex، طول القائمة: ${_playlist.length}');
        nextIndex = 0; // استخدام الفهرس الأول كحل بديل
      }

      // إيقاف التشغيل الحالي أولاً
      await stop();

      // إضافة تأخير صغير للتأكد من توقف التشغيل بالكامل
      await Future.delayed(Duration(milliseconds: 300));

      // تحديث المؤشر الحالي قبل التشغيل
      currentIndexNotifier.value = nextIndex;

      // استدعاء الـ callback لزيادة عدد المشاهدات قبل تشغيل الترنيمة التالية
      // نتحقق إذا كانت الـ callback غير فارغة وأن الفهرس صحيح
      if (_onHymnChangedCallback != null &&
          nextIndex >= 0 &&
          nextIndex < _titles.length) {
        String nextTitle = _titles[nextIndex];

        // التحقق مما إذا كانت نفس الترنيمة قد تم زيادة عدد مشاهداتها مؤخرًا
        DateTime now = DateTime.now();
        if (nextTitle == _lastIncrementedHymnId &&
            _lastIncrementTime != null &&
            now.difference(_lastIncrementTime!).inSeconds < 30) {
          print(
              '⚠️ تم تجاهل زيادة عدد المشاهدات لنفس الترنيمة خلال 30 ثانية: $nextTitle');
        } else {
          print(
              '📊 استدعاء callback لزيادة عدد المشاهدات للترنيمة التالية: $nextTitle');
          _onHymnChangedCallback!(nextIndex, nextTitle);

          // تحديث متغيرات التتبع
          _lastIncrementedHymnId = nextTitle;
          _lastIncrementTime = now;
        }
      } else {
        print(
            '⚠️ لا يمكن استدعاء الـ callback: ${_onHymnChangedCallback == null ? "الـ callback فارغة" : "الفهرس خارج النطاق"}');
      }

      // استخدام playFromBeginning للتشغيل الفوري
      String nextTitle = _titles[nextIndex];
      print('🎵 تشغيل الترنيمة التالية: $nextTitle (فهرس: $nextIndex)');

      await playFromBeginning(nextIndex, nextTitle);

      // مهم: لا نستدعي الـ callback مرة ثانية هنا، فقد تم استدعاؤها بالفعل

      print('✅ تم تشغيل الترنيمة التالية بنجاح');
    } catch (e) {
      print('❌ خطأ في تشغيل الترنيمة التالية: $e');
      isLoadingNotifier.value = false;
    } finally {
      // إعادة تعيين علامة تغيير المسار
      Future.delayed(Duration(milliseconds: 500), () {
        _isChangingTrack = false;
      });
    }
  }

  // تعديل دالة playPrevious لزيادة عدد المشاهدات
  Future<void> playPrevious() async {
    if (_isDisposed || _playlist.isEmpty) return;

    // منع التشغيل إذا كان هناك عملية تغيير مسار جارية
    if (_isChangingTrack) {
      print('⚠️ جاري تغيير المسار، تجاهل طلب التشغيل السابق');
      return;
    }

    _isChangingTrack = true;
    isLoadingNotifier.value = true; // إظهار مؤشر التحميل فوراً
    print('⏮️ تشغيل الترنيمة السابقة');

    try {
      int prevIndex;
      // التحقق مما إذا كان هناك ترنيمة حالية
      if (currentTitleNotifier.value == null ||
          currentIndexNotifier.value < 0) {
        print('⚠️ لا توجد ترنيمة حالية، استخدام المؤشر 0');
        prevIndex = 0;
      }
      // إذا تم تفعيل وضع العشوائي
      else if (isShufflingNotifier.value) {
        prevIndex = _getRandomIndex();
        print('🔀 اختيار ترنيمة عشوائية: $prevIndex');
      }
      // الانتقال إلى الترنيمة السابقة في قائمة التشغيل نفسها
      else {
        prevIndex = (currentIndexNotifier.value - 1 + _playlist.length) %
            _playlist.length;
        print(
            '⬅️ الانتقال إلى الترنيمة السابقة في القائمة: $prevIndex (من إجمالي: ${_playlist.length})');
      }

      // التحقق من صحة الفهرس
      if (prevIndex < 0 || prevIndex >= _playlist.length) {
        print('⚠️ فهرس غير صالح: $prevIndex، طول القائمة: ${_playlist.length}');
        prevIndex = 0; // استخدام الفهرس الأول كحل بديل
      }

      // إيقاف التشغيل الحالي أولاً
      await stop();

      // إضافة تأخير صغير للتأكد من توقف التشغيل بالكامل
      await Future.delayed(Duration(milliseconds: 300));

      // تحديث المؤشر الحالي قبل التشغيل
      currentIndexNotifier.value = prevIndex;

      // استدعاء الـ callback لزيادة عدد المشاهدات قبل تشغيل الترنيمة السابقة
      // نتحقق إذا كانت الـ callback غير فارغة وأن الفهرس صحيح
      if (_onHymnChangedCallback != null &&
          prevIndex >= 0 &&
          prevIndex < _titles.length) {
        String prevTitle = _titles[prevIndex];

        // التحقق مما إذا كانت نفس الترنيمة قد تم زيادة عدد مشاهداتها مؤخرًا
        DateTime now = DateTime.now();
        if (prevTitle == _lastIncrementedHymnId &&
            _lastIncrementTime != null &&
            now.difference(_lastIncrementTime!).inSeconds < 30) {
          print(
              '⚠️ تم تجاهل زيادة عدد المشاهدات لنفس الترنيمة خلال 30 ثانية: $prevTitle');
        } else {
          print(
              '📊 استدعاء callback لزيادة عدد المشاهدات للترنيمة السابقة: $prevTitle');
          _onHymnChangedCallback!(prevIndex, prevTitle);

          // تحديث متغيرات التتبع
          _lastIncrementedHymnId = prevTitle;
          _lastIncrementTime = now;
        }
      } else {
        print(
            '⚠️ لا يمكن استدعاء الـ callback: ${_onHymnChangedCallback == null ? "الـ callback فارغة" : "الفهرس خارج النطاق"}');
      }

      // استخدام playFromBeginning للتشغيل الفوري
      String prevTitle = _titles[prevIndex];
      print('🎵 تشغيل الترنيمة السابقة: $prevTitle (فهرس: $prevIndex)');

      await playFromBeginning(prevIndex, prevTitle);

      // مهم: لا نستدعي الـ callback مرة ثانية هنا، فقد تم استدعاؤها بالفعل

      print('✅ تم تشغيل الترنيمة السابقة بنجاح');
    } catch (e) {
      print('❌ خطأ في تشغيل الترنيمة السابقة: $e');
      isLoadingNotifier.value = false;
    } finally {
      // إعادة تعيين علامة تغيير المسار
      Future.delayed(Duration(milliseconds: 500), () {
        _isChangingTrack = false;
      });
    }
  }

  int _getRandomIndex() {
    if (_playlist.length <= 1) return 0;

    // Choose a random index different from current index
    int randomIndex;
    do {
      randomIndex =
          (DateTime.now().millisecondsSinceEpoch % _playlist.length).toInt();
    } while (randomIndex == currentIndexNotifier.value);

    return randomIndex;
  }

  Future<void> toggleShuffle() async {
    if (_isDisposed) return;

    isShufflingNotifier.value = !isShufflingNotifier.value;
    await _saveCurrentState();
  }

  Future<void> toggleRepeat() async {
    if (_isDisposed) return;

    // Cycle repeat mode: 0 (off) -> 1 (one) -> 2 (all) -> 0 ...
    repeatModeNotifier.value = (repeatModeNotifier.value + 1) % 3;
    await _saveCurrentState();
  }

  Future<void> _saveCurrentState() async {
    if (_isDisposed) return;

    try {
      final userId = _getCurrentUserId();
      final prefs = await SharedPreferences.getInstance();

      // Save current title and index
      if (currentTitleNotifier.value != null) {
        await prefs.setString(
            'lastPlayedTitle_$userId', currentTitleNotifier.value!);
      }
      await prefs.setInt('lastPlayedIndex_$userId', currentIndexNotifier.value);

      // Save current position
      final currentPosition = positionNotifier.value.inSeconds;
      await prefs.setInt('lastPosition_$userId', currentPosition);
      print('Saved current position: $currentPosition seconds');

      // Save playback state
      await prefs.setBool('wasPlaying_$userId', isPlayingNotifier.value);

      // Save playlist and titles
      await prefs.setStringList('lastPlaylist_$userId', _playlist);
      await prefs.setStringList('lastTitles_$userId', _titles);

      // حفظ روابط صور الترانيم (مع التعامل مع القيم الفارغة)
      final artworkUrlsToSave = _artworkUrls.map((url) => url ?? '').toList();
      await prefs.setStringList('lastArtworkUrls_$userId', artworkUrlsToSave);

      // Save repeat and shuffle modes
      await prefs.setInt('repeatMode_$userId', repeatModeNotifier.value);
      await prefs.setBool('isShuffling_$userId', isShufflingNotifier.value);

      print('Saved playback state successfully');
    } catch (e) {
      print('Error saving playback state: $e');
    }
  }

  Future<void> saveStateOnAppClose() async {
    if (_isDisposed) return;

    print('💾 حفظ الحالة عند إغلاق التطبيق...');

    try {
      // حفظ الموضع الحالي بشكل صريح
      final currentPosition = positionNotifier.value.inSeconds;
      final userId = _getCurrentUserId();
      final prefs = await SharedPreferences.getInstance();

      // حفظ العنوان والفهرس الحاليين
      if (currentTitleNotifier.value != null) {
        await prefs.setString(
            'lastPlayedTitle_$userId', currentTitleNotifier.value!);
        print('💾 تم حفظ العنوان الحالي: ${currentTitleNotifier.value}');
      }
      await prefs.setInt('lastPlayedIndex_$userId', currentIndexNotifier.value);

      // حفظ الموضع الحالي
      await prefs.setInt('lastPosition_$userId', currentPosition);
      print('💾 تم حفظ الموضع عند الإغلاق: $currentPosition ثانية');

      // حفظ حالة التشغيل
      await prefs.setBool('wasPlaying_$userId', isPlayingNotifier.value);
      print(
          '💾 تم حفظ حالة التشغيل: ${isPlayingNotifier.value ? "قيد التشغيل" : "متوقف"}');

      // حفظ قائمة التشغيل والعناوين
      if (_playlist.isNotEmpty && _titles.isNotEmpty) {
        await prefs.setStringList('lastPlaylist_$userId', _playlist);
        await prefs.setStringList('lastTitles_$userId', _titles);
        print('💾 تم حفظ قائمة التشغيل: ${_playlist.length} ترنيمة');

        // حفظ روابط صور الترانيم (مع التعامل مع القيم الفارغة)
        if (_artworkUrls.isNotEmpty) {
          final artworkUrlsToSave =
              _artworkUrls.map((url) => url ?? '').toList();
          await prefs.setStringList(
              'lastArtworkUrls_$userId', artworkUrlsToSave);
        }
      }

      // حفظ وضع التكرار والتشغيل العشوائي
      await prefs.setInt('repeatMode_$userId', repeatModeNotifier.value);
      await prefs.setBool('isShuffling_$userId', isShufflingNotifier.value);

      // حفظ سياق قائمة التشغيل الحالية
      String currentPlaylistType = 'general';
      String? currentPlaylistId;

      // محاولة الحصول على سياق قائمة التشغيل من callbacks
      bool foundContext = false;
      for (var cb in _playlistContextCallbacks) {
        if (cb != null) {
          try {
            var result = cb();
            if (result is List && result.length >= 2) {
              currentPlaylistType = result[0] as String;
              currentPlaylistId = result[1] as String?;
              foundContext = true;
              break;
            }
          } catch (e) {
            print('⚠️ خطأ في استدعاء callback لسياق قائمة التشغيل: $e');
          }
        }
      }

      if (!foundContext) {
        print(
            '⚠️ لم يتم العثور على سياق قائمة التشغيل، استخدام القيم الافتراضية');
      }

      // حفظ سياق قائمة التشغيل
      await prefs.setString('currentPlaylistType_$userId', currentPlaylistType);
      await prefs.setString(
          'currentPlaylistId_$userId', currentPlaylistId ?? '');
      print(
          '💾 تم حفظ سياق قائمة التشغيل: $currentPlaylistType, ${currentPlaylistId ?? "null"}');

      print('✅ تم حفظ حالة التشغيل عند إغلاق التطبيق بنجاح');
    } catch (e) {
      print('❌ خطأ في حفظ حالة التشغيل عند إغلاق التطبيق: $e');
    }
  }

  // تعديل دالة restorePlaybackState للتحكم في التشغيل التلقائي والمعالجة المحسنة
  Future<void> restorePlaybackState() async {
    if (_isDisposed) return;

    if (_resumeTimer != null) {
      _resumeTimer!.cancel();
      _resumeTimer = null;
    }

    try {
      final userId = _getCurrentUserId();
      print('🔄 استعادة حالة التشغيل للمستخدم: $userId');
      final prefs = await SharedPreferences.getInstance();

      // استعادة وضع التكرار والتشغيل العشوائي
      repeatModeNotifier.value = prefs.getInt('repeatMode_$userId') ?? 0;
      isShufflingNotifier.value = prefs.getBool('isShuffling_$userId') ?? false;

      // استعادة سياق قائمة التشغيل
      String savedPlaylistType =
          prefs.getString('currentPlaylistType_$userId') ?? 'general';
      String savedPlaylistId =
          prefs.getString('currentPlaylistId_$userId') ?? '';

      print(
          '🔄 استعادة سياق قائمة التشغيل: $savedPlaylistType, ${savedPlaylistId.isEmpty ? "null" : savedPlaylistId}');

      // استعادة قائمة التشغيل والعناوين
      final lastPlaylist = prefs.getStringList('lastPlaylist_$userId');
      final lastTitles = prefs.getStringList('lastTitles_$userId');

      if (lastPlaylist == null ||
          lastTitles == null ||
          lastPlaylist.isEmpty ||
          lastPlaylist.length != lastTitles.length) {
        print(
            '⚠️ لم يتم العثور على قائمة تشغيل سابقة أو قائمة تشغيل غير صالحة');
        return;
      }

      print('✅ تم استعادة قائمة التشغيل: ${lastPlaylist.length} ترنيمة');
      _playlist = lastPlaylist;
      _titles = lastTitles;

      // استعادة روابط صور الترانيم
      final lastArtworkUrls = prefs.getStringList('lastArtworkUrls_$userId');
      if (lastArtworkUrls != null &&
          lastArtworkUrls.length == lastPlaylist.length) {
        _artworkUrls =
            lastArtworkUrls.map((url) => url.isEmpty ? null : url).toList();
      } else {
        _artworkUrls = List.filled(lastPlaylist.length, null);
      }

      // استعادة آخر ترنيمة تم تشغيلها
      final lastTitle = prefs.getString('lastPlayedTitle_$userId');
      final lastIndex = prefs.getInt('lastPlayedIndex_$userId') ?? 0;
      final lastPosition = prefs.getInt('lastPosition_$userId') ?? 0;
      // استرجاع حالة التشغيل السابقة (كانت قيد التشغيل أم لا)
      final wasPlaying = prefs.getBool('wasPlaying_$userId') ?? false;

      print('🔄 آخر عنوان: $lastTitle');
      print('🔄 آخر فهرس: $lastIndex');
      print('🔄 آخر موضع: $lastPosition ثانية');
      print('🔄 كان قيد التشغيل: $wasPlaying');

      if (lastTitle == null || lastIndex < 0 || lastIndex >= _playlist.length) {
        print('⚠️ معلومات آخر ترنيمة غير صالحة');
        return;
      }

      print('✅ تم العثور على آخر ترنيمة: $lastTitle، فهرس: $lastIndex');

      // تعيين العنوان والفهرس الحاليين
      currentTitleNotifier.value = lastTitle;
      currentIndexNotifier.value = lastIndex;

      // تعيين علامة الاستعادة لمنع تحديثات شريط التقدم أثناء الاستعادة
      _isRestoringPosition = true;

      // تحديث الموضع مباشرة في ValueNotifier لتجنب الوميض
      if (lastPosition > 0) {
        positionNotifier.value = Duration(seconds: lastPosition);
      }

      try {
        print('🔄 إعداد مصدر الصوت: ${_playlist[lastIndex]}');

        // إعداد مصدر الصوت مع الموضع المحفوظ
        await prepareHymnAtPosition(lastIndex, lastTitle,
            lastPosition > 0 ? Duration(seconds: lastPosition) : Duration.zero);

        // مسح علامة الاستعادة بعد الإعداد
        _isRestoringPosition = false;

        // حفظ حالة التشغيل السابقة لاستخدامها في استئناف التشغيل لاحقاً
        _wasPlayingBeforeInterruption = wasPlaying;

        // إذا كانت الترنيمة قيد التشغيل قبل إغلاق التطبيق، قم بتشغيلها تلقائياً
        if (wasPlaying) {
          print('▶️ استئناف التشغيل التلقائي للترنيمة السابقة');
          await Future.delayed(Duration(milliseconds: 500));
          await _audioPlayer.play();
        } else {
          print('⏸️ الترنيمة السابقة كانت متوقفة، لا يتم التشغيل التلقائي');
        }

        print('✅ تم استعادة حالة التشغيل بنجاح');
      } catch (e) {
        _isRestoringPosition = false;
        print('❌ خطأ في إعداد مصدر الصوت: $e');

        // معالجة PlatformException بشكل خاص
        if (e is PlatformException && e.code == 'abort') {
          print('⚠️ تم قطع التحميل، محاولة استعادة الحالة...');
          await _recoverFromLoadingInterruption();
        } else {
          // محاولة التعافي من الخطأ
          _handlePlaybackError();
        }
      }
    } catch (e) {
      _isRestoringPosition = false;
      print('❌ خطأ في استعادة حالة التشغيل: $e');
    }
  }

  // تعديل دالة resumePlaybackAfterNavigation لعمل محاولات متكررة للاستئناف
  Future<void> resumePlaybackAfterNavigation() async {
    if (_isDisposed) return;

    // إلغاء المؤقت السابق إذا كان موجوداً
    if (_resumeTimer != null) {
      _resumeTimer!.cancel();
      _resumeTimer = null;
    }

    // عمل تأشير بأن الانتقال انتهى
    _isNavigating = false;

    // تجنب تنفيذ أي عمليات إذا كان التطبيق يغلق
    if (_isResumeInProgress) {
      print('⚠️ عملية استئناف التشغيل قيد التنفيذ بالفعل');
      return;
    }

    _isResumeInProgress = true;

    try {
      print('🔄 استئناف التشغيل بعد الانتقال...');

      // التحقق مما إذا كان هناك ترنيمة حالية
      if (currentTitleNotifier.value != null && _wasPlayingBeforeInterruption) {
        // إذا كانت الحالة هي ProcessingState.idle فنحاول إعادة تحميل المصدر
        if (_audioPlayer.processingState == ProcessingState.idle) {
          print('🔄 حالة المشغل خاملة، إعادة تحميل المصدر...');

          if (_playlist.isNotEmpty &&
              currentIndexNotifier.value < _playlist.length) {
            try {
              await play(
                  currentIndexNotifier.value, currentTitleNotifier.value);
              _wasPlayingBeforeInterruption = false;
              print('▶️ تم استئناف التشغيل');
            } catch (e) {
              print('❌ خطأ في إعادة تحميل المصدر: $e');

              // معالجة PlatformException بشكل خاص
              if (e is PlatformException && e.code == 'abort') {
                print('⚠️ تم قطع التحميل، محاولة استعادة الحالة...');
                await _recoverFromLoadingInterruption();
              }
            }
          }
        }
        // المشغل جاهز ولكن متوقف ويجب علينا استئنافه
        else if (!_audioPlayer.playing) {
          print('▶️ استئناف التشغيل بعد الانتقال');
          await _audioPlayer.play();
          _wasPlayingBeforeInterruption = false;
        } else {
          print('✅ المشغل في حالة جيدة، لا حاجة للاستئناف');
        }
      } else {
        print('⚠️ لا توجد ترنيمة حالية للاستئناف أو لم تكن قيد التشغيل');
      }
    } catch (e) {
      print('❌ خطأ في استئناف التشغيل بعد الانتقال: $e');

      // معالجة PlatformException بشكل خاص
      if (e is PlatformException && e.code == 'abort') {
        print('⚠️ تم قطع التحميل، محاولة استعادة الحالة...');
        await _recoverFromLoadingInterruption();
      }
    } finally {
      _isResumeInProgress = false;
    }
  }

  // إضافة دالة لحفظ حالة التشغيل قبل المقاطعة
  void savePlaybackState() {
    if (_isDisposed) return;

    _wasPlayingBeforeInterruption = isPlayingNotifier.value;
    print(
        '💾 تم حفظ حالة التشغيل: ${_wasPlayingBeforeInterruption ? 'قيد التشغيل' : 'متوقف'}');
  }

  // إضافة دالة للإشارة إلى بداية الانتقال
  void startNavigation() {
    if (_isDisposed) return;

    _isNavigating = true;
    savePlaybackState();
    print('🔄 بدء الانتقال بين الشاشات...');
  }

  // إضافة دالة للتحكم في منع الإيقاف أثناء التنقل
  void setPreventStopDuringNavigation(bool prevent) {
    if (_isDisposed) return;

    _preventStopDuringNavigation = prevent;
    print('🔄 تم تعيين منع الإيقاف أثناء التنقل إلى: $prevent');
  }

  // دالة للتحكم في منع استعادة الحالة
  void setPreventStateRestoration(bool prevent) {
    _preventStateRestoration = prevent;
    print('🔄 تم تعيين منع استعادة الحالة إلى: $prevent');
  }

  // دالة لمسح بيانات المستخدم عند تسجيل الخروج
  Future<void> clearUserData() async {
    if (_isDisposed) return;

    try {
      print('🧹 جاري مسح بيانات المستخدم...');

      // إيقاف التشغيل الحالي
      await stop();

      // مسح قائمة التشغيل الحالية
      _playlist = [];
      _titles = [];
      _artworkUrls = [];

      // إعادة تعيين المؤشرات
      currentIndexNotifier.value = 0;
      currentTitleNotifier.value = null;
      positionNotifier.value = Duration.zero;
      durationNotifier.value = null;

      // مسح الحالة المحفوظة
      final prefs = await SharedPreferences.getInstance();
      final userId = _getCurrentUserId();

      // مسح بيانات المستخدم السابق
      await prefs.remove('lastPlayedTitle_$userId');
      await prefs.remove('lastPlayedIndex_$userId');
      await prefs.remove('lastPosition_$userId');
      await prefs.remove('wasPlaying_$userId');
      await prefs.remove('lastPlaylist_$userId');
      await prefs.remove('lastTitles_$userId');
      await prefs.remove('lastArtworkUrls_$userId');
      await prefs.remove('repeatMode_$userId');
      await prefs.remove('isShuffling_$userId');
      await prefs.remove('currentPlaylistType_$userId');
      await prefs.remove('currentPlaylistId_$userId');

      print('✅ تم مسح بيانات المستخدم بنجاح');
    } catch (e) {
      print('❌ خطأ في مسح بيانات المستخدم: $e');
    }
  }

  // تعديل دالة dispose لضمان تنظيف الموارد بشكل صحيح
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    try {
      print('🧹 تنظيف موارد مشغل الصوت...');

      // إلغاء جميع المؤقتات
      if (_resumeTimer != null) {
        _resumeTimer!.cancel();
        _resumeTimer = null;
      }
      if (_debounceTimer != null) {
        _debounceTimer!.cancel();
        _debounceTimer = null;
      }

      // إلغاء جميع الاشتراكات
      if (_headphoneEventSubscription != null) {
        await _headphoneEventSubscription!.cancel();
        _headphoneEventSubscription = null;
      }

      // حفظ الحالة قبل الإغلاق
      try {
        await saveStateOnAppClose();
      } catch (e) {
        print('⚠️ تم تجاهل خطأ أثناء حفظ الحالة: $e');
      }

      // إيقاف التشغيل وتحرير الموارد بأمان
      try {
        if (_audioPlayer.playing) {
          await _audioPlayer.pause();
        }
        await _audioPlayer.stop();

        // إضافة تأخير قصير قبل التخلص من المشغل (مهم لنظام iOS)
        await Future.delayed(Duration(milliseconds: 300));

        await _audioPlayer.dispose();
      } catch (e) {
        print('⚠️ تم تجاهل خطأ أثناء إيقاف وتحرير المشغل: $e');
      }

      // تنظيف جلسة الصوت
      try {
        if (_audioSession != null) {
          await _audioSession!.setActive(false);
        }
      } catch (e) {
        print('⚠️ تم تجاهل خطأ أثناء تنظيف جلسة الصوت: $e');
      }

      print('✅ تم تنظيف موارد مشغل الصوت بنجاح');
    } catch (e) {
      print('❌ خطأ في تنظيف موارد مشغل الصوت: $e');

      // التعامل مع خطأ PlatformException بشكل خاص
      if (e is PlatformException && e.code == 'recreating_view') {
        print('⚠️ تم تجاهل خطأ recreating_view');
      }
    }
  }

  // إضافة دالة جديدة للتنظيف الدوري للكاش
  Future<void> performPeriodicCacheCleanup() async {
    if (_isDisposed) return;

    try {
      // التحقق من حجم الكاش الحالي
      final tempDir = Directory(_tempDirPath ?? '');
      if (await tempDir.exists()) {
        int totalSize = 0;
        int fileCount = 0;

        // حساب الحجم الإجمالي للملفات المؤقتة
        await for (final entity in tempDir.list()) {
          if (entity is File && entity.path.contains('hymn_')) {
            final stat = await entity.stat();
            totalSize += stat.size;
            fileCount++;
          }
        }

        // إذا تجاوز الحجم 200 ميجابايت، قم بتنظيف الملفات الأقدم
        final sizeInMB = totalSize / (1024 * 1024);
        if (sizeInMB > 200 || fileCount > 100) {
          print(
              '🧹 حجم الكاش الحالي: ${sizeInMB.toStringAsFixed(2)} ميجابايت، عدد الملفات: $fileCount');
          print('🧹 جاري تنظيف الكاش القديم...');

          // احتفظ بالملفات المستخدمة حاليًا
          final currentlyUsedFiles = _cachedFiles.values.toSet();

          // قائمة الملفات
          final files = <FileSystemEntity>[];
          await for (final entity in tempDir.list()) {
            if (entity is File &&
                entity.path.contains('hymn_') &&
                !currentlyUsedFiles.contains(entity.path)) {
              files.add(entity);
            }
          }

          // جمع معلومات الملفات أولاً
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

          // ترتيب القائمة حسب تاريخ التعديل (الأقدم أولاً)
          fileInfoList.sort((a, b) => a['modified'].compareTo(b['modified']));

          // استخراج الملفات المرتبة
          final sortedFiles =
              fileInfoList.map((info) => info['file'] as File).toList();

          // حذف أقدم 50% من الملفات
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

  // دالة مساعدة للحصول على معرف المستخدم الحالي
  String _getCurrentUserId() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return user?.uid ?? 'guest';
    } catch (e) {
      print('⚠️ خطأ في الحصول على معرف المستخدم: $e');
      return 'guest';
    }
  }

  // دالة مساعدة لاستدعاء callback زيادة عدد المشاهدات
  void _onHymnChangedFromAudioService(int index, String title) {
    if (_isDisposed) return;

    // التحقق مما إذا كانت نفس الترنيمة قد تم زيادة عدد مشاهداتها مؤخرًا
    DateTime now = DateTime.now();
    if (title == _lastIncrementedHymnId &&
        _lastIncrementTime != null &&
        now.difference(_lastIncrementTime!).inSeconds < 30) {
      print(
          '⚠️ تم تجاهل زيادة عدد المشاهدات لنفس الترنيمة خلال 30 ثانية: $title');
      return;
    }

    // استدعاء الـ callback إذا كانت موجودة
    if (_onHymnChangedCallback != null) {
      _onHymnChangedCallback!(index, title);
      print('📊 تم استدعاء callback لزيادة عدد المشاهدات للترنيمة: $title');

      // تحديث متغيرات التتبع
      _lastIncrementedHymnId = title;
      _lastIncrementTime = now;
    }
  }

  // إضافة getters للوصول إلى الحالة الحالية
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

  // دالة مساعدة لتنسيق الوقت بشكل مقروء (مثال: 01:23)
  String formatDuration(Duration? duration) {
    if (duration == null) return '00:00';

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  // إزالة دالة preloadPopularHymns أو تحويلها لدالة فارغة مع تعليق مناسب
  // إضافة دالة جديدة لتحميل الترانيم الشائعة مسبقاً
  Future<void> preloadPopularHymns() async {
    if (_isDisposed) return;

    try {
      print('🔄 جاري تحميل الترانيم الشائعة مسبقاً...');

      // الحصول على قائمة الترانيم الشائعة من Firestore
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('hymns')
          .orderBy('views', descending: true)
          .limit(5)
          .get();

      if (snapshot.docs.isEmpty) {
        print('⚠️ لم يتم العثور على ترانيم شائعة');
        return;
      }

      // تحميل الترانيم الشائعة في الخلفية
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final url = data['songUrl'] as String?;

        if (url != null && url.isNotEmpty) {
          // تحميل الملف في الخلفية بأولوية منخفضة
          _downloadToTempFile(url, highPriority: false);
        }
      }

      print('✅ تم بدء تحميل الترانيم الشائعة في الخلفية');
    } catch (e) {
      print('❌ خطأ في تحميل الترانيم الشائعة مسبقاً: $e');
    }
  }

  // تأكد من أن _preloadFirstHymns أيضًا فارغة
  void _preloadFirstHymns() {
    // تم تعطيل التحميل المسبق للترانيم لتوفير استهلاك الإنترنت
    print('🔄 تم تعطيل التحميل المسبق للترانيم لتوفير استهلاك الإنترنت');
  }

  // تأكد من أن _preloadAdjacentHymns أيضًا فارغة
  void _preloadAdjacentHymns(int currentIndex) {
    // تم تعطيل تحميل الترانيم المجاورة مسبقًا لتوفير استهلاك الإنترنت
    // لا يتم فعل أي شيء في هذه الدالة الآن
  }
}

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
