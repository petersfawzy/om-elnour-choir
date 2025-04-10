import 'package:flutter/material.dart';
import 'package:om_elnour_choir/services/remote_config_service.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';

class BackgroundContainer extends StatelessWidget {
  final Widget child;
  final bool useScaffold;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  const BackgroundContainer({
    Key? key,
    required this.child,
    this.useScaffold = true,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final remoteConfig = RemoteConfigService();

    // التحقق من استخدام صورة كخلفية
    final useBackgroundImage = remoteConfig.useBackgroundImage();
    final backgroundImageUrl = remoteConfig.getBackgroundImageUrl();
    final overlayImageUrl = remoteConfig.getOverlayImageUrl();
    final overlayOpacity = remoteConfig.getOverlayOpacity();

    // إنشاء محتوى الخلفية
    Widget content = child;

    // إذا كان هناك صورة طبقة علوية
    if (overlayImageUrl.isNotEmpty) {
      content = Stack(
        children: [
          // المحتوى الأساسي
          content,

          // صورة الطبقة العلوية
          Positioned.fill(
            child: Opacity(
              opacity: overlayOpacity,
              child: Image.network(
                overlayImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('❌ خطأ في تحميل صورة الطبقة العلوية: $error');
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      );
    }

    // إذا كان استخدام صورة كخلفية وهناك رابط صورة
    if (useBackgroundImage && backgroundImageUrl.isNotEmpty) {
      // استخدام صورة كخلفية
      content = Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(backgroundImageUrl),
            fit: BoxFit.cover,
            // إضافة طبقة سوداء شفافة فوق الصورة لتحسين قراءة النص
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.3),
              BlendMode.darken,
            ),
          ),
        ),
        child: content,
      );
    }

    // إذا كان استخدام Scaffold
    if (useScaffold) {
      return Scaffold(
        backgroundColor:
            useBackgroundImage ? Colors.transparent : AppColors.backgroundColor,
        appBar: appBar,
        body: content,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
      );
    }

    // إذا لم يكن استخدام Scaffold
    return content;
  }
}
