import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AppOpenAdService {
  // متغير لتخزين الإعلان
  AppOpenAd? _appOpenAd;

  // حالة الإعلان
  bool _isAdLoaded = false;
  bool _isShowingAd = false;
  bool _isLoadingAd = false;

  // متغير جديد لتتبع ما إذا كان التطبيق يفتح لأول مرة
  bool _isFirstOpen = true;

  // معرف وحدة الإعلان (باستخدام المعرفات الصحيحة)
  final String adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3343409547143147/6617828980' // معرف إعلان الفتح لـ Android
      : 'ca-app-pub-3343409547143147/8063127818'; // معرف إعلان الفتح لـ iOS

  // دالة تحميل الإعلان
  Future<void> loadAd() async {
    // تجنب تحميل الإعلان إذا كان هناك عملية تحميل جارية بالفعل
    if (_isLoadingAd) {
      print('⚠️ جاري تحميل إعلان الفتح بالفعل');
      return;
    }

    // التخلص من الإعلان القديم إذا كان موجودًا
    if (_appOpenAd != null) {
      await _appOpenAd!.dispose();
      _appOpenAd = null;
      _isAdLoaded = false;
    }

    _isLoadingAd = true;

    try {
      print('🔄 جاري تحميل إعلان الفتح...');

      // استخدام الطريقة الصحيحة لتحميل الإعلان
      await AppOpenAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            print('🎯 تم تحميل إعلان الفتح بنجاح');
            _appOpenAd = ad;
            _isAdLoaded = true;
            _isLoadingAd = false;

            // إعداد معالجات محتوى الشاشة الكاملة
            _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                print('🎬 تم عرض إعلان الفتح بملء الشاشة');
                _isShowingAd = true;
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                print('❌ فشل عرض إعلان الفتح: $error');
                _isShowingAd = false;
                _isAdLoaded = false;
                ad.dispose();
                _appOpenAd = null;
                _isLoadingAd = false;

                // إعادة تحميل الإعلان بعد فشل العرض
                Future.delayed(Duration(seconds: 1), () {
                  loadAd();
                });
              },
              onAdDismissedFullScreenContent: (ad) {
                print('👋 تم إغلاق إعلان الفتح');
                _isShowingAd = false;
                _isAdLoaded = false;
                ad.dispose();
                _appOpenAd = null;
                _isLoadingAd = false;

                // إعادة تحميل الإعلان بعد إغلاقه
                Future.delayed(Duration(seconds: 1), () {
                  loadAd();
                });
              },
            );
          },
          onAdFailedToLoad: (error) {
            print('🚫 فشل تحميل إعلان الفتح: $error');
            _isAdLoaded = false;
            _isLoadingAd = false;

            // إعادة المحاولة بعد فترة قصيرة
            Future.delayed(Duration(seconds: 5), () {
              loadAd();
            });
          },
        ),
      );
    } catch (e) {
      print('❌ خطأ في تحميل إعلان الفتح: $e');
      _isAdLoaded = false;
      _isLoadingAd = false;

      // إعادة المحاولة بعد فترة قصيرة
      Future.delayed(Duration(seconds: 5), () {
        loadAd();
      });
    }
  }

  // دالة جديدة للانتظار حتى تحميل الإعلان
  Future<bool> waitForAdToLoad({int maxWaitSeconds = 5}) async {
    int waitedSeconds = 0;

    while (!_isAdLoaded && !_isLoadingAd && waitedSeconds < maxWaitSeconds) {
      await Future.delayed(Duration(seconds: 1));
      waitedSeconds++;
      print('⏳ انتظار تحميل الإعلان... ($waitedSeconds/$maxWaitSeconds)');
    }

    // إذا كان الإعلان قيد التحميل، انتظر حتى اكتمال التحميل
    while (_isLoadingAd && waitedSeconds < maxWaitSeconds) {
      await Future.delayed(Duration(milliseconds: 500));
      waitedSeconds++;
      print('⏳ الإعلان قيد التحميل... ($waitedSeconds/$maxWaitSeconds)');
    }

    return _isAdLoaded;
  }

  // دالة عرض الإعلان
  Future<bool> showAdIfAvailable() async {
    try {
      // إذا كان الإعلان قيد العرض، لا تعرضه مرة أخرى
      if (_isShowingAd) {
        print('⚠️ الإعلان قيد العرض بالفعل');
        return false;
      }

      // إذا كان الإعلان غير محمل، حاول تحميله أولاً إذا لم تكن هناك عملية تحميل جارية
      if (!_isAdLoaded || _appOpenAd == null) {
        if (!_isLoadingAd) {
          print('⚠️ الإعلان غير جاهز للعرض، جاري تحميله...');
          await loadAd();
        } else {
          print('⚠️ جاري تحميل الإعلان بالفعل');
        }

        // انتظار لحظة للتحميل
        await Future.delayed(Duration(milliseconds: 300));

        // تحقق مرة أخرى
        if (!_isAdLoaded || _appOpenAd == null) {
          print('⚠️ لا يزال الإعلان غير جاهز بعد محاولة التحميل');
          return false;
        }
      }

      try {
        print('🎬 جاري عرض إعلان الفتح...');
        await _appOpenAd!.show();
        _isShowingAd = true;
        print('✅ تم عرض إعلان الفتح');
        return true;
      } catch (e) {
        print('❌ خطأ في عرض إعلان الفتح: $e');
        _isShowingAd = false;
        _isAdLoaded = false;
        _appOpenAd = null;

        // إعادة تحميل الإعلان بعد فشل العرض
        loadAd();

        return false;
      }
    } catch (e) {
      print('❌ خطأ عام في عرض إعلان الفتح: $e');
      return false;
    }
  }

  // دالة محسنة للتحقق مما إذا كان يجب عرض الإعلان
  Future<bool> showAdIfFirstOpen() async {
    if (!_isFirstOpen) {
      print('⚠️ ليست المرة الأولى لفتح التطبيق، لن يتم عرض الإعلان');
      return false;
    }

    // انتظار تحميل الإعلان إذا لم يكن جاهزاً
    if (!_isAdLoaded) {
      print('⏳ الإعلان غير جاهز، انتظار التحميل...');
      bool loaded = await waitForAdToLoad();
      if (!loaded) {
        print('❌ انتهت مهلة انتظار تحميل الإعلان');
        _isFirstOpen = false; // تعيين المتغير حتى في حالة الفشل
        return false;
      }
    }

    // تعيين المتغير إلى false بعد المرة الأولى
    _isFirstOpen = false;

    // عرض الإعلان إذا كان متاحًا
    return await showAdIfAvailable();
  }

  // دالة لإعادة تعيين حالة الفتح الأول (تستخدم عند إغلاق التطبيق تمامًا)
  void resetFirstOpenState() {
    _isFirstOpen = true;
    print('🔄 تم إعادة تعيين حالة الفتح الأول');
  }

  // دالة للتحقق من حالة الإعلان
  bool get isAdLoaded => _isAdLoaded;
  bool get isShowingAd => _isShowingAd;
  bool get isLoadingAd => _isLoadingAd;

  // دالة للتخلص من الإعلان عند إغلاق التطبيق
  Future<void> dispose() async {
    if (_appOpenAd != null) {
      await _appOpenAd!.dispose();
      _appOpenAd = null;
      _isAdLoaded = false;
      _isShowingAd = false;
      _isLoadingAd = false;
    }
    print('🧹 تم التخلص من AppOpenAdService');
  }
}
