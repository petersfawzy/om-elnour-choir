import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdBanner extends StatefulWidget {
  final bool showAd; // ✅ خيار للتحكم في عرض الإعلان

  const AdBanner({super.key, this.showAd = true});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.showAd) {
      _loadAd();
    }
  }

  void _loadAd() {
    if (_bannerAd != null) return; // ✅ تجنب تحميل الإعلان أكثر من مرة

    _bannerAd = BannerAd(
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-3343409547143147/6995481163' // إعلان Android
          : 'ca-app-pub-3343409547143147/8298159747', // إعلان iOS
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ فشل تحميل الإعلان: $error');
          ad.dispose(); // ✅ تحرير الموارد في حالة الفشل
          _bannerAd = null; // ✅ إعادة التهيئة لضمان تحميل جديد لاحقًا
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAd || !_isAdLoaded || _bannerAd == null) {
      return const SizedBox
          .shrink(); // ✅ عدم عرض أي شيء إذا لم يتم تحميل الإعلان
    }

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose(); // ✅ تجنب تسريبات الذاكرة
    super.dispose();
  }
}
