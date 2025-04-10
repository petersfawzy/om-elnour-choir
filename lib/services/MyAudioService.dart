import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:async'; // إضافة لدعم Timer

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

  // إضافة متغير callback ودالة لتسجيل callback لزيادة عدد المشاهدات
  Function(int, String)? _onHymnChangedCallback;

  // إضافة متغير لمنع الضغط المتكرر على أزرار التالي/السابق
  bool _isChangingTrack = false;

  // إضافة مؤقت لمنع الضغط المتكرر
  Timer? _debounceTimer;

  // إضافة متغير لتتبع عدد محاولات التعافي من الأخطاء
  int _recoveryAttempts = 0;

  // إضافة متغير لتتبع آخر خطأ
  DateTime? _lastErrorTime;

  // إضافة دالة لتسجيل callback لزيادة عدد المشاهدات
  void registerHymnChangedCallback(Function(int, String) callback) {
    _onHymnChangedCallback = callback;
    print('📊 تم تسجيل callback لزيادة عدد المشاهدات');
  }

  // تعديل منشئ MyAudioService للتأكد من استدعاء restorePlaybackState مرة واحدة فقط
  MyAudioService() {
    // استدعاء _initAudioService مرة واحدة فقط عند إنشاء الكائن
    _initAudioService();

    // لا نقوم بتشغيل الترنيمة تلقائياً عند بدء التطبيق
    // إزالة الاستدعاء المتأخر لاستئناف التشغيل
  }

  // دالة جديدة لتهيئة خدمة الصوت
  Future<void> _initAudioService() async {
    if (_isInitialized) return;

    try {
      await _setupAudioFocusHandling();
      await _initAudioPlayer();

      // تهيئة الخدمة اكتملت
      _isInitialized = true;
      print('✅ تم تهيئة خدمة الصوت بنجاح');
    } catch (e) {
      print('❌ خطأ في تهيئة خدمة الصوت: $e');
      // محاولة إعادة التهيئة بعد فترة قصيرة
      Future.delayed(Duration(seconds: 2), () {
        _initAudioService();
      });
    }
  }

  // إضافة دالة للتعامل مع تركيز الصوت
  Future<void> _setupAudioFocusHandling() async {
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
        print('🎧 تم فصل سماعات الرأس');
        if (isPlayingNotifier.value) {
          _wasPlayingBeforeInterruption = true;
          pause();
        }
      });

      // التعامل مع مقاطعات الصوت (مثل المكالمات)
      _audioSession?.interruptionEventStream.listen((event) {
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
          if (_wasPlayingBeforeInterruption) {
            play();
            _wasPlayingBeforeInterruption = false;
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

  // تعديل في دالة _initAudioPlayer لضمان تشغيل الترنيمة التالية عند انتهاء الحالية
  Future<void> _initAudioPlayer() async {
    try {
      // تنظيف أي استماع سابق
      await _audioPlayer.stop();

      // إلغاء الاستماع للتغييرات في حالة التشغيل قبل إعادة تسجيلها
      // (هذا لتجنب تعدد المستمعين)

      // Listen to playback state changes
      _audioPlayer.playerStateStream.listen((state) {
        print(
            '🎵 تغيرت حالة التشغيل: ${state.playing ? 'يعمل' : 'متوقف'}, ${state.processingState}');
        isPlayingNotifier.value = state.playing;

        // تحديث حالة التحميل
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
        if (!_isRestoringPosition) {
          positionNotifier.value = position;
        }
      });

      // Listen to duration changes
      _audioPlayer.durationStream.listen((duration) {
        durationNotifier.value = duration;
      });

      // Listen to playback completion
      _audioPlayer.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) {
          print('🎵 الترنيمة انتهت، وضع التكرار: ${repeatModeNotifier.value}');

          if (repeatModeNotifier.value == 1) {
            // Repeat current hymn
            print('🔄 تكرار الترنيمة الحالية');
            _audioPlayer.seek(Duration.zero);
            _audioPlayer.play();
          } else {
            // Play next hymn (with wrap-around) even if repeat mode is off
            print('⏭️ الانتقال إلى الترنيمة التالية');
            playNext();
          }
        }
      });

      // Listen to errors to recover from them
      _audioPlayer.playbackEventStream.listen(
        (event) {
          // تسجيل الأحداث للتصحيح
          if (event.processingState == ProcessingState.idle) {
            print('🎵 حالة المشغل: خامل (idle)');
          }
        },
        onError: (error) {
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
  // تعديل دالة _handlePlaybackError لتجنب إعادة تعيين المتغير النهائي
  Future<void> _handlePlaybackError() async {
    try {
      // تسجيل وقت الخطأ
      final now = DateTime.now();

      // إذا كان الخطأ الأخير حدث خلال الثواني القليلة الماضية، زيادة عدد محاولات التعافي
      if (_lastErrorTime != null &&
          now.difference(_lastErrorTime!).inSeconds < 5) {
        _recoveryAttempts++;
        print('⚠️ تكرار الخطأ، عدد محاولات التعافي: $_recoveryAttempts');

        // إذا كان هناك عدة محاولات متتالية، انتظر فترة أطول قبل المحاولة مرة أخرى
        if (_recoveryAttempts > 3) {
          print('⚠️ عدد كبير من محاولات التعافي، انتظار فترة أطول...');
          await Future.delayed(Duration(seconds: 3));
          _recoveryAttempts = 0; // إعادة تعيين العداد بعد الانتظار
        }
      } else {
        _recoveryAttempts = 1;
      }

      _lastErrorTime = now;

      // حفظ المعلومات الحالية
      final wasPlaying = isPlayingNotifier.value;
      final currentIndex = currentIndexNotifier.value;
      final currentPosition = positionNotifier.value;

      // إيقاف المشغل الحالي
      await _audioPlayer.stop();

      // إعادة تهيئة المشغل بدون إعادة إنشائه
      try {
        await _audioPlayer.setAudioSource(
            AudioSource.uri(Uri.parse('https://example.com/empty.mp3')),
            preload: false);
      } catch (error) {
        // تجاهل أي أخطاء هنا، فقط نحاول إعادة تعيين حالة المشغل
        print('تم تجاهل خطأ أثناء إعادة تعيين المشغل: $error');
      }

      // استعادة التشغيل إذا كان يعمل
      if (wasPlaying &&
          _playlist.isNotEmpty &&
          currentIndex < _playlist.length) {
        await prepareHymnAtPosition(
            currentIndex, _titles[currentIndex], currentPosition);
        await play();
      }

      // إعادة تعيين متغير تغيير المسار
      _isChangingTrack = false;
    } catch (e) {
      print('❌ خطأ في معالجة خطأ التشغيل: $e');
      _isChangingTrack = false;
    }
  }

  Future<void> setPlaylist(List<String> urls, List<String> titles,
      [List<String?> artworkUrls = const []]) async {
    if (urls.isEmpty || titles.isEmpty || urls.length != titles.length) {
      print('Invalid playlist');
      return;
    }

    // حفظ حالة التشغيل قبل تغيير قائمة التشغيل
    _wasPlayingBeforeInterruption = isPlayingNotifier.value;

    _playlist = urls;
    _titles = titles;

    // إذا تم توفير روابط صور، استخدمها، وإلا استخدم قائمة فارغة بنفس طول القائمة
    if (artworkUrls.isNotEmpty && artworkUrls.length == urls.length) {
      _artworkUrls = artworkUrls;
    } else {
      _artworkUrls = List.filled(urls.length, null);
    }

    // Save new playlist
    await _saveCurrentState();
  }

  Future<void> play([int? index, String? title]) async {
    // التأكد من اكتمال التهيئة
    if (!_isInitialized) {
      await _initAudioService();
    }

    try {
      if (index != null) {
        await _playAtIndex(index, title);
      } else {
        // Resume playback
        await _audioPlayer.play();
        print('▶️ تم استئناف التشغيل');
      }
    } catch (e) {
      print('❌ خطأ أثناء التشغيل: $e');
      // محاولة التعافي من الخطأ
      _handlePlaybackError();
    }
  }

  // إضافة دالة للتحقق من حالة الاتصال بالإنترنت
  Future<bool> _isConnectedToInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  // تعديل في دالة _playAtIndex لتحسين آلية التحميل أثناء التشغيل
  Future<void> _playAtIndex(int index, String? title) async {
    if (index < 0 || index >= _playlist.length) {
      print('Invalid index: $index, playlist length: ${_playlist.length}');
      return;
    }

    // منع تغيير المسار إذا كانت هناك عملية تغيير جارية بالفعل
    if (_isChangingTrack) {
      print('⚠️ جاري تغيير المسار بالفعل، تجاهل الطلب الجديد');
      return;
    }

    // تعيين متغير تغيير المسار
    _isChangingTrack = true;

    // إلغاء أي مؤقت سابق
    if (_debounceTimer != null) {
      _debounceTimer!.cancel();
    }

    // إعداد مؤقت لإعادة تعيين متغير تغيير المسار بعد فترة
    _debounceTimer = Timer(Duration(seconds: 3), () {
      _isChangingTrack = false;
    });

    try {
      print('Playing: ${title ?? _titles[index]} at index $index');

      // تحديث المؤشر الحالي والعنوان مباشرة
      int previousIndex = currentIndexNotifier.value;
      String? previousTitle = currentTitleNotifier.value;

      // تحديث القيم الجديدة
      currentIndexNotifier.value = index;
      currentTitleNotifier.value = title ?? _titles[index];

      // استدعاء callback لتغيير الترنيمة إذا كانت مختلفة عن السابقة
      if (_onHymnChangedCallback != null &&
          (previousIndex != index ||
              previousTitle != currentTitleNotifier.value)) {
        print('📊 استدعاء callback لزيادة عدد المشاهدات عند تغيير الترنيمة');
        _onHymnChangedCallback!(index, currentTitleNotifier.value!);
      }

      // Show loading indicator
      isLoadingNotifier.value = true;

      // Get URL for the hymn
      final String url = _playlist[index];

      // التأكد من توقف التشغيل الحالي
      await _audioPlayer.stop();

      // تحميل الترانيم التالية والسابقة في الخلفية بشكل استباقي
      _preloadAdjacentHymns(index);

      // التحقق من حالة الاتصال بالإنترنت
      bool isConnected = await _isConnectedToInternet();

      if (!isConnected) {
        print('⚠️ لا يوجد اتصال بالإنترنت، محاولة التشغيل من الكاش...');

        // البحث عن الملف في الكاش
        final cachedPath = await _getCachedFile(url);

        if (cachedPath != null) {
          // تشغيل الملف من الكاش
          final fileSource = AudioSource.uri(Uri.file(cachedPath));
          await _audioPlayer.setAudioSource(fileSource, preload: true);
          await _audioPlayer.play();

          // إخفاء مؤشر التحميل
          isLoadingNotifier.value = false;

          // حفظ الحالة في الخلفية
          _saveCurrentState();

          print('✅ تم تشغيل الترنيمة من الكاش بنجاح');
          _isChangingTrack = false;
          return;
        } else {
          print('⚠️ الملف غير موجود في الكاش ولا يوجد اتصال بالإنترنت');
          isLoadingNotifier.value = false;
          _isChangingTrack = false;
          return;
        }
      }

      // تجريب الاستراتيجيات المختلفة للتشغيل
      try {
        // استراتيجية 1: استخدام تهيئة مباشرة
        print('🎵 محاولة تشغيل باستخدام استراتيجية 1');
        final audioSource = AudioSource.uri(Uri.parse(url));

        // استخدام setAudioSource مع preload: true لتحميل الملف بشكل كامل
        await _audioPlayer.setAudioSource(audioSource, preload: true);

        // بدء التشغيل
        await _audioPlayer.play();

        // تخزين الملف في الخلفية للاستخدام المستقبلي
        _cacheFileInBackground(url);
      } catch (e) {
        print('❌ فشلت استراتيجية 1: $e');

        // استراتيجية 2: استخدام الملف المخزن مؤقتًا إذا كان متاحًا
        try {
          print('🎵 محاولة تشغيل باستخدام استراتيجية 2');

          // البحث عن الملف في الذاكرة المؤقتة
          final cachedPath = await _getCachedFile(url);

          if (cachedPath != null) {
            final fileSource = AudioSource.uri(Uri.file(cachedPath));
            await _audioPlayer.setAudioSource(fileSource, preload: true);
            await _audioPlayer.play();
          } else {
            throw Exception('ملف التخزين المؤقت غير متاح');
          }
        } catch (e2) {
          print('❌ فشلت استراتيجية 2: $e2');

          // استراتيجية 3: استخدام طريقة أبسط
          try {
            print('🎵 محاولة تشغيل باستخدام استراتيجية 3');
            await _audioPlayer.setUrl(url);
            await _audioPlayer.play();

            // تخزين الملف في الخلفية للاستخدام المستقبلي
            _cacheFileInBackground(url);
          } catch (e3) {
            print('❌ فشلت جميع استراتيجيات التشغيل: $e3');
            _isChangingTrack = false;
            throw e3; // إعادة رمي الخطأ للمعالجة الخارجية
          }
        }
      }

      // إخفاء مؤشر التحميل
      isLoadingNotifier.value = false;

      // حفظ الحالة في الخلفية
      _saveCurrentState();

      print('Playback started successfully');
      _isChangingTrack = false;
    } catch (e) {
      print('Error playing hymn: $e');
      // إصلاح: تأكد من إخفاء مؤشر التحميل في حالة حدوث خطأ
      isLoadingNotifier.value = false;
      _isChangingTrack = false;

      // محاولة التعافي من الخطأ
      _handlePlaybackError();
    }
  }

  Future<void> playFromBeginning(int index, String title) async {
    await _playAtIndex(index, title);
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
  void _cacheFileInBackground(String url) {
    // تأخير تحميل الملف في الخلفية لتجنب التنافس على الموارد
    Future.delayed(Duration(milliseconds: 500), () async {
      try {
        // التحقق مما إذا كان الملف موجودًا بالفعل في الذاكرة المؤقتة
        final fileInfo = await _cacheManager.getFileFromCache(url);
        if (fileInfo != null) {
          _cachedFiles[url] = fileInfo.file.path;
          print('✅ الملف موجود بالفعل في الذاكرة المؤقتة: $url');
          return;
        }

        // تحميل الملف بشكل تدريجي
        print('🔄 جاري تحميل الملف للتخزين المؤقت: $url');
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

  // دالة جديدة لتحميل الترانيم المجاورة بشكل استباقي
  void _preloadAdjacentHymns(int currentIndex) {
    if (_playlist.isEmpty) return;

    // تحميل الترنيمة التالية
    final nextIndex = (currentIndex + 1) % _playlist.length;
    if (nextIndex != currentIndex) {
      _cacheFileInBackground(_playlist[nextIndex]);
    }

    // تحميل الترنيمة السابقة
    final prevIndex = (currentIndex - 1 + _playlist.length) % _playlist.length;
    if (prevIndex != currentIndex && prevIndex != nextIndex) {
      _cacheFileInBackground(_playlist[prevIndex]);
    }

    // تحميل ترنيمة إضافية للأمام
    final nextNextIndex = (nextIndex + 1) % _playlist.length;
    if (nextNextIndex != currentIndex && nextNextIndex != prevIndex) {
      _cacheFileInBackground(_playlist[nextNextIndex]);
    }

    print('🔄 تم جدولة تحميل الترانيم المجاورة في الخلفية');
  }

  Future<void> prepareHymnAtPosition(
      int index, String title, Duration position) async {
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

      // Update position directly in ValueNotifier to avoid flicker
      positionNotifier.value = position;

      // توقف أي تشغيل حالي
      await _audioPlayer.stop();

      // محاولة تحضير الملف بطرق مختلفة
      try {
        // Set audio source with specified position
        await _audioPlayer.setAudioSource(
          AudioSource.uri(Uri.parse(_playlist[index])),
          initialPosition: position,
          preload: true,
        );
      } catch (e) {
        print('Error in primary preparation method: $e');

        // محاولة ثانية باستخدام الملف المخزن مؤقتاً
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

      // Clear restoration flag after setup
      _isRestoringPosition = false;

      print('Hymn prepared at specified position successfully');
    } catch (e) {
      _isRestoringPosition = false;
      print('Error preparing hymn at position: $e');

      // Fallback method - final attempt
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

          // Use setAudioSource directly for faster loading
          await _audioPlayer.setAudioSource(
            AudioSource.uri(Uri.parse(_playlist[currentIndexNotifier.value])),
          );

          // Restore last position
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

          // If playlist is not empty, try to play first hymn
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

      // Save state after toggle
      await _saveCurrentState();
      print('Toggle play/pause completed');
    } catch (e) {
      print('Error in togglePlayPause: $e');
      // محاولة التعافي من الخطأ
      _handlePlaybackError();
    }
  }

  // دالة لإيقاف التشغيل مؤقتاً (للاستخدام الخارجي)
  Future<void> pause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
      print('⏸️ تم إيقاف التشغيل مؤقتاً من خلال دالة pause()');
    }
  }

  // تعديل دالة stop لمنع إيقاف التشغيل أثناء التنقل
  Future<void> stop() async {
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
    // Set restoration flag to prevent progress bar updates during seeking
    _isRestoringPosition = true;

    // Update position directly in ValueNotifier to avoid flicker
    positionNotifier.value = position;

    await _audioPlayer.seek(position);

    // Clear restoration flag after seeking
    _isRestoringPosition = false;
  }

  // تعديل دالة playNext لزيادة عدد المشاهدات عند الانتقال للترنيمة التالية
  Future<void> playNext() async {
    if (_playlist.isEmpty) return;

    // منع التشغيل إذا كان هناك عملية تغيير مسار جارية
    if (_isChangingTrack) {
      print('⚠️ جاري تغيير المسار، تجاهل طلب التشغيل التالي');
      return;
    }

    print('⏭️ تشغيل الترنيمة التالية');

    int nextIndex;
    if (isShufflingNotifier.value) {
      // Choose a random hymn different from current
      nextIndex = _getRandomIndex();
      print('🔀 اختيار ترنيمة عشوائية: $nextIndex');
    } else {
      // Move to next hymn in playlist
      nextIndex = (currentIndexNotifier.value + 1) % _playlist.length;
      print('➡️ الانتقال إلى الترنيمة التالية في القائمة: $nextIndex');
    }

    // Use playFromBeginning for immediate playback
    await playFromBeginning(nextIndex, _titles[nextIndex]);
  }

  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;

    // منع التشغيل إذا كان هناك عملية تغيير مسار جارية
    if (_isChangingTrack) {
      print('⚠️ جاري تغيير المسار، تجاهل طلب التشغيل السابق');
      return;
    }

    int prevIndex;
    if (isShufflingNotifier.value) {
      // Choose a random hymn different from current
      prevIndex = _getRandomIndex();
    } else {
      // Move to previous hymn in playlist
      prevIndex = (currentIndexNotifier.value - 1 + _playlist.length) %
          _playlist.length;
    }

    // Use playFromBeginning for immediate playback
    await playFromBeginning(prevIndex, _titles[prevIndex]);
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
    isShufflingNotifier.value = !isShufflingNotifier.value;
    await _saveCurrentState();
  }

  Future<void> toggleRepeat() async {
    // Cycle repeat mode: 0 (off) -> 1 (one) -> 2 (all) -> 0 ...
    repeatModeNotifier.value = (repeatModeNotifier.value + 1) % 3;
    await _saveCurrentState();
  }

  Future<void> _saveCurrentState() async {
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
    print('Saving state on app close...');

    try {
      // Save current position explicitly
      final currentPosition = positionNotifier.value.inSeconds;
      final userId = _getCurrentUserId();
      final prefs = await SharedPreferences.getInstance();

      // Save current title and index
      if (currentTitleNotifier.value != null) {
        await prefs.setString(
            'lastPlayedTitle_$userId', currentTitleNotifier.value!);
      }
      await prefs.setInt('lastPlayedIndex_$userId', currentIndexNotifier.value);

      // Save current position
      await prefs.setInt('lastPosition_$userId', currentPosition);
      print('Saved position on close: $currentPosition seconds');

      // Save playback state
      await prefs.setBool('wasPlaying_$userId', isPlayingNotifier.value);

      // Save playlist and titles
      if (_playlist.isNotEmpty && _titles.isNotEmpty) {
        await prefs.setStringList('lastPlaylist_$userId', _playlist);
        await prefs.setStringList('lastTitles_$userId', _titles);

        // حفظ روابط صور الترانيم (مع التعامل مع القيم الفارغة)
        if (_artworkUrls.isNotEmpty) {
          final artworkUrlsToSave =
              _artworkUrls.map((url) => url ?? '').toList();
          await prefs.setStringList(
              'lastArtworkUrls_$userId', artworkUrlsToSave);
        }
      }

      // Save repeat and shuffle modes
      await prefs.setInt('repeatMode_$userId', repeatModeNotifier.value);
      await prefs.setBool('isShuffling_$userId', isShufflingNotifier.value);

      print('Saved playback state on app close successfully');
    } catch (e) {
      print('Error saving playback state on app close: $e');
    }
  }

  // تعديل دالة restorePlaybackState للتحكم في التشغيل التلقائي والمعالجة المحسنة
  Future<void> restorePlaybackState() async {
    if (_resumeTimer != null) {
      _resumeTimer!.cancel();
      _resumeTimer = null;
    }

    try {
      final userId = _getCurrentUserId();
      print('Restoring playback state for user: $userId');
      final prefs = await SharedPreferences.getInstance();

      // Restore repeat and shuffle modes
      repeatModeNotifier.value = prefs.getInt('repeatMode_$userId') ?? 0;
      isShufflingNotifier.value = prefs.getBool('isShuffling_$userId') ?? false;

      // Restore playlist and titles
      final lastPlaylist = prefs.getStringList('lastPlaylist_$userId');
      final lastTitles = prefs.getStringList('lastTitles_$userId');

      if (lastPlaylist == null ||
          lastTitles == null ||
          lastPlaylist.isEmpty ||
          lastPlaylist.length != lastTitles.length) {
        print('No previous playlist found or invalid playlist');
        return;
      }

      print('Restored playlist: ${lastPlaylist.length} hymns');
      _playlist = lastPlaylist;
      _titles = lastTitles;

      // استعادة روابط صور الترانيم (تبسيط)
      _artworkUrls = List.filled(lastPlaylist.length, null);

      // Restore last played hymn
      final lastTitle = prefs.getString('lastPlayedTitle_$userId');
      final lastIndex = prefs.getInt('lastPlayedIndex_$userId') ?? 0;
      final lastPosition = prefs.getInt('lastPosition_$userId') ?? 0;
      // استرجاع حالة التشغيل السابقة (كانت قيد التشغيل أم لا)
      final wasPlaying = prefs.getBool('wasPlaying_$userId') ?? false;

      print('Last title: $lastTitle');
      print('Last index: $lastIndex');
      print('Last position: $lastPosition seconds');
      print('Was playing: $wasPlaying');

      if (lastTitle == null || lastIndex < 0 || lastIndex >= _playlist.length) {
        print('Invalid last hymn information');
        return;
      }

      print('Found last hymn: $lastTitle, index: $lastIndex');

      // Set current title and index
      currentTitleNotifier.value = lastTitle;
      currentIndexNotifier.value = lastIndex;

      // Set restoration flag to prevent progress bar updates during restoration
      _isRestoringPosition = true;

      // Update position directly in ValueNotifier to avoid flicker
      if (lastPosition > 0) {
        positionNotifier.value = Duration(seconds: lastPosition);
      }

      try {
        print('Setting up audio source: ${_playlist[lastIndex]}');

        // Set up audio source with saved position
        await prepareHymnAtPosition(lastIndex, lastTitle,
            lastPosition > 0 ? Duration(seconds: lastPosition) : Duration.zero);

        // Clear restoration flag after setup
        _isRestoringPosition = false;

        // مهم: لا نقوم بتشغيل الترنيمة تلقائياً عند فتح التطبيق
        // حتى لو كانت قيد التشغيل قبل إغلاق التطبيق
        print('✅ تم استعادة معلومات آخر ترنيمة بدون تشغيل تلقائي');

        // حفظ حالة التشغيل السابقة لاستخدامها في استئناف التشغيل لاحقاً
        // لكن لا نقوم بتشغيل الترنيمة تلقائياً
        _shouldResumeAfterNavigation = false; // تغيير هنا
        _wasPlayingBeforeInterruption = false; // تغيير هنا

        // تأكيد على عدم التشغيل التلقائي
        if (_audioPlayer.playing) {
          await _audioPlayer.pause();
        }
      } catch (e) {
        _isRestoringPosition = false;
        print('Error setting up audio source: $e');

        // محاولة استرداد الخطأ
        _handlePlaybackError();
      }
    } catch (e) {
      _isRestoringPosition = false;
      print('Error restoring playback state: $e');
    }
  }

  // تعديل دالة resumePlaybackAfterNavigation لعمل محاولات متكررة للاستئناف
  Future<void> resumePlaybackAfterNavigation() async {
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
      if (currentTitleNotifier.value != null) {
        // إذا كانت الحالة هي ProcessingState.idle فنحاول إعادة تحميل المصدر
        if (_audioPlayer.processingState == ProcessingState.idle) {
          print('🔄 حالة المشغل خاملة، إعادة تحميل المصدر...');

          if (_playlist.isNotEmpty &&
              currentIndexNotifier.value < _playlist.length) {
            try {
              // استخدام الموضع الحالي
              final position = positionNotifier.value;

              // إعادة تحميل المصدر
              await prepareHymnAtPosition(currentIndexNotifier.value,
                  currentTitleNotifier.value!, position);

              // تشغيل فقط إذا كان يعمل قبل الانتقال
              if (_wasPlayingBeforeInterruption) {
                await _audioPlayer.play();
                _wasPlayingBeforeInterruption = false;
                print('▶️ تم استئناف التشغيل بعد إعادة تحميل المصدر');
              }
            } catch (e) {
              print('❌ خطأ في إعادة تحميل المصدر: $e');
            }
          }
        }
        // التشغيل جاهز ولكن متوقف ويجب علينا استئنافه فقط إذا كان يعمل قبل الانتقال
        else if (!_audioPlayer.playing && _wasPlayingBeforeInterruption) {
          print('▶️ استئناف التشغيل بعد الانتقال');
          await _audioPlayer.play();
          _wasPlayingBeforeInterruption = false;
        } else {
          print('✅ المشغل في حالة جيدة، لا حاجة للاستئناف');
        }
      } else {
        print('⚠️ لا توجد ترنيمة حالية للاستئناف');
      }

      print('✅ تم التحقق من حالة التشغيل بنجاح');
    } catch (e) {
      print('❌ خطأ في استئناف التشغيل بعد الانتقال: $e');

      // محاولة استرداد الخطأ بعد فترة قصيرة
      _resumeTimer = Timer(Duration(milliseconds: 500), () {
        _isResumeInProgress = false;
        resumePlaybackAfterNavigation();
      });
    } finally {
      _isResumeInProgress = false;
    }
  }

  // إضافة دالة لتحميل الترانيم الشائعة مسبقًا
  Future<void> preloadPopularHymns() async {
    try {
      print('🔄 جاري تحميل الترانيم الشائعة مسبقًا...');

      // الحصول على الترانيم الأكثر استماعًا من Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('hymns')
          .orderBy('views', descending: true)
          .limit(10) // زيادة العدد من 5 إلى 10
          .get();

      if (snapshot.docs.isEmpty) {
        print('⚠️ لم يتم العثور على ترانيم شائعة');
        return;
      }

      // تحميل الترانيم في الخلفية
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final songUrl = data['songUrl'] as String?;

        if (songUrl != null && songUrl.isNotEmpty) {
          _cacheFileInBackground(songUrl);
        }
      }

      print('✅ تم بدء تحميل الترانيم الشائعة في الخلفية');
    } catch (e) {
      print('❌ خطأ في تحميل الترانيم الشائعة مسبقًا: $e');
    }
  }

  // إضافة دالة لحفظ حالة التشغيل قبل المقاطعة
  void savePlaybackState() {
    _wasPlayingBeforeInterruption = isPlayingNotifier.value;
    print(
        '💾 تم حفظ حالة التشغيل: ${_wasPlayingBeforeInterruption ? 'قيد التشغيل' : 'متوقف'}');
  }

  // إضافة دالة للإشارة إلى بداية الانتقال
  void startNavigation() {
    _isNavigating = true;
    savePlaybackState();
    print('🔄 بدء الانتقال بين الشاشات...');
  }

  // إضافة دالة للتحكم في منع الإيقاف أثناء التنقل
  void setPreventStopDuringNavigation(bool prevent) {
    _preventStopDuringNavigation = prevent;
    print('🔄 تم تعيين منع الإيقاف أثناء التنقل إلى: $prevent');
  }

  Future<void> dispose() async {
    try {
      print('🧹 تنظيف موارد مشغل الصوت...');

      // إلغاء المؤقت
      if (_resumeTimer != null) {
        _resumeTimer!.cancel();
        _resumeTimer = null;
      }

      // إلغاء مؤقت debounce
      if (_debounceTimer != null) {
        _debounceTimer!.cancel();
        _debounceTimer = null;
      }

      // حفظ الحالة قبل الإغلاق
      await saveStateOnAppClose();

      // إيقاف التشغيل وتحرير الموارد
      await _audioPlayer.stop();
      await _audioPlayer.dispose();

      print('✅ تم تنظيف موارد مشغل الصوت بنجاح');
    } catch (e) {
      print('❌ خطأ في تنظيف موارد مشغل الصوت: $e');
    }
  }

  Future<void> clearUserData() async {
    try {
      print('🧹 جاري مسح بيانات المستخدم في مشغل الصوت...');

      // إيقاف التشغيل
      await _audioPlayer.stop();

      // مسح قوائم التشغيل
      _playlist = [];
      _titles = [];
      _artworkUrls = [];
      _cachedFiles.clear();

      // إعادة تعيين المؤشرات
      currentIndexNotifier.value = 0;
      currentTitleNotifier.value = null;
      positionNotifier.value = Duration.zero;
      durationNotifier.value = null;
      isPlayingNotifier.value = false;

      // مسح البيانات من SharedPreferences
      final userId = _getCurrentUserId();
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('lastPlayedTitle_$userId');
      await prefs.remove('lastPlayedIndex_$userId');
      await prefs.remove('lastPosition_$userId');
      await prefs.remove('wasPlaying_$userId');
      await prefs.remove('lastPlaylist_$userId');
      await prefs.remove('lastTitles_$userId');
      await prefs.remove('lastArtworkUrls_$userId');
      await prefs.remove('repeatMode_$userId');
      await prefs.remove('isShuffling_$userId');

      print('✅ تم مسح بيانات المستخدم في مشغل الصوت بنجاح');
    } catch (e) {
      print('❌ خطأ في مسح بيانات المستخدم في مشغل الصوت: $e');
    }
  }

  // دالة جديدة لتنظيف الكاش القديم
  Future<void> cleanOldCache() async {
    try {
      print('🧹 جاري تنظيف الكاش القديم...');
      await _cacheManager.emptyCache();
      print('✅ تم تنظيف الكاش القديم بنجاح');
    } catch (e) {
      print('❌ خطأ في تنظيف الكاش القديم: $e');
    }
  }

  String _getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  }
}
