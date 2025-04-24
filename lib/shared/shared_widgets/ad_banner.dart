import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../services/MyAudioService.dart';

class AdBanner extends StatefulWidget {
  final String cacheKey; // معرف للتمييز بين الإعلانات المختلفة
  final MyAudioService? audioService; // إضافة معلمة audioService

  const AdBanner(
      {Key? key, required this.cacheKey, this.audioService // جعلها اختيارية
      })
      : super(key: key);

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;
  bool _disposed = false;
  bool _adLoadFailed = false; // إضافة متغير لتتبع فشل تحميل الإعلان

  // إنشاء معرف فريد عند إنشاء الحالة وليس عند تهيئة المتغير
  late final String _uniqueId;

  // إضافة متغير لتتبع محاولات تحميل الإعلان
  int _loadAttempts = 0;
  static const int _maxAttempts = 3;

  // إضافة متغير لتتبع مهلة تحميل الإعلان
  Timer? _adLoadTimeoutTimer;

  @override
  void initState() {
    super.initState();

    // إنشاء معرف فريد عند إنشاء الحالة وليس عند تهيئة المتغير
    _uniqueId = '${widget.cacheKey}_${DateTime.now().millisecondsSinceEpoch}';

    // جدولة هذا ليتم تشغيله بعد عرض الإطار الأول
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;

      // حفظ حالة التشغيل قبل تحميل الإعلان إذا كان audioService متاحًا
      if (widget.audioService != null) {
        widget.audioService!.savePlaybackState();
      }

      // تحميل الإعلان
      if (mounted && !_isAdLoading && !_isAdLoaded) {
        _loadBannerAd();
      }
    });
  }

  @override
  void didUpdateWidget(AdBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    // إذا تغير cacheKey، نعيد تحميل الإعلان
    if (oldWidget.cacheKey != widget.cacheKey) {
      _disposeCurrentAd();
      if (mounted && !_isAdLoading && !_disposed) {
        _loadBannerAd();
      }
    }
  }

  void _disposeCurrentAd() {
    if (_bannerAd != null) {
      try {
        _bannerAd!.dispose();
      } catch (e) {
        print('❌ خطأ في التخلص من الإعلان الحالي: $e');
      }
      _bannerAd = null;
      _isAdLoaded = false;
    }

    // إلغاء مؤقت المهلة إذا كان موجودًا
    _adLoadTimeoutTimer?.cancel();
    _adLoadTimeoutTimer = null;
  }

  @override
  void dispose() {
    _disposed = true;

    try {
      _disposeCurrentAd();

      // استئناف التشغيل بعد التخلص من الإعلان بشكل آمن
      if (widget.audioService != null) {
        // استخدام Future.microtask بدلاً من تنفيذ مباشر
        Future.microtask(() {
          try {
            widget.audioService!.resumePlaybackAfterNavigation();
          } catch (e) {
            print('❌ خطأ في استئناف التشغيل بعد التخلص من الإعلان: $e');
          }
        });
      }
    } catch (e) {
      print('❌ خطأ في dispose للإعلان: $e');
    }

    super.dispose();
  }

  // تعديل دالة _loadBannerAd لتحسين التعامل مع الأخطاء
  void _loadBannerAd() {
    if (_isAdLoading ||
        _isAdLoaded ||
        !mounted ||
        _disposed ||
        _loadAttempts >= _maxAttempts) return;

    _isAdLoading = true;
    _adLoadFailed = false; // إعادة تعيين حالة فشل التحميل عند بدء محاولة جديدة

    try {
      final String adUnitId = Platform.isAndroid
          ? 'ca-app-pub-3343409547143147/6995481163'
          : 'ca-app-pub-3343409547143147/8298159747';

      print('🔄 جاري تحميل إعلان البانر: $_uniqueId');

      // إضافة مهلة زمنية لتحميل الإعلان (10 ثوانٍ)
      _adLoadTimeoutTimer = Timer(Duration(seconds: 10), () {
        if (!_isAdLoaded && !_disposed) {
          print('⚠️ انتهت مهلة تحميل الإعلان: $_uniqueId');
          _isAdLoading = false;

          if (mounted) {
            setState(() {
              _adLoadFailed = true; // تعيين حالة فشل التحميل
            });
          }

          // زيادة عدد المحاولات
          _loadAttempts++;

          // استئناف التشغيل بعد انتهاء المهلة
          if (widget.audioService != null && !_disposed) {
            try {
              widget.audioService!.resumePlaybackAfterNavigation();
            } catch (e) {
              print(
                  '❌ خطأ في استئناف التشغيل بعد انتهاء مهلة تحميل الإعلان: $e');
            }
          }

          // إعادة تحميل الإعلان إذا لم نصل للحد الأقصى من المحاولات
          if (_loadAttempts < _maxAttempts && mounted && !_disposed) {
            Future.delayed(Duration(seconds: 2), () {
              if (mounted && !_disposed && !_isAdLoaded) {
                _loadBannerAd();
              }
            });
          }
        }
      });

      final bannerAd = BannerAd(
        adUnitId: adUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            print('✅ تم تحميل إعلان البانر بنجاح: $_uniqueId');

            // إلغاء مؤقت المهلة
            _adLoadTimeoutTimer?.cancel();
            _adLoadTimeoutTimer = null;

            if (mounted && !_disposed) {
              setState(() {
                _bannerAd = ad as BannerAd;
                _isAdLoaded = true;
                _isAdLoading = false;
                _adLoadFailed = false; // إعادة تعيين حالة فشل التحميل
                _loadAttempts = 0; // إعادة تعيين عدد المحاولات عند النجاح
              });
            } else {
              // إذا تم التخلص من الحالة، تخلص من الإعلان
              ad.dispose();
            }

            // استئناف التشغيل بعد تحميل الإعلان
            if (widget.audioService != null && !_disposed) {
              try {
                widget.audioService!.resumePlaybackAfterNavigation();
              } catch (e) {
                print('❌ خطأ في استئناف التشغيل بعد تحميل الإعلان: $e');
              }
            }
          },
          onAdFailedToLoad: (ad, error) {
            print('❌ فشل تحميل إعلان البانر: $error - $_uniqueId');
            ad.dispose();

            // إلغاء مؤقت المهلة
            _adLoadTimeoutTimer?.cancel();
            _adLoadTimeoutTimer = null;

            if (mounted) {
              setState(() {
                _isAdLoading = false;
                _adLoadFailed = true; // تعيين حالة فشل التحميل
              });
            }

            // زيادة عدد المحاولات
            _loadAttempts++;

            if (_loadAttempts < _maxAttempts && mounted && !_disposed) {
              // محاولة إعادة التحميل بعد تأخير
              // استخدام تأخير تصاعدي (exponential backoff)
              final retryDelay =
                  Duration(seconds: 1 << _loadAttempts); // 2^attempts seconds
              print(
                  '🔄 إعادة محاولة تحميل الإعلان بعد ${retryDelay.inSeconds} ثانية (محاولة $_loadAttempts من $_maxAttempts)');

              Future.delayed(retryDelay, () {
                if (mounted && !_disposed && !_isAdLoaded) {
                  _loadBannerAd();
                }
              });
            }

            // استئناف التشغيل حتى في حالة فشل تحميل الإعلان
            if (widget.audioService != null && !_disposed) {
              try {
                widget.audioService!.resumePlaybackAfterNavigation();
              } catch (e) {
                print('❌ خطأ في استئناف التشغيل بعد فشل تحميل الإعلان: $e');
              }
            }
          },
        ),
      );

      bannerAd.load();
    } catch (e) {
      print('❌ خطأ أثناء إنشاء إعلان البانر: $e - $_uniqueId');

      // إلغاء مؤقت المهلة
      _adLoadTimeoutTimer?.cancel();
      _adLoadTimeoutTimer = null;

      if (mounted) {
        setState(() {
          _isAdLoading = false;
          _adLoadFailed = true; // تعيين حالة فشل التحميل
        });
      }

      _loadAttempts++;

      // استئناف التشغيل في حالة حدوث خطأ
      if (widget.audioService != null && !_disposed) {
        try {
          widget.audioService!.resumePlaybackAfterNavigation();
        } catch (e) {
          print('❌ خطأ في استئناف التشغيل بعد خطأ في تحميل الإعلان: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // إذا فشل تحميل الإعلان أو لم يتم تحميله بعد، نعيد حاوية بارتفاع صفر
    if (_bannerAd == null || !_isAdLoaded || _disposed || _adLoadFailed) {
      return SizedBox.shrink(); // حاوية بأبعاد صفرية
    }

    // إذا تم تحميل الإعلان بنجاح، نعرضه
    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
