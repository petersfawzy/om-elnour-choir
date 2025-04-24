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

// إضافة مفتاح عام للـ Navigator للوصول إلى BuildContext
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// إنشاء كائن واحد من MyAudioService للاستخدام في جميع أنحاء التطبيق
final MyAudioService audioService = MyAudioService();
final CacheService cacheService = CacheService();
// إضافة متغير عام لخدمة إعلان الفتح
final AppOpenAdService appOpenAdService = AppOpenAdService();
// إضافة متغير لتتبع ما إذا كان التطبيق يفتح لأول مرة
bool isFirstOpen = true;
final RemoteConfigService remoteConfigService = RemoteConfigService();
// إضافة متغير لخدمة Firebase
final FirebaseService firebaseService = FirebaseService();
// إضافة متغير لخدمة الإشعارات
NotificationService? notificationService;
// إضافة متغير لتتبع ما إذا كان التطبيق قيد الإغلاق
bool isAppTerminating = false;
// إضافة متغير لتتبع ما إذا كان التطبيق قد تم تهيئته بالفعل
bool isAppInitialized = false;

// إضافة دالة لحفظ حالة التطبيق عند الإغلاق
Future<void> _saveAppState() async {
  try {
    print('💾 حفظ حالة التطبيق عند الإغلاق...');

    // حفظ حالة التشغيل
    await audioService.saveStateOnAppClose();

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

// تعديل دالة معالجة الإشعارات في الخلفية لتكون أكثر تفصيلاً
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // تأكد من تهيئة Firebase قبل استخدامه في الخلفية
  try {
    await Firebase.initializeApp();
    print("✅ تم تهيئة Firebase في الخلفية");
  } catch (e) {
    print("❌ خطأ في تهيئة Firebase في الخلفية: $e");
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
      notifications =
          List<Map<String, dynamic>>.from(jsonDecode(storedNotifications));
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

// دالة main مبسطة
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

  // تهيئة Firebase أولاً
  try {
    print("🔥 تهيئة Firebase...");
    await Firebase.initializeApp();
    print("✅ تم تهيئة Firebase بنجاح");

    // تسجيل معالج الإشعارات في الخلفية
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    print("✅ تم تسجيل معالج الإشعارات في الخلفية");
  } catch (e) {
    print("⚠️ خطأ في تهيئة Firebase: $e");
  }

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

  // محاولة تهيئة Remote Config
  try {
    await remoteConfigService.initialize();
    print("✅ تم تهيئة Remote Config بنجاح");
  } catch (e) {
    print("⚠️ خطأ في تهيئة Remote Config: $e");
  }

  // محاولة تهيئة الإعلانات
  try {
    await MobileAds.instance.initialize();
    print("✅ تم تهيئة الإعلانات بنجاح");

    // تأخير تحميل إعلان الفتح
    Future.delayed(Duration(seconds: 2), () {
      appOpenAdService.loadAd();
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
            final hymnsCubit = HymnsCubit(hymnRepository, audioService);
            return hymnsCubit;
          },
        ),
        BlocProvider(create: (context) => NewsCubit()),
      ],
      child: MyApp(navigatorKey: navigatorKey, firstTime: firstTime),
    ),
  );
}

// دالة لاستيراد الإشعارات المخزنة في الخلفية
Future<void> _importBackgroundNotifications() async {
  try {
    if (notificationService == null) {
      print("⚠️ خدمة الإشعارات غير مهيأة بعد");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final String? storedNotifications =
        prefs.getString('background_notifications');

    if (storedNotifications != null) {
      final List<dynamic> notifications = jsonDecode(storedNotifications);
      int importedCount = 0;

      for (var notification in notifications) {
        // استخدام الدالة العامة في NotificationService بدلاً من الوصول المباشر إلى _historyService
        try {
          await notificationService!.importBackgroundNotification(
            id: notification['id'],
            title: notification['title'],
            body: notification['body'],
            data: Map<String, dynamic>.from(notification['data']),
            timestamp:
                DateTime.fromMillisecondsSinceEpoch(notification['timestamp']),
            isRead: notification['isRead'] ?? false,
          );
          importedCount++;
        } catch (e) {
          print("⚠️ خطأ في استيراد إشعار: $e");
        }
      }

      // حذف الإشعارات المستوردة من التخزين المؤقت
      await prefs.remove('background_notifications');
      print("✅ تم استيراد $importedCount إشعار من الخلفية");
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
    print('🔄 تغيرت حالة دورة حياة التطبيق: $state');

    // تجنب معالجة نفس الحالة مرتين متتاليتين
    if (_lastState == state) {
      print('⚠️ تم تجاهل تغيير الحالة لأنها نفس الحالة السابقة: $state');
      return;
    }

    _lastState = state;

    if (state == AppLifecycleState.resumed) {
      // عند العودة من الخلفية
      print("📱 التطبيق عاد من الخلفية");

      // إعادة تعيين متغير إنهاء التطبيق
      isAppTerminating = false;

      // إخطار Swift بأن التطبيق قد استؤنف
      _channel.invokeMethod('appResumed').then((_) {
        print("✅ تم إخطار Swift باستئناف التطبيق");
      }).catchError((error) {
        print("❌ خطأ في إخطار Swift: $error");
      });

      // استئناف تشغيل الصوت بعد تأخير قصير
      Future.delayed(Duration(milliseconds: 800), () {
        if (!isAppTerminating) {
          audioService.resumePlaybackAfterNavigation();
        }
      });

      // تأخير تحميل إعلان الفتح
      Future.delayed(Duration(seconds: 3), () {
        if (!isAppTerminating) {
          appOpenAdService.loadAd();
        }
      });
    } else if (state == AppLifecycleState.paused) {
      print('📱 التطبيق في الخلفية، جاري حفظ الحالة...');

      // إخطار Swift بأن التطبيق قد توقف مؤقتًا
      _channel.invokeMethod('appPaused').then((_) {
        print("✅ تم إخطار Swift بإيقاف التطبيق مؤقتًا");
      }).catchError((error) {
        print("❌ خطأ في إخطار Swift: $error");
      });

      // حفظ حالة التشغيل قبل الانتقال للخلفية
      audioService.savePlaybackState();

      // استدعاء دالة حفظ الحالة
      _saveAppState();
    } else if (state == AppLifecycleState.detached) {
      print('📱 التطبيق منفصل، جاري حفظ الحالة وتنظيف الموارد...');

      // تعيين متغير إنهاء التطبيق
      isAppTerminating = true;

      // حفظ الحالة وتنظيف الموارد بشكل كامل
      _saveAppState();
      audioService.dispose();

      // إعادة تعيين حالة الفتح الأول لإعلان الفتح
      appOpenAdService.resetFirstOpenState();
    } else if (state == AppLifecycleState.inactive) {
      print('📱 التطبيق غير نشط، جاري حفظ الحالة...');

      // حفظ حالة التشغيل
      audioService.savePlaybackState();

      // استدعاء دالة حفظ الحالة
      _saveAppState();
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
      if (mounted && !isAppTerminating) {
        try {
          await appOpenAdService.loadAd();
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
