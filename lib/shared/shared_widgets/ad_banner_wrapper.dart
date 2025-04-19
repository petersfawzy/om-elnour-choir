import 'package:flutter/material.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner_manager.dart';

/// مغلف آمن للإعلانات
/// يتعامل مع دورة حياة الإعلان ويمنع المشاكل المرتبطة بإعادة الإنشاء
class AdBannerWrapper extends StatefulWidget {
  final String cacheKey;
  final MyAudioService? audioService;
  final double height;
  final bool respectLifecycle;

  const AdBannerWrapper({
    Key? key,
    required this.cacheKey,
    this.audioService,
    this.height = 50.0,
    this.respectLifecycle = true,
  }) : super(key: key);

  @override
  State<AdBannerWrapper> createState() => _AdBannerWrapperState();
}

class _AdBannerWrapperState extends State<AdBannerWrapper>
    with AutomaticKeepAliveClientMixin {
  // الحصول على مفتاح من مدير الإعلانات
  late final GlobalKey _adKey;
  // متغير للتحكم فيما إذا كان الإعلان مرئيًا
  bool _isVisible = true;
  // مرجع إلى مدير الإعلانات
  final AdBannerManager _adManager = AdBannerManager();
  // متغير لتتبع ما إذا كان الـ widget قد تم التخلص منه
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    // الحصول على مفتاح للإعلان
    _adKey = _adManager.getAdKey(widget.cacheKey);

    // حفظ حالة التشغيل قبل تحميل الإعلان
    if (widget.respectLifecycle && widget.audioService != null) {
      widget.audioService!.savePlaybackState();
    }
  }

  @override
  void didUpdateWidget(AdBannerWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);

    // إذا تغير cacheKey، نحصل على مفتاح جديد
    if (oldWidget.cacheKey != widget.cacheKey) {
      _adKey = _adManager.getAdKey(widget.cacheKey);
    }
  }

  @override
  void dispose() {
    _disposed = true;

    // استئناف التشغيل بعد التخلص من الإعلان بشكل آمن
    if (widget.respectLifecycle && widget.audioService != null) {
      // استخدام Future.microtask بدلاً من تنفيذ مباشر
      Future.microtask(() {
        try {
          widget.audioService!.resumePlaybackAfterNavigation();
        } catch (e) {
          print('❌ خطأ في استئناف التشغيل بعد التخلص من الإعلان: $e');
        }
      });
    }

    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // حاوية بارتفاع ثابت لمنع إعادة ترتيب العناصر
    return Container(
      height: widget.height,
      child: _isVisible
          ? AdBanner(
              key: _adKey,
              cacheKey: widget.cacheKey,
              audioService: widget.audioService,
            )
          : Container(
              color: Colors.transparent,
            ),
    );
  }

  // دالة للتحكم في ظهور الإعلان
  void setVisibility(bool isVisible) {
    if (mounted && !_disposed && _isVisible != isVisible) {
      setState(() {
        _isVisible = isVisible;
      });
    }
  }
}
