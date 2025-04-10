import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../services/MyAudioService.dart';

class AdBanner extends StatefulWidget {
  final String cacheKey; // معرف للتمييز بين الإعلانات المختلفة
  final MyAudioService? audioService; // إضافة معلمة audioService

  const AdBanner(
      {Key? key, this.cacheKey = 'default', this.audioService // جعلها اختيارية
      })
      : super(key: key);

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();

    // جدولة هذا ليتم تشغيله بعد عرض الإطار الأول
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // حفظ حالة التشغيل قبل تحميل الإعلان إذا كان audioService متاحًا
      if (widget.audioService != null) {
        widget.audioService!.savePlaybackState();

        // استئناف التشغيل فوراً لمنع المقاطعة
        widget.audioService!.resumePlaybackAfterNavigation();
      }

      // تحميل الإعلان
      _loadBannerAd();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();

    // استئناف التشغيل بعد التخلص من الإعلان
    Future.delayed(Duration(milliseconds: 100), () {
      if (!mounted && widget.audioService != null) {
        try {
          widget.audioService!.resumePlaybackAfterNavigation();
        } catch (e) {
          print('❌ خطأ في استئناف التشغيل بعد التخلص من الإعلان: $e');
        }
      }
    });

    super.dispose();
  }

  void _loadBannerAd() {
    final String adUnitId = Platform.isAndroid
        ? 'ca-app-pub-3343409547143147/6995481163'
        : 'ca-app-pub-3343409547143147/8298159747';

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('✅ تم تحميل إعلان البانر بنجاح');
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }

          // استئناف التشغيل بعد تحميل الإعلان
          if (widget.audioService != null) {
            widget.audioService!.resumePlaybackAfterNavigation();
          }
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ فشل تحميل إعلان البانر: $error');
          ad.dispose();

          // استئناف التشغيل حتى في حالة فشل تحميل الإعلان
          if (widget.audioService != null) {
            widget.audioService!.resumePlaybackAfterNavigation();
          }
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  Widget build(BuildContext context) {
    if (_bannerAd == null || !_isAdLoaded) {
      return const SizedBox(height: 50); // مساحة احتياطية للإعلان
    }

    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
