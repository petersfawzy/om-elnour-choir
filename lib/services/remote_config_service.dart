import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  // القيم الافتراضية
  static const String _keyBackgroundColor = 'app_background_color';
  static const String _keyAppAmberColor = 'app_amber_color';
  static const String _keyIntroLogo = 'intro_logo_url';
  static const String _keyIntroTitle = 'intro_title';
  static const String _keyIntroSubtitle = 'intro_subtitle';
  static const String _keyIntroVerse1 = 'intro_verse_1';
  static const String _keyIntroVerse2 = 'intro_verse_2';

  // إضافة مفاتيح جديدة لصور الخلفية
  static const String _keyBackgroundImageUrl = 'app_background_image_url';
  static const String _keyOverlayImageUrl = 'app_overlay_image_url';
  static const String _keyOverlayOpacity = 'app_overlay_opacity';
  static const String _keyUseBackgroundImage = 'app_use_background_image';
  static const String _keyIntroAnnouncement =
      'intro_announcement'; // مفتاح جديد للنص الإعلاني

  // إضافة مفاتيح جديدة لنص ورابط مشاركة الآية
  static const String _keyShareVerseText = 'share_verse_text';
  static const String _keyShareAppLink = 'share_app_link';

  // إضافة مفتاح جديد للون النص في حقول الإدخال
  static const String _keyInputTextColor = 'input_text_color';

  // وقت التحديث الأخير
  DateTime? _lastFetchTime;

  // مؤشر لمعرفة ما إذا كانت القيم قد تغيرت
  final ValueNotifier<bool> configUpdated = ValueNotifier<bool>(false);

  factory RemoteConfigService() {
    return _instance;
  }

  RemoteConfigService._internal();

  Future<void> initialize() async {
    try {
      // إعداد الخيارات بفترة تخزين مؤقت صفرية للتطوير
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(seconds: 0), // صفر للتطوير
      ));

      // تعيين القيم الافتراضية
      await _remoteConfig.setDefaults({
        _keyBackgroundColor: '#121212', // لون الخلفية الافتراضي
        _keyAppAmberColor: '#FFC107', // لون الأمبر الافتراضي
        _keyIntroLogo:
            '', // رابط الشعار الافتراضي (فارغ يعني استخدام الشعار المحلي)
        _keyIntroTitle: 'WELCOME TO',
        _keyIntroSubtitle: 'OM ELNOUR CHOIR',
        _keyIntroVerse1:
            'مُكَلِّمِينَ بَعْضُكُمْ بَعْضًا بِمَزَامِيرَ وَتَسَابِيحَ وَأَغَانِيَّ رُوحِيَّةٍ،',
        _keyIntroVerse2:
            'مُتَرَنِّمِينَ وَمُرَتِّلِينَ فِي قُلُوبِكُمْ لِلرَّبِّ." (أف ٥: ١٩).',
        _keyBackgroundImageUrl:
            '', // رابط صورة الخلفية (فارغ يعني عدم استخدام صورة)
        _keyOverlayImageUrl:
            '', // رابط صورة الطبقة العلوية (فارغ يعني عدم استخدام صورة)
        _keyOverlayOpacity: '0.3', // شفافية الطبقة العلوية (0.0 - 1.0)
        _keyUseBackgroundImage: 'false', // استخدام صورة كخلفية بدلاً من اللون
        _keyIntroAnnouncement:
            '', // النص الإعلاني في أعلى الشاشة (فارغ يعني عدم عرض أي نص)
        _keyShareVerseText:
            'حمل تطبيق كورال أم النور:', // النص الافتراضي لمشاركة الآية
        _keyShareAppLink:
            'https://get-tap.app/om.elnour.choir', // الرابط الافتراضي للتطبيق
        _keyInputTextColor:
            '#FFFFFF', // اللون الافتراضي للنص في حقول الإدخال (أبيض)
      });

      // جلب القيم من Firebase
      await fetchAndActivate();

      // حفظ القيم في التخزين المحلي للاستخدام في حالة عدم الاتصال
      await _saveConfigToLocal();

      print('✅ تم تهيئة خدمة التكوين عن بُعد بنجاح');
    } catch (e) {
      print('❌ خطأ في تهيئة خدمة التكوين عن بُعد: $e');
      // استعادة القيم من التخزين المحلي في حالة الفشل
      await _loadConfigFromLocal();
    }
  }

  // إضافة دالة refresh كواجهة لـ fetchAndActivate
  Future<bool> refresh() async {
    print('🔄 جاري تحديث التكوين عن بُعد...');

    try {
      // إعادة تعيين minimumFetchInterval إلى 0 لضمان التحديث الفوري
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(seconds: 0),
      ));

      // محاولة مسح ذاكرة التخزين المؤقت
      try {
        // هذه الطريقة قد لا تكون متاحة في جميع إصدارات Firebase
        // لذلك نضعها في كتلة try-catch منفصلة
        await _remoteConfig.ensureInitialized();
      } catch (e) {
        print('⚠️ لا يمكن استدعاء ensureInitialized: $e');
      }

      // استخدام fetchAndActivate بدلاً من fetch و activate منفصلين
      bool updated = await _remoteConfig.fetchAndActivate();

      if (updated) {
        print('✅ تم جلب وتفعيل القيم الجديدة من Firebase');
      } else {
        print('⚠️ لم يتم تحديث أي قيم جديدة من Firebase');

        // محاولة إضافية لجلب القيم
        print('🔄 محاولة إضافية لجلب القيم...');
        await _remoteConfig.fetch();
        updated = await _remoteConfig.activate();

        if (updated) {
          print('✅ تم تحديث القيم في المحاولة الإضافية');
        } else {
          print('⚠️ فشلت المحاولة الإضافية أيضًا');
        }
      }

      // طباعة جميع القيم المجلوبة للتصحيح
      print('📊 القيم المجلوبة من Remote Config:');
      print(
          'app_background_color: ${_remoteConfig.getString(_keyBackgroundColor)}');
      print('app_amber_color: ${_remoteConfig.getString(_keyAppAmberColor)}');
      print('input_text_color: ${_remoteConfig.getString(_keyInputTextColor)}');

      // طباعة جميع القيم المتاحة في Remote Config
      print('📋 جميع القيم المتاحة في Remote Config:');
      final allKeys = _remoteConfig.getAll().keys;
      for (final key in allKeys) {
        print('$key: ${_remoteConfig.getString(key)}');
      }

      // حفظ القيم في التخزين المحلي
      await _saveConfigToLocal();

      // إشعار المستمعين بتحديث القيم
      configUpdated.value = !configUpdated.value;

      return updated;
    } catch (e) {
      print('❌ خطأ في تحديث التكوين عن بُعد: $e');
      return false;
    }
  }

  Future<bool> fetchAndActivate() async {
    try {
      // جلب القيم من Firebase
      bool updated = await _remoteConfig.fetchAndActivate();
      _lastFetchTime = DateTime.now();

      // طباعة القيم للتصحيح
      print('🔄 تم تحديث التكوين عن بعد:');
      print('app_amber_color: ${_remoteConfig.getString(_keyAppAmberColor)}');
      print(
          'app_background_color: ${_remoteConfig.getString(_keyBackgroundColor)}');
      print('input_text_color: ${_remoteConfig.getString(_keyInputTextColor)}');

      // حفظ القيم في التخزين المحلي
      await _saveConfigToLocal();

      // إشعار المستمعين بتحديث القيم
      configUpdated.value = !configUpdated.value;

      print('✅ تم تحديث التكوين عن بُعد بنجاح');
      return updated;
    } catch (e) {
      print('❌ خطأ في تحديث التكوين عن بُعد: $e');
      return false;
    }
  }

  // حفظ القيم في التخزين المحلي
  Future<void> _saveConfigToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configMap = {
        _keyBackgroundColor: _remoteConfig.getString(_keyBackgroundColor),
        _keyAppAmberColor: _remoteConfig.getString(_keyAppAmberColor),
        _keyIntroLogo: getIntroLogoUrl(),
        _keyIntroTitle: getIntroTitle(),
        _keyIntroSubtitle: getIntroSubtitle(),
        _keyIntroVerse1: getIntroVerse1(),
        _keyIntroVerse2: getIntroVerse2(),
        _keyBackgroundImageUrl: getBackgroundImageUrl(),
        _keyOverlayImageUrl: getOverlayImageUrl(),
        _keyOverlayOpacity: getOverlayOpacity().toString(),
        _keyUseBackgroundImage: useBackgroundImage().toString(),
        _keyIntroAnnouncement: getIntroAnnouncement(),
        _keyShareVerseText: getShareVerseText(),
        _keyShareAppLink: getShareAppLink(),
        _keyInputTextColor: _remoteConfig.getString(_keyInputTextColor),
        'lastFetchTime': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString('remote_config', jsonEncode(configMap));
      print('✅ تم حفظ التكوين في التخزين المحلي');
    } catch (e) {
      print('❌ خطأ في حفظ التكوين في التخزين المحلي: $e');
    }
  }

  // استعادة القيم من التخزين المحلي
  Future<void> _loadConfigFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('remote_config');

      if (configJson != null) {
        final configMap = jsonDecode(configJson) as Map<String, dynamic>;

        // تحديث وقت آخر جلب
        if (configMap.containsKey('lastFetchTime')) {
          _lastFetchTime = DateTime.fromMillisecondsSinceEpoch(
              configMap['lastFetchTime'] as int);
        }

        // No necesitamos hacer nada especial aquí, ya que los valores se cargarán
        // cuando se llame a los métodos getter correspondientes
        print(
            '📝 تم العثور على قيم التكوين المخزنة: ${configMap.keys.join(', ')}');
      }
    } catch (e) {
      print('❌ خطأ في استعادة التكوين من التخزين المحلي: $e');
    }
  }

  // الحصول على لون الخلفية
  Color getBackgroundColor() {
    final colorHex = _remoteConfig.getString(_keyBackgroundColor);
    print('🎨 قيمة لون الخلفية من Remote Config: $colorHex');
    return _hexToColor(colorHex, defaultColor: const Color(0xFF121212));
  }

  // الحصول على لون الأمبر
  Color getAppAmberColor() {
    final colorHex = _remoteConfig.getString(_keyAppAmberColor);
    print('🎨 قيمة لون الأمبر من Remote Config: $colorHex');
    return _hexToColor(colorHex, defaultColor: const Color(0xFFFFC107));
  }

  // الحصول على لون النص في حقول الإدخال
  Color getInputTextColor() {
    final colorHex = _remoteConfig.getString(_keyInputTextColor);
    print('🎨 قيمة لون النص في حقول الإدخال من Remote Config: $colorHex');
    return _hexToColor(colorHex, defaultColor: Colors.white);
  }

  // الحصول على رابط شعار شاشة المقدمة
  String getIntroLogoUrl() {
    return _remoteConfig.getString(_keyIntroLogo);
  }

  // الحصول على عنوان شاشة المقدمة
  String getIntroTitle() {
    return _remoteConfig.getString(_keyIntroTitle);
  }

  // الحصول على العنوان الفرعي لشاشة المقدمة
  String getIntroSubtitle() {
    return _remoteConfig.getString(_keyIntroSubtitle);
  }

  // الحصول على الآية الأولى
  String getIntroVerse1() {
    return _remoteConfig.getString(_keyIntroVerse1);
  }

  // الحصول على الآية الثانية
  String getIntroVerse2() {
    return _remoteConfig.getString(_keyIntroVerse2);
  }

  // الحصول على رابط صورة الخلفية
  String getBackgroundImageUrl() {
    return _remoteConfig.getString(_keyBackgroundImageUrl);
  }

  // الحصول على رابط صورة الطبقة العلوية
  String getOverlayImageUrl() {
    return _remoteConfig.getString(_keyOverlayImageUrl);
  }

  // الحصول على شفافية الطبقة العلوية
  double getOverlayOpacity() {
    final opacityStr = _remoteConfig.getString(_keyOverlayOpacity);
    try {
      final opacity = double.parse(opacityStr);
      return opacity.clamp(0.0, 1.0);
    } catch (e) {
      return 0.3; // القيمة الافتراضية
    }
  }

  // التحقق من استخدام صورة كخلفية
  bool useBackgroundImage() {
    final useImageStr = _remoteConfig.getString(_keyUseBackgroundImage);
    return useImageStr.toLowerCase() == 'true';
  }

  // دالة للحصول على النص الإعلاني
  String getIntroAnnouncement() {
    return _remoteConfig.getString(_keyIntroAnnouncement);
  }

  // دالة للحصول على نص مشاركة الآية
  String getShareVerseText() {
    return _remoteConfig.getString(_keyShareVerseText);
  }

  // دالة للحصول على رابط التطبيق للمشاركة
  String getShareAppLink() {
    return _remoteConfig.getString(_keyShareAppLink);
  }

  // تحويل اللون من صيغة hex إلى Color
  Color _hexToColor(String hexColor, {required Color defaultColor}) {
    try {
      // تنظيف سلسلة اللون
      hexColor = hexColor.trim();

      // التحقق من وجود علامة #
      if (!hexColor.startsWith('#')) {
        print('⚠️ سلسلة اللون لا تبدأ بـ #: $hexColor');
        return defaultColor;
      }

      // إزالة علامة #
      hexColor = hexColor.replaceAll('#', '');

      // التحقق من طول سلسلة اللون
      if (hexColor.length != 6 && hexColor.length != 8) {
        print(
            '⚠️ طول سلسلة اللون غير صحيح: $hexColor (الطول: ${hexColor.length})');
        return defaultColor;
      }

      // إضافة قناة ألفا إذا لم تكن موجودة
      if (hexColor.length == 6) {
        hexColor = 'FF' + hexColor;
      }

      // تحويل السلسلة إلى عدد صحيح
      final colorValue = int.parse(hexColor, radix: 16);

      // إنشاء كائن Color
      final color = Color(colorValue);
      print('✅ تم تحويل اللون بنجاح: $hexColor -> $color');
      return color;
    } catch (e) {
      print('❌ خطأ في تحويل اللون: $e، القيمة: $hexColor');
      return defaultColor;
    }
  }

  // التحقق من الحاجة للتحديث
  bool needsUpdate() {
    if (_lastFetchTime == null) return true;
    final now = DateTime.now();
    return now.difference(_lastFetchTime!).inHours >= 1;
  }

  // دالة للحصول على جميع قيم التكوين (للتصحيح)
  Map<String, dynamic> getAllConfigValues() {
    return {
      'app_background_color': _remoteConfig.getString(_keyBackgroundColor),
      'app_amber_color': _remoteConfig.getString(_keyAppAmberColor),
      'intro_logo_url': _remoteConfig.getString(_keyIntroLogo),
      'intro_title': _remoteConfig.getString(_keyIntroTitle),
      'intro_subtitle': _remoteConfig.getString(_keyIntroSubtitle),
      'intro_verse_1': _remoteConfig.getString(_keyIntroVerse1),
      'intro_verse_2': _remoteConfig.getString(_keyIntroVerse2),
      'app_background_image_url':
          _remoteConfig.getString(_keyBackgroundImageUrl),
      'app_overlay_image_url': _remoteConfig.getString(_keyOverlayImageUrl),
      'app_overlay_opacity': _remoteConfig.getString(_keyOverlayOpacity),
      'app_use_background_image':
          _remoteConfig.getString(_keyUseBackgroundImage),
      'intro_announcement': _remoteConfig.getString(_keyIntroAnnouncement),
      'share_verse_text': _remoteConfig.getString(_keyShareVerseText),
      'share_app_link': _remoteConfig.getString(_keyShareAppLink),
      'input_text_color': _remoteConfig.getString(_keyInputTextColor),
    };
  }
}
