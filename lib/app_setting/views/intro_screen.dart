import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:om_elnour_choir/app_setting/views/home_screen.dart';
import 'package:om_elnour_choir/user/views/login_screen.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:om_elnour_choir/services/remote_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:om_elnour_choir/services/app_open_ad_service.dart'; // Import the AppOpenAdService

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with WidgetsBindingObserver {
  bool _isCheckingUpdate = false;
  // إضافة متغير للتحكم في وضع الاختبار
  final bool _isTestingMode = false; // تغيير إلى false لإيقاف رسائل الاختبار
  bool _isNavigating = false; // متغير لتتبع حالة الانتقال
  bool _isConfigLoaded = false; // متغير لتتبع حالة تحميل التكوين
  bool _isLogoLoaded = false; // متغير جديد لتتبع حالة تحميل الشعار
  bool _isUpdateCheckComplete = false; // متغير جديد لتتبع اكتمال فحص التحديثات
  String _introAnnouncement = ''; // متغير جديد للنص الإعلاني

  // إضافة متغير للتحكم في مدة ظهور الشاشة
  final int _minimumDisplayTimeSeconds =
      8; // الحد الأدنى لمدة ظهور الشاشة بالثواني
  DateTime? _screenLoadTime; // وقت تحميل الشاشة

  // إضافة خدمة Remote Config
  final RemoteConfigService _remoteConfigService = RemoteConfigService();
  final AppOpenAdService appOpenAdService =
      AppOpenAdService(); // Create an instance of AppOpenAdService

  // متغيرات لتخزين قيم Remote Config
  String? _logoUrl;
  String _introTitle = 'WELCOME TO';
  String _introSubtitle = 'OM ELNOUR CHOIR';
  String _introVerse1 =
      'مُكَلِّمِينَ بَعْضُكُمْ بَعْضًا بِمَزَامِيرَ وَتَسَابِيحَ وَأَغَانِيَّ رُوحِيَّةٍ،';
  String _introVerse2 =
      'مُتَرَنِّمِينَ وَمُرَتِّلِينَ فِي قُلُوبِكُمْ لِلرَّبِّ." (أف ٥: ١٩).';

  // معلومات التطبيق
  final String _appStoreId = '1660609952'; // معرف تطبيقك على App Store
  final String _packageName =
      'com.egypt.redcherry.omelnourchoir'; // اسم حزمة تطبيقك

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screenLoadTime = DateTime.now();

    // تأخير تحميل التكوين والتحقق من التحديثات
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        _loadCachedConfig();
        _loadRemoteConfig();
        _checkForUpdates();
      }
    });

    // تأخير تحميل إعلان الفتح
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        try {
          appOpenAdService.loadAd();
        } catch (e) {
          print('❌ خطأ في تحميل إعلان الفتح: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    print('🧹 تم التخلص من IntroScreen');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('🔄 تغيرت حالة دورة حياة التطبيق في IntroScreen: $state');

    if (state == AppLifecycleState.resumed) {
      // عند العودة من الخلفية
      print("📱 IntroScreen: التطبيق عاد من الخلفية");
    } else if (state == AppLifecycleState.paused) {
      print('📱 IntroScreen: التطبيق في الخلفية');
    }
  }

  // دالة جديدة للتحقق من تحميل جميع الموارد
  void _checkAllResourcesLoaded() {
    if (_isNavigating) return;

    print('🔍 التحقق من حالة تحميل الموارد:');
    print('- تحميل التكوين: $_isConfigLoaded');
    print('- تحميل الشعار: $_isLogoLoaded');
    print('- اكتمال فحص التحديثات: $_isUpdateCheckComplete');

    // التحقق من الوقت المنقضي منذ تحميل الشاشة
    final elapsedSeconds =
        DateTime.now().difference(_screenLoadTime!).inSeconds;
    print('⏱️ الوقت المنقضي منذ تحميل الشاشة: $elapsedSeconds ثانية');

    // إذا لم تكتمل جميع العمليات، ننتظر ثانية إضافية ونحاول مرة أخرى
    if (!_isConfigLoaded || !_isUpdateCheckComplete || !_isLogoLoaded) {
      print('⏳ لم تكتمل جميع العمليات بعد، سيتم إعادة المحاولة بعد ثانية...');
      Future.delayed(Duration(seconds: 1), () {
        if (mounted && !_isNavigating) {
          _checkAllResourcesLoaded();
        }
      });
      return;
    }

    // التحقق من الحد الأدنى للوقت
    if (elapsedSeconds < _minimumDisplayTimeSeconds) {
      final remainingSeconds = _minimumDisplayTimeSeconds - elapsedSeconds;
      print(
          '⏳ لم يتم الوصول إلى الحد الأدنى للوقت، الانتظار لـ $remainingSeconds ثانية إضافية...');
      Future.delayed(Duration(seconds: remainingSeconds), () {
        if (mounted && !_isNavigating) {
          _checkLoginStatus();
        }
      });
    } else {
      print(
          '✅ اكتملت جميع العمليات والوقت كافٍ، جاري التحقق من حالة تسجيل الدخول...');
      _checkLoginStatus();
    }
  }

  // تحميل التكوين المخزن مؤقتًا
  Future<void> _loadCachedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedLogoUrl = prefs.getString('cached_logo_url');
      final cachedTitle = prefs.getString('cached_intro_title');
      final cachedSubtitle = prefs.getString('cached_intro_subtitle');
      final cachedVerse1 = prefs.getString('cached_intro_verse1');
      final cachedVerse2 = prefs.getString('cached_intro_verse2');
      final cachedAnnouncement =
          prefs.getString('cached_intro_announcement'); // إضافة هنا

      if (mounted) {
        setState(() {
          if (cachedLogoUrl != null && cachedLogoUrl.isNotEmpty) {
            _logoUrl = cachedLogoUrl;
            print('✅ تم تحميل رابط الشعار من التخزين المؤقت: $_logoUrl');
          }

          if (cachedTitle != null && cachedTitle.isNotEmpty) {
            _introTitle = cachedTitle;
          }

          if (cachedSubtitle != null && cachedSubtitle.isNotEmpty) {
            _introSubtitle = cachedSubtitle;
          }

          if (cachedVerse1 != null && cachedVerse1.isNotEmpty) {
            _introVerse1 = cachedVerse1;
          }

          if (cachedVerse2 != null && cachedVerse2.isNotEmpty) {
            _introVerse2 = cachedVerse2;
          }

          // تحميل النص الإعلاني من التخزين المؤقت
          if (cachedAnnouncement != null && cachedAnnouncement.isNotEmpty) {
            _introAnnouncement = cachedAnnouncement;
            print(
                '✅ تم تحميل النص الإعلاني من التخزين المؤقت: $_introAnnouncement');
          }
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل التكوين المخزن مؤقتًا: $e');
    }
  }

// تعديل دالة _loadRemoteConfig لتحميل النص الإعلاني
  Future<void> _loadRemoteConfig() async {
    try {
      // محاولة تحديث Remote Config
      await _remoteConfigService.refresh();

      // الحصول على القيم
      final logoUrl = _remoteConfigService.getIntroLogoUrl();
      final introTitle = _remoteConfigService.getIntroTitle();
      final introSubtitle = _remoteConfigService.getIntroSubtitle();
      final introVerse1 = _remoteConfigService.getIntroVerse1();
      final introVerse2 = _remoteConfigService.getIntroVerse2();
      final introAnnouncement =
          _remoteConfigService.getIntroAnnouncement(); // إضافة هنا

      // طباعة القيم للتصحيح
      print('📊 قيم Remote Config:');
      print('- رابط الشعار: $logoUrl');
      print('- العنوان: $introTitle');
      print('- العنوان الفرعي: $introSubtitle');
      print('- الآية 1: $introVerse1');
      print('- الآية 2: $introVerse2');
      print('- النص الإعلاني: $introAnnouncement'); // إضافة هنا

      // تخزين القيم في التخزين المؤقت
      final prefs = await SharedPreferences.getInstance();

      // إذا كان رابط الشعار فارغًا، امسح القيمة المخزنة مؤقتًا
      if (logoUrl.isEmpty) {
        await prefs.remove('cached_logo_url');
        print('🧹 تم مسح رابط الشعار المخزن مؤقتًا للعودة إلى الشعار الأصلي');
      } else {
        await prefs.setString('cached_logo_url', logoUrl);
      }

      // تخزين باقي القيم
      if (introTitle.isNotEmpty) {
        await prefs.setString('cached_intro_title', introTitle);
      }
      if (introSubtitle.isNotEmpty) {
        await prefs.setString('cached_intro_subtitle', introSubtitle);
      }
      if (introVerse1.isNotEmpty) {
        await prefs.setString('cached_intro_verse1', introVerse1);
      }
      if (introVerse2.isNotEmpty) {
        await prefs.setString('cached_intro_verse2', introVerse2);
      }
      // تخزين النص الإعلاني
      await prefs.setString('cached_intro_announcement', introAnnouncement);

      // تحديث الحالة
      if (mounted) {
        setState(() {
          _isConfigLoaded = true;
          // إذا كان رابط الشعار فارغًا، اجعل _logoUrl فارغًا للعودة إلى الشعار الأصلي
          _logoUrl = logoUrl.isEmpty ? null : logoUrl;

          if (introTitle.isNotEmpty) {
            _introTitle = introTitle;
          }
          if (introSubtitle.isNotEmpty) {
            _introSubtitle = introSubtitle;
          }
          if (introVerse1.isNotEmpty) {
            _introVerse1 = introVerse1;
          }
          if (introVerse2.isNotEmpty) {
            _introVerse2 = introVerse2;
          }
          // تحديث النص الإعلاني
          _introAnnouncement = introAnnouncement;
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل Remote Config: $e');
      // تعيين حالة تحميل التكوين حتى في حالة الخطأ
      if (mounted) {
        setState(() {
          _isConfigLoaded = true;
        });
      }
    }
  }

  // التحقق من وجود تحديثات
  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdate || _isNavigating) return;

    if (mounted) {
      setState(() {
        _isCheckingUpdate = true;
      });
    }

    try {
      print('🔄 جاري التحقق من وجود تحديثات...');

      // الحصول على معلومات الإصدار الحالي
      final packageInfo = await PackageInfo.fromPlatform();
      print(
          '📱 إصدار التطبيق الحالي: ${packageInfo.version} (${packageInfo.buildNumber})');

      // في بيئة التطوير، نستخدم وضع الاختبار فقط ونتخطى التحقق الفعلي من التحديثات
      bool isDevMode = true; // يمكن تغييرها لاحقًا للتحقق من بيئة التطوير

      if (mounted && isDevMode && _isTestingMode) {
        print(
            '🧪 وضع التطوير: تخطي التحقق الفعلي من التحديثات واستخدام وضع الاختبار');

        // عرض مربع حوار التحديث المناسب للنظام
        if (Platform.isAndroid) {
          _showAndroidUpdateDialog(immediate: false);
        } else if (Platform.isIOS) {
          _showIOSUpdateDialog();
        }
      } else if (mounted) {
        // التحقق من التحديثات بناءً على نظام التشغيل
        if (Platform.isAndroid && !isDevMode) {
          await _checkAndroidUpdates();
        } else if (Platform.isIOS) {
          await _checkIOSUpdates(packageInfo.version);
        }
      }
    } catch (e) {
      print('❌ خطأ عام في التحقق من التحديثات: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
          _isUpdateCheckComplete = true; // تعيين حالة اكتمال فحص التحديثات
        });

        // التحقق من إمكانية الانتقال بعد اكتمال فحص التحديثات
        _checkAllResourcesLoaded();
      }
    }
  }

  // تعديل دالة التحقق من تحديثات Android لمنع ظهور رسالتين
  Future<void> _checkAndroidUpdates() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      // طباعة معلومات التحديث للتشخيص
      print('📊 معلومات تحديث Android:');
      print('- توفر التحديث: ${updateInfo.updateAvailability}');
      print('- الإصدار المتاح: ${updateInfo.availableVersionCode}');

      // التحقق من وجود تحديث
      if (mounted &&
          updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        print('✅ يوجد تحديث متاح لـ Android');

        // استخدام آلية التحديث المرن المدمجة بدلاً من عرض مربع حوار مخصص
        try {
          // بدء التحديث المرن مباشرة بدون عرض مربع حوار مخصص
          await InAppUpdate.startFlexibleUpdate();
          if (mounted) {
            await InAppUpdate.completeFlexibleUpdate();
          }
        } catch (e) {
          print('❌ فشل في بدء التحديث المرن: $e');
          // إذا فشل التحديث المرن، نعرض مربع الحوار المخصص كخطة بديلة
          if (mounted) {
            _showAndroidUpdateDialog(immediate: false);
          }
        }
      } else {
        print('✅ تطبيق Android محدث بالفعل');
      }
    } catch (e) {
      print('❌ خطأ في التحقق من تحديثات Android: $e');
      print(
          '⚠️ هذا الخطأ متوقع في بيئة التطوير أو عندما يكون التطبيق غير مثبت من متجر Google Play');

      // في حالة الخطأ في بيئة التطوير، نعرض مربع الحوار المخصص فقط إذا كان وضع الاختبار مفعل
      if (_isTestingMode && mounted) {
        _showAndroidUpdateDialog(immediate: false);
      }
    }
  }

  // التحقق من تحديثات iOS
  Future<void> _checkIOSUpdates(String currentVersion) async {
    try {
      // في الإنتاج، يمكنك استخدام API لاسترداد أحدث إصدار من App Store
      // هنا نستخدم API iTunes للتحقق من أحدث إصدار
      final response = await http.get(
        Uri.parse('https://itunes.apple.com/lookup?id=$_appStoreId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['resultCount'] > 0) {
          final storeVersion = data['results'][0]['version'];
          print('📊 معلومات تحديث iOS:');
          print('- الإصدار الحالي: $currentVersion');
          print('- الإصدار المتاح في App Store: $storeVersion');

          // مقارنة الإصدارات (يمكن تحسين هذه المقارنة)
          if (_isNewerVersion(storeVersion, currentVersion)) {
            print('✅ يوجد تحديث متاح لـ iOS');
            if (mounted) {
              _showIOSUpdateDialog();
            }
          } else {
            print('✅ تطبيق iOS محدث بالفعل');
          }
        }
      } else {
        print('❌ فشل في الاتصال بـ iTunes API: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ خطأ في التحقق من تحديثات iOS: $e');

      // في وضع الاختبار، نعرض مربع حوار التحديث على أي حال
      if (_isTestingMode && mounted) {
        _showIOSUpdateDialog();
      }
    }
  }

  // مقارنة الإصدارات لمعرفة ما إذا كان الإصدار الجديد أحدث
  bool _isNewerVersion(String storeVersion, String currentVersion) {
    // تقسيم الإصدارات إلى أجزاء (مثال: 1.0.1 -> [1, 0, 1])
    List<int> storeVersionParts =
        storeVersion.split('.').map((part) => int.tryParse(part) ?? 0).toList();

    List<int> currentVersionParts = currentVersion
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();

    // التأكد من أن كلا القائمتين لهما نفس الطول
    while (storeVersionParts.length < currentVersionParts.length) {
      storeVersionParts.add(0);
    }
    while (currentVersionParts.length < storeVersionParts.length) {
      currentVersionParts.add(0);
    }

    // مقارنة كل جزء
    for (int i = 0; i < storeVersionParts.length; i++) {
      if (storeVersionParts[i] > currentVersionParts[i]) {
        return true; // الإصدار الجديد أحدث
      } else if (storeVersionParts[i] < currentVersionParts[i]) {
        return false; // الإصدار الحالي أحدث
      }
    }

    return false; // الإصدارات متطابقة
  }

  // عرض مربع حوار تحديث Android
  void _showAndroidUpdateDialog({required bool immediate}) {
    if (!mounted || _isNavigating) return;

    showDialog(
      context: context,
      barrierDismissible:
          !immediate, // إذا كان التحديث ضروريًا، لا يمكن إغلاق مربع الحوار
      builder: (context) => WillPopScope(
        // منع إغلاق مربع الحوار بالضغط على زر الرجوع
        onWillPop: () async => !immediate,
        child: AlertDialog(
          title: Row(
            children: [
              Image.asset('assets/images/logo.png', width: 40, height: 40),
              const SizedBox(width: 10),
              const Text('تحديث جديد متاح'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'يوجد إصدار جديد من التطبيق. يرجى تحديث التطبيق للاستمتاع بأحدث الميزات وإصلاحات الأخطاء.',
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[200],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.system_update,
                          size: 50, color: AppColors.appamber),
                      const SizedBox(height: 10),
                      Text(
                        'تحديث Google Play',
                        style: TextStyle(
                          color: AppColors.appamber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (!immediate)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('لاحقًا'),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _openGooglePlayStore();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.appamber,
                foregroundColor: Colors.black,
              ),
              child: const Text('تحديث الآن'),
            ),
          ],
        ),
      ),
    );
  }

  // عرض مربع حوار تحديث iOS
  void _showIOSUpdateDialog() {
    if (!mounted || _isNavigating) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => WillPopScope(
        // السماح بإغلاق مربع الحوار بالضغط على زر الرجوع
        onWillPop: () async => true,
        child: AlertDialog(
          title: Row(
            children: [
              Image.asset('assets/images/logo.png', width: 40, height: 40),
              const SizedBox(width: 10),
              const Text('تحديث جديد متاح'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'يوجد إصدار جديد من التطبيق. يرجى تحديث التطبيق للاستمتاع بأحدث الميزات وإصلاحات الأخطاء.',
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[200],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.app_shortcut, size: 50, color: Colors.blue),
                      const SizedBox(height: 10),
                      const Text(
                        'تحديث App Store',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لاحقًا'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _openAppStore();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('تحديث الآن'),
            ),
          ],
        ),
      ),
    );
  }

  // فتح متجر Google Play
  Future<void> _openGooglePlayStore() async {
    if (!mounted || _isNavigating) return;

    try {
      // محاولة فتح متجر Google Play
      final url = 'market://details?id=$_packageName';
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        // إذا فشل، افتح صفحة الويب لمتجر Google Play
        await launch(
            'https://play.google.com/store/apps/details?id=$_packageName');
      }
    } catch (e) {
      print('❌ فشل في فتح متجر Google Play: $e');
    }
  }

  // فتح متجر App Store
  Future<void> _openAppStore() async {
    if (!mounted || _isNavigating) return;

    try {
      // محاولة فتح متجر App Store
      final url = 'https://apps.apple.com/app/id$_appStoreId';
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        // إذا فشل، افتح صفحة الويب لمتجر App Store
        await launch('https://apps.apple.com/app/id$_appStoreId');
      }
    } catch (e) {
      print('❌ فشل في فتح متجر App Store: $e');
    }
  }

  // تعديل دالة _checkLoginStatus في IntroScreen للتعامل مع الأخطاء بشكل أفضل
  void _checkLoginStatus() async {
    if (_isNavigating) return;

    print('🔄 جاري التحقق من حالة تسجيل الدخول...');

    // انتظار حتى يتم تحميل التكوين
    if (!_isConfigLoaded) {
      print('⏳ انتظار تحميل التكوين قبل التحقق من حالة تسجيل الدخول...');
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) {
      print('❌ Widget غير موجود بعد');
      return;
    }

    try {
      // إضافة تأخير إضافي لضمان اكتمال التهيئة
      await Future.delayed(const Duration(milliseconds: 300));

      print('🔍 التحقق من Firebase Auth...');
      User? user = FirebaseAuth.instance.currentUser;

      if (!mounted) {
        print('❌ Widget غير موجود بعد');
        return;
      }

      print('👤 حالة المستخدم: ${user != null ? "مسجل" : "غير مسجل"}');

      // تعيين متغير الانتقال لمنع استدعاء setState بعد الانتقال
      setState(() {
        _isNavigating = true;
      });

      // إضافة تأخير قصير قبل الانتقال للتأكد من اكتمال تحميل الموارد
      await Future.delayed(Duration(milliseconds: 300));

      if (user != null) {
        print('✅ المستخدم مسجل، جاري الانتقال إلى HomeScreen...');

        // استخدام Navigator.pushReplacement بدلاً من pushAndRemoveUntil
        // لتحسين الأداء وتجنب مشاكل انتقال الصفحات على iOS
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        print('❌ المستخدم غير مسجل، جاري الانتقال إلى Login...');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Login()),
        );
      }
    } catch (e) {
      print('❌ خطأ في التحقق من حالة تسجيل الدخول: $e');
      if (mounted && !_isNavigating) {
        setState(() {
          _isNavigating = true;
        });

        print('⚠️ حدث خطأ، جاري الانتقال إلى Login...');

        // استخدام Navigator.pushReplacement
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Login()),
        );
      }
    }
  }

  // تعديل دالة build لوضع النص فوق الصورة مباشرة بنفس المسافة التي بين الصورة والنص تحتها
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // إضافة مساحة متغيرة في الأعلى
              Spacer(flex: 1),

              // إضافة النص الإعلاني فوق الصورة إذا كان موجودًا
              if (_introAnnouncement.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _introAnnouncement,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.appamber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // نفس المسافة بين النص والصورة كما بين الصورة والنص تحتها (20 بكسل)
                const SizedBox(height: 20),
              ],

              // الشعار
              _buildLogo(),

              // المسافة بين الشعار والنص تحته (20 بكسل)
              const SizedBox(height: 20),

              // النصوص
              Text(_introTitle,
                  style:
                      const TextStyle(color: Colors.amberAccent, fontSize: 18)),
              Text(_introSubtitle,
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 18,
                  )),
              const SizedBox(height: 20),
              Text(_introVerse1,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.amberAccent, fontSize: 15)),
              Text(_introVerse2,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.amberAccent, fontSize: 15)),

              // مؤشر التحميل إذا كان هناك تحقق من التحديثات
              if (_isCheckingUpdate)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: CircularProgressIndicator(color: AppColors.appamber),
                ),

              // أزرار اختبار التحديث في وضع التطوير
              if (_isTestingMode && !_isCheckingUpdate && !_isNavigating)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () =>
                            _showAndroidUpdateDialog(immediate: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.appamber,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('اختبار تحديث Android'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => _showIOSUpdateDialog(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('اختبار تحديث iOS'),
                      ),
                    ],
                  ),
                ),

              // إضافة مساحة متغيرة في الأسفل
              Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  // دالة لبناء الشعار (من الإنترنت أو محليًا)
  Widget _buildLogo() {
    if (_logoUrl != null && _logoUrl!.isNotEmpty) {
      // استخدام صورة من الإنترنت مع التخزين المؤقت
      return Container(
        height: 150,
        width: 150,
        margin: const EdgeInsets.all(10.0),
        child: CachedNetworkImage(
          imageUrl: _logoUrl!,
          fit: BoxFit.contain,
          placeholder: (context, url) => Center(
            child: CircularProgressIndicator(
              color: AppColors.appamber,
            ),
          ),
          errorWidget: (context, url, error) {
            print('❌ خطأ في تحميل الشعار من الإنترنت: $error');
            // في حالة الخطأ، استخدم الشعار المحلي
            return Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                    image: AssetImage("assets/images/logo.png"),
                    fit: BoxFit.contain),
              ),
            );
          },
          // إضافة مستمع لتحميل الصورة
          imageBuilder: (context, imageProvider) {
            // تعيين حالة تحميل الشعار عند اكتمال التحميل
            if (mounted && !_isLogoLoaded) {
              setState(() {
                _isLogoLoaded = true;
              });
              print('✅ تم تحميل الشعار من الإنترنت بنجاح');
              // التحقق من إمكانية الانتقال بعد تحميل الشعار
              _checkAllResourcesLoaded();
            }
            return Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.contain,
                ),
              ),
            );
          },
        ),
      );
    } else {
      // استخدام الشعار المحلي
      // تعيين حالة تحميل الشعار لأن الشعار المحلي يتم تحميله فورًا
      if (mounted && !_isLogoLoaded) {
        // استخدام Future.microtask لتجنب setState أثناء البناء
        Future.microtask(() {
          setState(() {
            _isLogoLoaded = true;
          });
          print('✅ تم تحميل الشعار المحلي بنجاح');
          // التحقق من إمكانية الانتقال بعد تحميل الشعار
          _checkAllResourcesLoaded();
        });
      }

      return Container(
        height: 150,
        width: 150,
        margin: const EdgeInsets.all(10.0),
        decoration: const BoxDecoration(
          image: DecorationImage(
              image: AssetImage("assets/images/logo.png"), fit: BoxFit.contain),
        ),
      );
    }
  }
}
