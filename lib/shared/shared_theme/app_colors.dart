import 'package:flutter/material.dart';
import 'package:om_elnour_choir/services/remote_config_service.dart';

class AppColors {
  // مستمع للتغييرات في الألوان
  static final ValueNotifier<Color> backgroundColorNotifier =
      ValueNotifier<Color>(const Color(0xFF121212));
  static final ValueNotifier<Color> appAmberNotifier =
      ValueNotifier<Color>(const Color(0xFFFFC107));

  // الألوان الثابتة
  static const Color jeansColor = Color(0xFF1976D2);
  static const Color errorColor = Color(0xFFB00020);

  // الحصول على الألوان الديناميكية
  static Color get backgroundColor => backgroundColorNotifier.value;
  static Color get appamber => appAmberNotifier.value;

  // تحديث الألوان من التكوين عن بُعد
  static void updateFromRemoteConfig() {
    try {
      final remoteConfig = RemoteConfigService();

      // الحصول على الألوان من Remote Config
      final newBackgroundColor = remoteConfig.getBackgroundColor();
      final newAmberColor = remoteConfig.getAppAmberColor();

      print('🔄 تحديث الألوان:');
      print('- لون الخلفية: $newBackgroundColor');
      print('- لون الأمبر: $newAmberColor');

      // تحديث الألوان
      backgroundColorNotifier.value = newBackgroundColor;
      appAmberNotifier.value = newAmberColor;

      print('✅ تم تحديث الألوان بنجاح');
    } catch (e) {
      print('❌ خطأ في تحديث الألوان: $e');
    }
  }

  // تهيئة الألوان
  static void initialize() {
    try {
      final remoteConfig = RemoteConfigService();

      // تعيين الألوان الأولية
      backgroundColorNotifier.value = remoteConfig.getBackgroundColor();
      appAmberNotifier.value = remoteConfig.getAppAmberColor();

      print('✅ تم تهيئة الألوان:');
      print('- لون الخلفية: ${backgroundColorNotifier.value}');
      print('- لون الأمبر: ${appAmberNotifier.value}');

      // الاستماع للتغييرات في التكوين عن بُعد
      remoteConfig.configUpdated.addListener(() {
        updateFromRemoteConfig();
      });
    } catch (e) {
      print('❌ خطأ في تهيئة الألوان: $e');
    }
  }

  // دالة للتحقق من الألوان الحالية (للتصحيح)
  static void debugColors() {
    print('🔍 الألوان الحالية:');
    print(
        '- لون الخلفية: $backgroundColor (${backgroundColor.value.toRadixString(16)})');
    print('- لون الأمبر: $appamber (${appamber.value.toRadixString(16)})');
  }
}
