import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyAudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  final ValueNotifier<String?> currentTitleNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<Duration> positionNotifier =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> durationNotifier =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> currentIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isShufflingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> repeatModeNotifier = ValueNotifier<int>(0);

  List<String> _playlist = [];
  List<String> _titles = [];

  MyAudioService() {
    _setupAudioPlayer();
    // استدعاء استعادة حالة التشغيل عند إنشاء الخدمة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      restorePlaybackState();
    });
  }

  void _setupAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      isPlayingNotifier.value = state.playing;
      // حفظ الحالة عند تغيير حالة التشغيل
      if (currentTitleNotifier.value != null) {
        _saveCurrentState();
      }
    });

    _audioPlayer.positionStream.listen((position) {
      positionNotifier.value = position;
      // حفظ الموضع كل 5 ثوانٍ
      if (position.inSeconds % 5 == 0 && currentTitleNotifier.value != null) {
        _saveCurrentState();
      }
    });

    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        durationNotifier.value = duration;
      }
    });

    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null) {
        currentIndexNotifier.value = index;
        // حفظ المؤشر الحالي عند تغييره
        if (currentTitleNotifier.value != null) {
          _saveCurrentState();
        }
      }
    });
  }

  Future<void> setPlaylist(List<String> urls, List<String> titles) async {
    _playlist = List.from(urls);
    _titles = List.from(titles);
    print('✅ تم تحديث قائمة التشغيل: ${_playlist.length} ترنيمة');

    // حفظ قائمة التشغيل في التخزين المؤقت
    await _savePlaylistToPrefs();
  }

  Future<void> _savePlaylistToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_playlist.isNotEmpty) {
        await prefs.setStringList('lastPlaylist', _playlist);
      }
      if (_titles.isNotEmpty) {
        await prefs.setStringList('lastTitles', _titles);
      }
      print('✅ تم حفظ قائمة التشغيل في التخزين المؤقت');
    } catch (e) {
      print('❌ خطأ في حفظ قائمة التشغيل: $e');
    }
  }

  Future<void> play(int index, String title) async {
    if (index < 0 || index >= _playlist.length) {
      print('❌ مؤشر غير صالح: $index، طول القائمة: ${_playlist.length}');
      return;
    }

    try {
      print('▶️ جاري تشغيل: $title من المؤشر $index');

      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(_playlist[index])),
      );
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();

      currentTitleNotifier.value = title;
      currentIndexNotifier.value = index;

      // حفظ الحالة الحالية
      await _saveCurrentState();

      print('✅ تم تشغيل الترنيمة بنجاح');
    } catch (e) {
      print('❌ خطأ في تشغيل الترنيمة: $e');
    }
  }

  // إضافة دالة جديدة لتحميل الترنيمة بدون تشغيلها
  Future<void> prepareHymn(int index, String title) async {
    if (index < 0 || index >= _playlist.length) {
      print('❌ مؤشر غير صالح: $index، طول القائمة: ${_playlist.length}');
      return;
    }

    try {
      print('🔄 جاري تحميل: $title من المؤشر $index بدون تشغيل');

      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(_playlist[index])),
      );

      currentTitleNotifier.value = title;
      currentIndexNotifier.value = index;

      // حفظ الحالة الحالية
      await _saveCurrentState();

      print('✅ تم تحميل الترنيمة بنجاح بدون تشغيل');
    } catch (e) {
      print('❌ خطأ في تحميل الترنيمة: $e');
    }
  }

  Future<void> _saveCurrentState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // حفظ معلومات التشغيل الأساسية
      if (currentTitleNotifier.value != null) {
        await prefs.setString('lastPlayedTitle', currentTitleNotifier.value!);
      }
      await prefs.setInt('lastPlayedIndex', currentIndexNotifier.value);
      await prefs.setInt('lastPosition', positionNotifier.value.inSeconds);
      await prefs.setBool('wasPlaying', isPlayingNotifier.value);

      // حفظ عنوان URL الحالي للوصول المباشر إذا لزم الأمر
      if (currentIndexNotifier.value >= 0 &&
          currentIndexNotifier.value < _playlist.length) {
        await prefs.setString(
            'lastPlayedUrl', _playlist[currentIndexNotifier.value]);
      }

      print('💾 تم حفظ حالة التشغيل الحالية');
    } catch (e) {
      print('❌ خطأ في حفظ الحالة: $e');
    }
  }

  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }

    // حفظ الحالة بعد التبديل
    await _saveCurrentState();
  }

  Future<void> playNext() async {
    if (_playlist.isEmpty) return;

    int nextIndex = currentIndexNotifier.value + 1;
    if (nextIndex >= _playlist.length) {
      nextIndex = 0;
    }
    await play(nextIndex, _titles[nextIndex]);
  }

  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;

    int prevIndex = currentIndexNotifier.value - 1;
    if (prevIndex < 0) {
      prevIndex = _playlist.length - 1;
    }
    await play(prevIndex, _titles[prevIndex]);
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);

    // حفظ الموضع بعد البحث
    await _saveCurrentState();
  }

  Future<void> toggleShuffle() async {
    isShufflingNotifier.value = !isShufflingNotifier.value;

    // حفظ حالة الخلط
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isShuffling', isShufflingNotifier.value);

    if (isShufflingNotifier.value) {
      // حفظ المؤشر والعنوان الحاليين قبل الخلط
      final currentIndex = currentIndexNotifier.value;
      final currentUrl = currentIndex >= 0 && currentIndex < _playlist.length
          ? _playlist[currentIndex]
          : null;

      // خلط كلا القائمتين معًا
      List<String> tempUrls = List.from(_playlist);
      List<String> tempTitles = List.from(_titles);

      // إنشاء أزواج، خلط، ثم فك التعبئة
      List<MapEntry<String, String>> pairs = [];
      for (int i = 0; i < tempUrls.length; i++) {
        pairs.add(MapEntry(tempUrls[i], tempTitles[i]));
      }

      pairs.shuffle();

      _playlist = pairs.map((e) => e.key).toList();
      _titles = pairs.map((e) => e.value).toList();

      // البحث عن المؤشر الجديد للأغنية الحالية
      if (currentUrl != null) {
        final newIndex = _playlist.indexOf(currentUrl);
        if (newIndex != -1) {
          currentIndexNotifier.value = newIndex;
        }
      }

      // حفظ قائمة التشغيل الجديدة
      await _savePlaylistToPrefs();
    }
  }

  Future<void> toggleRepeat() async {
    repeatModeNotifier.value = (repeatModeNotifier.value + 1) % 3;

    // حفظ وضع التكرار
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('repeatMode', repeatModeNotifier.value);
  }

  Future<void> restorePlaybackState() async {
    try {
      print('🔄 جاري استعادة حالة التشغيل...');
      final prefs = await SharedPreferences.getInstance();

      // استعادة وضع التكرار
      repeatModeNotifier.value = prefs.getInt('repeatMode') ?? 0;

      // استعادة حالة الخلط
      isShufflingNotifier.value = prefs.getBool('isShuffling') ?? false;

      // استعادة قائمة التشغيل والعناوين
      final lastPlaylist = prefs.getStringList('lastPlaylist');
      final lastTitles = prefs.getStringList('lastTitles');

      if (lastPlaylist != null &&
          lastTitles != null &&
          lastPlaylist.isNotEmpty &&
          lastPlaylist.length == lastTitles.length) {
        print('✅ تم استعادة قائمة التشغيل: ${lastPlaylist.length} ترنيمة');
        _playlist = lastPlaylist;
        _titles = lastTitles;
      } else {
        print('⚠️ لم يتم العثور على قائمة تشغيل سابقة أو القائمة غير صالحة');
        return; // الخروج إذا لم تكن هناك قائمة تشغيل صالحة
      }

      // استعادة آخر أغنية تم تشغيلها
      final lastTitle = prefs.getString('lastPlayedTitle');
      final lastIndex = prefs.getInt('lastPlayedIndex');
      final lastPosition = prefs.getInt('lastPosition') ?? 0;
      final wasPlaying = prefs.getBool('wasPlaying') ?? false;

      if (lastTitle != null &&
          lastIndex != null &&
          lastIndex >= 0 &&
          lastIndex < _playlist.length) {
        print('✅ تم العثور على آخر ترنيمة: $lastTitle، المؤشر: $lastIndex');

        // تعيين العنوان والمؤشر الحاليين
        currentTitleNotifier.value = lastTitle;
        currentIndexNotifier.value = lastIndex;

        // إعداد مصدر الصوت بدون تشغيل تلقائي
        await _audioPlayer.setAudioSource(
          AudioSource.uri(Uri.parse(_playlist[lastIndex])),
        );

        // الانتقال إلى آخر موضع
        if (lastPosition > 0) {
          await _audioPlayer.seek(Duration(seconds: lastPosition));
        }

        // لا نقوم بالتشغيل تلقائيًا
        // تم إزالة: if (wasPlaying) { await _audioPlayer.play(); }

        print('✅ تم استعادة حالة التشغيل بنجاح بدون تشغيل تلقائي');
      } else {
        print('⚠️ لم يتم العثور على معلومات آخر ترنيمة أو المعلومات غير صالحة');
      }
    } catch (e) {
      print('❌ خطأ في استعادة حالة التشغيل: $e');
    }
  }

  Future<void> stop() async {
    // حفظ الحالة قبل الإيقاف
    await _saveCurrentState();

    await _audioPlayer.stop();
    isPlayingNotifier.value = false;
  }

  Future<void> dispose() async {
    // حفظ الحالة قبل التخلص
    await _saveCurrentState();

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
