import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:om_elnour_choir/services/FirebaseService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:om_elnour_choir/services/remote_config_service.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/hymn_repository.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/news_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_cubit.dart';
import 'package:om_elnour_choir/app_setting/views/home_screen.dart';
import 'package:om_elnour_choir/app_setting/views/intro_screen.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/services/cache_service.dart';
import 'package:om_elnour_choir/user/views/login_screen.dart';
import 'package:om_elnour_choir/user/views/profile_screen.dart';
import 'package:om_elnour_choir/user/views/signup_screen.dart';
import 'package:om_elnour_choir/services/notification_service.dart';
import 'package:om_elnour_choir/services/app_open_ad_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';

// إضافة مفتاح عام للـ Navigator للوصول إلى BuildContext
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// تغيير المتغيرات العالمية لتكون nullable
MyAudioService? audioService;
final CacheService cacheService = CacheService();
// إضافة متغير عام لخدمة إعلان الفتح
AppOpenAdService? appOpenAdService;
// إضافة متغير لتتبع ما إذا كان التطبيق يفتح لأول مرة
bool isFirstOpen = true;
RemoteConfigService? remoteConfigService;
// إضافة متغير لخدمة Firebase
FirebaseService? firebaseService;
// إضافة متغير لخدمة الإشعارات
NotificationService? notificationService;
// إضافة متغير لتتبع ما إذا كان التطبيق قيد الإغلاق
bool isAppTerminating = false;
// إضافة متغير لتتبع ما إذا كان التطبيق قد تم تهيئته بالفعل
bool isAppInitialized = false;

// إضافة متغير لتتبع محاولات إعادة التهيئة
int _initRetryCount = 0;
const int _maxInitRetries = 3;

// إضافة دالة لتنظيف الموارد
Future<void> _cleanupResources() async {
  try {
    print("🧹 تنظيف الموارد...");

    // حفظ حالة التطبيق
    await _saveAppState();

    // إغلاق خدمة الصوت
    if (audioService != null) {
      await audioService!.dispose();
      audioService = null;
      print("✅ تم إغلاق خدمة الصوت");
    }

    // إغلاق خدمة الإعلانات
    if (appOpenAdService != null) {
      appOpenAdService!.dispose();
      appOpenAdService = null;
      print("✅ تم إغلاق خدمة الإعلانات");
    }

    print("✅ تم تنظيف الموارد بنجاح");
  } catch (e) {
    print("❌ خطأ في تنظيف الموارد: $e");
  }
}

// إضافة دالة لحفظ حالة التطبيق عند الإغلاق
Future<void> _saveAppState() async {
  try {
    print('💾 حفظ حالة التطبيق عند الإغلاق...');

    // حفظ حالة التشغيل إذا كانت خدمة الصوت مهيأة
    if (audioService != null && !audioService!.isDisposed) {
      await audioService!.saveStateOnAppClose();
    }

    // الوصول إلى HymnsCubit من خلال BuildContext إذا كان متاحًا
    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        final hymnsCubit = BlocProvider.of<HymnsCubit>(context, listen: false);
        await hymnsCubit.saveStateOnAppClose();
      } catch (e) {
        print('⚠️ تعذر الوصول إلى HymnsCubit: $e');
      }
    }

    print('✅ تم حفظ حالة التطبيق عند الإغلاق بنجاح');
  } catch (e) {
    print('❌ خطأ في حفظ حالة التطبيق عند الإغلاق: $e');
  }
}

// تعديل دالة معالجة الإشعارات في الخلفية
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // تأكد من تهيئة Firebase قبل استخدامه في الخلفية
  try {
    // تحقق مما إذا كان Firebase مهيأ بالفعل
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
      print("✅ تم تهيئة Firebase في الخلفية");
    } else {
      print("✅ Firebase مهيأ بالفعل في الخلفية");
    }
  } catch (e) {
    print("❌ خطأ في تهيئة Firebase في الخلفية: $e");
    // لا نرمي الاستثناء هنا، نستمر في المعالجة
  }

  print("🔔 إشعار في الخلفية: ${message.notification?.title}");
  print("📦 بيانات الإشعار: ${message.data}");
  print("🆔 معرف الرسالة: ${message.messageId}");
  print("🔄 نوع الإشعار: ${message.data['screen_type'] ?? 'غير محدد'}");

  // حفظ الإشعار في التخزين المحلي لعرضه لاحقًا
  try {
    final prefs = await SharedPreferences.getInstance();
    final String? storedNotifications =
        prefs.getString('background_notifications');
    List<Map<String, dynamic>> notifications = [];

    if (storedNotifications != null) {
      try {
        notifications =
            List<Map<String, dynamic>>.from(jsonDecode(storedNotifications));
      } catch (e) {
        print("⚠️ خطأ في تحليل الإشعارات المخزنة: $e");
        notifications = [];
      }
    }

    // إضافة الإشعار الجديد
    if (message.notification != null) {
      notifications.add({
        'id': message.messageId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'title': message.notification!.title ?? 'إشعار جديد',
        'body': message.notification!.body ?? '',
        'data': message.data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      });

      // حفظ الإشعارات المحدثة
      await prefs.setString(
          'background_notifications', jsonEncode(notifications));
      print("✅ تم حفظ الإشعار في الخلفية");
      print("📊 عدد الإشعارات المخزنة: ${notifications.length}");
    }
  } catch (e) {
    print("❌ خطأ في حفظ الإشعار في الخلفية: $e");
  }
}

// إضافة دالة لاستيراد الإشعارات المخزنة في الخلفية
Future<void> _importBackgroundNotifications() async {
  try {
    if (notificationService == null) {
      print("⚠️ خدمة الإشعارات غير مهيأة، تجاهل استيراد الإشعارات");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final String? storedNotifications =
        prefs.getString('background_notifications');

    if (storedNotifications == null || storedNotifications.isEmpty) {
      print("ℹ️ لا توجد إشعارات مخزنة في الخلفية");
      return;
    }

    try {
      final List<dynamic> notifications = jsonDecode(storedNotifications);
      print("📲 استيراد ${notifications.length} إشعار من الخلفية");

      for (final notification in notifications) {
        try {
          await notificationService!.importBackgroundNotification(
            id: notification['id'] ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            title: notification['title'] ?? 'إشعار جديد',
            body: notification['body'] ?? '',
            data: Map<String, dynamic>.from(notification['data'] ?? {}),
            timestamp: DateTime.fromMillisecondsSinceEpoch(
                notification['timestamp'] ??
                    DateTime.now().millisecondsSinceEpoch),
            isRead: notification['isRead'] ?? false,
          );
        } catch (e) {
          print("⚠️ خطأ في استيراد إشعار: $e");
        }
      }

      // مسح الإشعارات المخزنة بعد استيرادها
      await prefs.remove('background_notifications');
      print("✅ تم استيراد الإشعارات من الخلفية بنجاح");
    } catch (e) {
      print("❌ خطأ في تحليل الإشعارات المخزنة: $e");
    }
  } catch (e) {
    print("❌ خطأ في استيراد الإشعارات من الخلفية: $e");
  }
}

// تعديل فئة AppLifecycleObserver لتكون أكثر مرونة
class AppLifecycleObserver extends WidgetsBindingObserver {
  // إضافة قناة اتصال مع Swift
  final MethodChannel _channel =
      MethodChannel('com.egypt.redcherry.omelnourchoir/app_lifecycle');

  // إضافة متغير لتتبع آخر حالة
  AppLifecycleState? _lastState;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    try {
      print('🔄 تغيرت حالة دورة حياة التطبيق: $state');

      // تجنب معالجة نفس الحالة مرتين متتاليتين
      if (_lastState == state) {
        print('⚠️ تم تجاهل تغيير الحالة لأنها نفس الحالة السابقة: $state');
        return;
      }

      _lastState = state;

      switch (state) {
        case AppLifecycleState.resumed:
          _handleAppResumed();
          break;
        case AppLifecycleState.inactive:
          _handleAppInactive();
          break;
        case AppLifecycleState.paused:
          _handleAppPaused();
          break;
        case AppLifecycleState.detached:
          _handleAppDetached();
          break;
        default:
          break;
      }
    } catch (e) {
      print("❌ خطأ في معالجة تغيير حالة دورة حياة التطبيق: $e");
    }
  }

  void _handleAppResumed() {
    try {
      print("📱 التطبيق عاد من الخلفية");

      // إعادة تعيين متغير إنهاء التطبيق
      isAppTerminating = false;

      // إخطار Swift بأن التطبيق قد استؤنف
      _channel.invokeMethod('appResumed').then((_) {
        print("✅ تم إخطار Swift باستئناف التطبيق");
      }).catchError((error) {
        print("⚠️ خطأ في إخطار Swift: $error");
      });

      // استئناف تشغيل الصوت بعد تأخير قصير
      Future.delayed(Duration(milliseconds: 800), () {
        if (!isAppTerminating &&
            audioService != null &&
            !audioService!.isDisposed) {
          audioService!.resumePlaybackAfterNavigation();
        }
      });

      // تأخير تحميل إعلان الفتح
      Future.delayed(Duration(seconds: 3), () {
        if (!isAppTerminating && appOpenAdService != null) {
          appOpenAdService!.loadAd();
        }
      });

      // استيراد الإشعارات من الخلفية
      _importBackgroundNotifications();
    } catch (e) {
      print("❌ خطأ في معالجة استئناف التطبيق: $e");
    }
  }

  void _handleAppInactive() {
    try {
      print('📱 التطبيق غير نشط، جاري حفظ الحالة...');

      // حفظ حالة التشغيل
      if (audioService != null && !audioService!.isDisposed) {
        audioService!.savePlaybackState();
      }

      // استدعاء دالة حفظ الحالة
      _saveAppState();
    } catch (e) {
      print("❌ خطأ في معالجة حالة التطبيق غير النشط: $e");
    }
  }

  void _handleAppPaused() {
    try {
      print('📱 التطبيق في الخلفية، جاري حفظ الحالة...');

      // إخطار Swift بأن التطبيق قد توقف مؤقتًا
      _channel.invokeMethod('appPaused').then((_) {
        print("✅ تم إخطار Swift بإيقاف التطبيق مؤقتًا");
      }).catchError((error) {
        print("⚠️ خطأ في إخطار Swift: $error");
      });

      // حفظ حالة التشغيل قبل الانتقال للخلفية
      if (audioService != null && !audioService!.isDisposed) {
        audioService!.savePlaybackState();
      }

      // استدعاء دالة حفظ الحالة
      _saveAppState();
    } catch (e) {
      print("❌ خطأ في معالجة إيقاف التطبيق مؤقتًا: $e");
    }
  }

  void _handleAppDetached() {
    try {
      print('📱 التطبيق منفصل، جاري حفظ الحالة وتنظيف الموارد...');

      // تعيين متغير إنهاء التطبيق
      isAppTerminating = true;

      // تنظيف الموارد بشكل كامل
      _cleanupResources();

      // إعادة تعيين حالة الفتح الأول لإعلان الفتح
      if (appOpenAdService != null) {
        appOpenAdService!.resetFirstOpenState();
      }
    } catch (e) {
      print("❌ خطأ في معالجة فصل التطبيق: $e");
    }
  }
}

// دالة main مع معالجة أفضل للأخطاء
void main() async {
  // تأكد من تهيئة Flutter قبل استدعاء أي شيء آخر
  WidgetsFlutterBinding.ensureInitialized();
  print("🚀 بدء تشغيل التطبيق...");

  // إضافة معالجة الأخطاء غير المتوقعة
  FlutterError.onError = (FlutterErrorDetails details) {
    print("❌ خطأ غير متوقع: ${details.exception}");
    print("📋 تفاصيل الخطأ: ${details.stack}");
    FlutterError.presentError(details);
  };

  // إضافة معالجة الأخطاء غير المعالجة في Zone
  runZonedGuarded(() async {
    await _initializeApp();
  }, (error, stackTrace) {
    print("❌ خطأ غير معالج: $error");
    print("📋 تفاصيل الخطأ: $stackTrace");
  });
}

// دالة تهيئة التطبيق
Future<void> _initializeApp() async {
  try {
    // تهيئة Firebase أولاً
    print("🔥 تهيئة Firebase...");
    await Firebase.initializeApp();
    print("✅ تم تهيئة Firebase بنجاح");

    // تهيئة App Check
    try {
      await FirebaseAppCheck.instance.activate(
        // استخدم DeviceCheck في الإنتاج و Debug Provider في التطوير
        appleProvider: AppleProvider.deviceCheck,
        // يمكنك استخدام هذا في بيئة التطوير
        // appleProvider: AppleProvider.debug,
      );
      print("✅ تم تهيئة Firebase App Check بنجاح");
    } catch (e) {
      print("⚠️ خطأ في تهيئة Firebase App Check: $e");
    }

    // تسجيل معالج الإشعارات في الخلفية
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    print("✅ تم تسجيل معالج الإشعارات في الخلفية");

    // تهيئة الألوان
    AppColors.initialize();
    print("✅ تم تهيئة الألوان بنجاح");

    // تهيئة خدمة الإشعارات
    try {
      notificationService = NotificationService(navigatorKey: navigatorKey);
      await notificationService!.initialize();
      print("✅ تم تهيئة خدمة الإشعارات بنجاح");

      // استيراد الإشعارات المخزنة في الخلفية
      await _importBackgroundNotifications();
    } catch (e) {
      print("⚠️ خطأ في تهيئة خدمة الإشعارات: $e");
    }

    // تهيئة خدمة الصوت
    try {
      audioService = MyAudioService();
      print("✅ تم تهيئة خدمة الصوت بنجاح");
    } catch (e) {
      print("⚠️ خطأ في تهيئة خدمة الصوت: $e");
    }

    // محاولة تهيئة Remote Config
    try {
      remoteConfigService = RemoteConfigService();
      await remoteConfigService!.initialize();
      print("✅ تم تهيئة Remote Config بنجاح");
    } catch (e) {
      print("⚠️ خطأ في تهيئة Remote Config: $e");
    }

    // محاولة تهيئة الإعلانات
    try {
      await MobileAds.instance.initialize();
      print("✅ تم تهيئة الإعلانات بنجاح");

      // تأخير تحميل إعلان الفتح
      appOpenAdService = AppOpenAdService();
      Future.delayed(Duration(seconds: 2), () {
        if (appOpenAdService != null) {
          appOpenAdService!.loadAd();
        }
      });
    } catch (e) {
      print("⚠️ خطأ في تهيئة الإعلانات: $e");
    }

    // التحقق من أول استخدام للتطبيق
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool firstTime = prefs.getBool('firstTime') ?? true;

    if (firstTime) {
      await prefs.setBool('firstTime', false);
      print("📱 هذه هي المرة الأولى لفتح التطبيق");
    }

    // إضافة مستمع لحالة التطبيق
    WidgetsBinding.instance.addObserver(AppLifecycleObserver());
    print("✅ تم إضافة مراقب دورة حياة التطبيق");

    // تعيين متغير تهيئة التطبيق
    isAppInitialized = true;
    print("✅ تم تهيئة التطبيق بنجاح");

    print("🚀 بدء تشغيل واجهة المستخدم...");
    runApp(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => CopticCalendarCubit()),
          BlocProvider(create: (context) => DailyBreadCubit()),
          BlocProvider(create: (context) => VerceCubit()),
          BlocProvider(
            create: (context) {
              final hymnRepository = HymnsRepository();
              // التأكد من تهيئة audioService قبل استخدامه
              if (audioService == null) {
                audioService = MyAudioService();
                print("✅ تم إنشاء خدمة الصوت في BlocProvider");
              }
              final hymnsCubit = HymnsCubit(hymnRepository, audioService!);
              return hymnsCubit;
            },
          ),
          BlocProvider(create: (context) => NewsCubit()),
        ],
        child: MyApp(navigatorKey: navigatorKey, firstTime: firstTime),
      ),
    );
  } catch (e) {
    print("❌ خطأ في تهيئة التطبيق: $e");

    // محاولة إعادة التهيئة إذا لم يتجاوز الحد الأقصى للمحاولات
    if (_initRetryCount < _maxInitRetries) {
      _initRetryCount++;
      print(
          "🔄 محاولة إعادة تهيئة التطبيق (${_initRetryCount}/${_maxInitRetries})...");
      await Future.delayed(Duration(seconds: 2));
      await _initializeApp();
    } else {
      print("❌ فشلت جميع محاولات تهيئة التطبيق");
      // عرض شاشة خطأ بسيطة
      runApp(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text("حدث خطأ أثناء تهيئة التطبيق",
                    style: TextStyle(fontSize: 18)),
                SizedBox(height: 8),
                Text("يرجى إعادة تشغيل التطبيق",
                    style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ));
    }
  }
}

class MyApp extends StatefulWidget {
  final bool firstTime;
  final GlobalKey<NavigatorState> navigatorKey;
  const MyApp({Key? key, required this.firstTime, required this.navigatorKey})
      : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // تأخير تحميل إعلان الفتح
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration(seconds: 2));
      if (mounted && !isAppTerminating && appOpenAdService != null) {
        try {
          await appOpenAdService!.loadAd();
        } catch (e) {
          print('❌ خطأ في تحميل إعلان الفتح: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.amber,
        fontFamily: 'Cairo',
      ),
      home: const IntroScreen(),
      routes: {
        '/login': (context) => Login(),
        '/home': (context) => HomeScreen(),
        '/signup': (context) => SignupScreen(),
        '/profile': (context) => ProfileScreen(),
      },
    );
  }
}
