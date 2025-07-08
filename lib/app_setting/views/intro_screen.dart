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
import 'package:flutter/foundation.dart';
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

class _IntroScreenState extends State<IntroScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // إضافة متغير للتحكم في وضع الاختبار

  bool _isNavigating = false; // متغير لتتبع حالة الانتقال
  bool _isConfigLoaded = false; // متغير لتتبع حالة تحميل التكوين
  bool _isLogoLoaded = false; // متغير جديد لتتبع حالة تحميل الشعار

  bool _isAdLoaded = false; // متغير جديد لتتبع حالة تحميل الإعلان
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

  // متحكمات الانيميشن
  late AnimationController _logoAnimationController;
  late AnimationController _textAnimationController;
  late AnimationController _announcementAnimationController;

  // الانيميشن
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<Offset> _titleSlideAnimation;
  late Animation<double> _titleOpacityAnimation;
  late Animation<Offset> _subtitleSlideAnimation;
  late Animation<double> _subtitleOpacityAnimation;
  late Animation<Offset> _verseSlideAnimation;
  late Animation<double> _verseOpacityAnimation;
  late Animation<double> _announcementOpacityAnimation;
  late Animation<double> _announcementScaleAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screenLoadTime = DateTime.now();

    // تهيئة متحكمات الانيميشن
    _initializeAnimations();

    // بدء الانيميشن
    _startAnimations();

    // تأخير تحميل التكوين والتحقق من التحديثات
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        _loadCachedConfig();
        _loadRemoteConfig();
      }
    });

    // تحميل إعلان الفتح مبكراً
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        _loadAppOpenAd();
      }
    });
  }

  // تهيئة الانيميشن
  void _initializeAnimations() {
    // متحكم انيميشن اللوجو
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // متحكم انيميشن النص
    _textAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // متحكم انيميشن النص الإعلاني
    _announcementAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // انيميشن اللوجو - تكبير وظهور
    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.elasticOut,
    ));

    _logoOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.easeIn,
    ));

    // انيميشن العنوان الرئيسي - انزلاق من الأعلى
    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    ));

    _titleOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    ));

    // انيميشن العنوان الفرعي - انزلاق من اليمين
    _subtitleSlideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
    ));

    _subtitleOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: const Interval(0.2, 0.5, curve: Curves.easeIn),
    ));

    // انيميشن الآيات - انزلاق من الأسفل
    _verseSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
    ));

    _verseOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
    ));

    // انيميشن النص الإعلاني - ظهور وتكبير
    _announcementOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _announcementAnimationController,
      curve: Curves.easeIn,
    ));

    _announcementScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _announcementAnimationController,
      curve: Curves.bounceOut,
    ));
  }

  // بدء الانيميشن
  void _startAnimations() {
    // بدء انيميشن اللوجو فوراً
    _logoAnimationController.forward();

    // بدء انيميشن النص بعد تأخير قصير
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _textAnimationController.forward();
      }
    });
  }

  // بدء انيميشن النص الإعلاني
  void _startAnnouncementAnimation() {
    if (mounted && _introAnnouncement.isNotEmpty) {
      _announcementAnimationController.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // التخلص من متحكمات الانيميشن
    _logoAnimationController.dispose();
    _textAnimationController.dispose();
    _announcementAnimationController.dispose();
    // التخلص من إعلان الفتح
    appOpenAdService.dispose();
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

  // دالة جديدة لتحميل إعلان الفتح
  Future<void> _loadAppOpenAd() async {
    try {
      print('🎬 بدء تحميل إعلان الفتح...');
      await appOpenAdService.loadAd();

      // انتظار تحميل الإعلان مع مهلة زمنية
      bool adLoaded = await appOpenAdService.waitForAdToLoad(maxWaitSeconds: 5);

      if (mounted) {
        setState(() {
          _isAdLoaded = adLoaded;
        });

        if (adLoaded) {
          print('✅ تم تحميل إعلان الفتح بنجاح');
        } else {
          print('⚠️ لم يتم تحميل إعلان الفتح في الوقت المحدد');
        }

        // التحقق من إمكانية الانتقال بعد محاولة تحميل الإعلان
        _checkAllResourcesLoaded();
      }
    } catch (e) {
      print('❌ خطأ في تحميل إعلان الفتح: $e');
      if (mounted) {
        setState(() {
          _isAdLoaded = false;
        });
        // التحقق من إمكانية الانتقال حتى في حالة فشل تحميل الإعلان
        _checkAllResourcesLoaded();
      }
    }
  }

  // دالة جديدة للتحقق من تحميل جميع الموارد
  void _checkAllResourcesLoaded() {
    if (_isNavigating) return;

    print('🔍 التحقق من حالة تحميل الموارد:');
    print('- تحميل التكوين: $_isConfigLoaded');
    print('- تحميل الشعار: $_isLogoLoaded');
    print('- حالة تحميل الإعلان: $_isAdLoaded');

    // التحقق من الوقت المنقضي منذ تحميل الشاشة
    final elapsedSeconds =
        DateTime.now().difference(_screenLoadTime!).inSeconds;
    print('⏱️ الوقت المنقضي منذ تحميل الشاشة: $elapsedSeconds ثانية');

    // إذا لم تكتمل جميع العمليات الأساسية، ننتظر ثانية إضافية ونحاول مرة أخرى
    // ملاحظة: الإعلان ليس ضرورياً لاكتمال التحميل
    if (!_isConfigLoaded || !_isLogoLoaded) {
      print(
          '⏳ لم تكتمل جميع العمليات الأساسية بعد، سيتم إعادة المحاولة بعد ثانية...');
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
            // بدء انيميشن النص الإعلاني
            _startAnnouncementAnimation();
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
          if (introAnnouncement.isNotEmpty) {
            _introAnnouncement = introAnnouncement;
            // بدء انيميشن النص الإعلاني إذا لم يكن قد بدأ بعد
            _startAnnouncementAnimation();
          }
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

  // تعديل دالة _checkLoginStatus للتعامل مع إعلان الفتح
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
      // محاولة عرض إعلان الفتح قبل الانتقال
      print('🎬 محاولة عرض إعلان الفتح...');
      bool adShown = await appOpenAdService.showAdIfFirstOpen();

      if (adShown) {
        print('✅ تم عرض إعلان الفتح، انتظار إغلاقه...');
        // انتظار إضافي للسماح للمستخدم بمشاهدة الإعلان
        await Future.delayed(Duration(seconds: 2));
      } else {
        print('⚠️ لم يتم عرض إعلان الفتح');
      }

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

  // تعديل دالة build لإضافة الانيميشن
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

              // إضافة النص الإعلاني فوق الصورة مع انيميشن
              if (_introAnnouncement.isNotEmpty) ...[
                AnimatedBuilder(
                  animation: _announcementAnimationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _announcementScaleAnimation.value,
                      child: Opacity(
                        opacity: _announcementOpacityAnimation.value,
                        child: Padding(
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
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],

              // الشعار مع انيميشن
              AnimatedBuilder(
                animation: _logoAnimationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoScaleAnimation.value,
                    child: Opacity(
                      opacity: _logoOpacityAnimation.value,
                      child: _buildLogo(),
                    ),
                  );
                },
              ),

              // المسافة بين الشعار والنص تحته
              const SizedBox(height: 20),

              // العنوان الرئيسي مع انيميشن
              AnimatedBuilder(
                animation: _textAnimationController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _titleSlideAnimation,
                    child: FadeTransition(
                      opacity: _titleOpacityAnimation,
                      child: Text(
                        _introTitle,
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // العنوان الفرعي مع انيميشن
              AnimatedBuilder(
                animation: _textAnimationController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _subtitleSlideAnimation,
                    child: FadeTransition(
                      opacity: _subtitleOpacityAnimation,
                      child: Text(
                        _introSubtitle,
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // الآيات مع انيميشن
              AnimatedBuilder(
                animation: _textAnimationController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _verseSlideAnimation,
                    child: FadeTransition(
                      opacity: _verseOpacityAnimation,
                      child: Column(
                        children: [
                          Text(
                            _introVerse1,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            _introVerse2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
