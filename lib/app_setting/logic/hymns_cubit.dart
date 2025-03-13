import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_states.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HymnsCubit extends Cubit<HymnsState> {
  final Myaudioservice audioService;
  final CacheManager cacheManager;

  List<HymnsModel> hymns = [];
  HymnsModel? currentHymn;
  Duration currentPosition = Duration.zero;
  bool isPlaying = false;

  HymnsCubit(this.audioService, this.cacheManager) : super(InitHymnsStates());

  /// 🔹 استعادة آخر ترنيمة تم تشغيلها بعد فتح التطبيق
  void restoreLastHymn(HymnsModel hymn, int position) {
    currentHymn = hymn;

    // ✅ استرجاع الموضع فقط لو الترانيمة مش شغالة
    if (!audioService.isPlaying) {
      currentPosition = Duration(seconds: position);
    }

    isPlaying = audioService.isPlaying;

    emit(HymnsLastPlayed(
      hymns.indexOf(currentHymn!),
      hymn.songName,
      hymn.songUrl,
      audioService.positionNotifier.value, // ✅ تحديث الوقت الفعلي
      isPlaying,
    ));
  }

  Future<void> playHymn(HymnsModel hymn) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (currentHymn == hymn && audioService.isPlayingNotifier.value) {
      // إذا كانت الترنيمة نفسها شغالة، قم بإيقافها
      audioService.togglePlayPause();
      return;
    }

    await prefs.setInt('lastPlayedIndex', hymns.indexOf(hymn));
    await prefs.setString('lastPlayedTitle', hymn.songName);
    await prefs.setBool('isPlaying', true);

    currentHymn = hymn;
    isPlaying = true;

    emit(HymnsLastPlayed(
      hymns.indexOf(hymn),
      hymn.songName,
      hymn.songUrl,
      Duration.zero,
      isPlaying,
    ));

    await audioService.play(hymns.indexOf(hymn), hymn.songName);
    increasePlayCount(hymn.id);

    // ✅ تحديث الحالة بناءً على `isPlayingNotifier`
    audioService.isPlayingNotifier.addListener(() {
      isPlaying = audioService.isPlayingNotifier.value;
      emit(HymnsLastPlayed(
        hymns.indexOf(currentHymn!),
        currentHymn!.songName,
        currentHymn!.songUrl,
        audioService.positionNotifier.value,
        isPlaying,
      ));
    });
  }

  void pauseHymn() async {
    if (currentHymn == null) return;

    isPlaying = false;
    audioService.togglePlayPause(); // ✅ استدعاء `togglePlayPause` بدل `pause()`

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastPosition', currentPosition.inSeconds);

    emit(HymnsLastPlayed(
      hymns.indexOf(currentHymn!),
      currentHymn!.songName,
      currentHymn!.songUrl,
      currentPosition,
      isPlaying,
    ));
  }

  /// 🔹 استئناف تشغيل الترنيمة من نفس الموضع
  void resumeHymn() async {
    if (currentHymn == null) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? lastPosition = prefs.getInt('lastPosition');

    // ✅ استرجاع الموضع فقط لو التطبيق كان مقفول
    if (!audioService.isPlaying && lastPosition != null) {
      audioService.seek(Duration(seconds: lastPosition));
    }

    audioService.resume();

    isPlaying = true;
    emit(HymnsLastPlayed(
      hymns.indexOf(currentHymn!),
      currentHymn!.songName,
      currentHymn!.songUrl,
      audioService.positionNotifier.value, // ✅ تحديث الوقت الفعلي
      isPlaying,
    ));
  }

  /// 🔹 إيقاف التشغيل تمامًا عند غلق التطبيق
  void stopHymn() async {
    if (currentHymn == null) return;

    isPlaying = false;
    audioService.pause(); // ✅ إيقاف المشغل ولكن بدون مسحه

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('lastPosition');
    prefs.remove('isPlaying');

    emit(HymnsStopped());
  }

  /// 🔹 إنشاء ترنيمة جديدة في قاعدة البيانات
  void createHymn({
    required String title,
    required String url,
    String? youtubeUrl,
    required String category,
    required String album,
  }) async {
    try {
      emit(HymnsLoading());

      final hymnData = {
        "title": title,
        "url": url,
        "youtubeUrl": youtubeUrl,
        "category": category,
        "album": album,
        "views": 0,
        "createdAt": DateTime.now().millisecondsSinceEpoch,
      };

      await FirebaseFirestore.instance.collection("hymns").add(hymnData);

      emit(CreateHymnSuccessState());
    } catch (e) {
      emit(HymnsErrorState(e.toString()));
    }
  }

  Future<void> increasePlayCount(String hymnId) async {
    try {
      DocumentReference docRef =
          FirebaseFirestore.instance.collection('hymns').doc(hymnId);

      DocumentSnapshot doc = await docRef.get();
      if (doc.exists) {
        await docRef.update({'views': FieldValue.increment(1)});
      }
    } catch (e) {
      print("❌ خطأ أثناء تحديث عدد المشاهدات: $e");
    }
  }
}
