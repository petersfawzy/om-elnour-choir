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

  // إنشاء معرف فريد عند إنشاء الحالة وليس عند تهيئة المتغير
  late final String _uniqueId;

  // إضافة متغير لتتبع محاولات تحميل الإعلان
  int _loadAttempts = 0;
  static const int _maxAttempts = 3;

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

    try {
      final String adUnitId = Platform.isAndroid
          ? 'ca-app-pub-3343409547143147/6995481163'
          : 'ca-app-pub-3343409547143147/8298159747';

      print('🔄 جاري تحميل إعلان البانر: $_uniqueId');

      final bannerAd = BannerAd(
        adUnitId: adUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            print('✅ تم تحميل إعلان البانر بنجاح: $_uniqueId');
            if (mounted && !_disposed) {
              setState(() {
                _bannerAd = ad as BannerAd;
                _isAdLoaded = true;
                _isAdLoading = false;
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
            _isAdLoading = false;

            // زيادة عدد المحاولات
            _loadAttempts++;

            if (_loadAttempts < _maxAttempts && mounted && !_disposed) {
              // محاولة إعادة التحميل بعد تأخير
              Future.delayed(Duration(seconds: 2), () {
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
      _isAdLoading = false;
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
    if (_bannerAd == null || !_isAdLoaded || _disposed) {
      // إرجاع حاوية بنفس الحجم لتجنب تغيير التخطيط
      return Container(
        width: 320, // عرض إعلان البانر القياسي
        height: 50, // ارتفاع إعلان البانر القياسي
        color: Colors.transparent,
      );
    }

    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
