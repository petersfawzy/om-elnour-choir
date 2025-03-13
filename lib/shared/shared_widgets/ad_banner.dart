import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  _AdBannerState createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  static BannerAd? _bannerAd;
  static bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (_bannerAd == null) {
      // ✅ تأكد من عدم تحميل الإعلان أكثر من مرة
      _bannerAd = BannerAd(
        adUnitId: 'ca-app-pub-3940256099942544/6300978111',
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
            ad.dispose();
            debugPrint('❌ فشل تحميل الإعلان: $error');
          },
        ),
      );

      _bannerAd!.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isAdLoaded && _bannerAd != null
        ? SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          )
        : const SizedBox.shrink();
  }

  @override
  void dispose() {
    // ❌ لا نقوم بحذف الإعلان هنا لأنه static
    super.dispose();
  }
}
