import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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

// تعديل دالة معالجة الإشعارات في الخلفية
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // تأكد من تهيئة Firebase قبل استخدامه
  await Firebase.initializeApp();
  print("🔔 إشعار في الخلفية: ${message.notification?.title}");
  print("📦 بيانات الإشعار: ${message.data}");
}

void main() async {
  // تأكد من تهيئة Flutter قبل استدعاء أي شيء آخر
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Firebase
  await Firebase.initializeApp();

  // تهيئة Firebase App Check
  await FirebaseAppCheck.instance.activate(
    // استخدم وضع التصحيح في بيئة التطوير
    androidProvider: AndroidProvider.debug,
  );

  // تسجيل معالج الإشعارات في الخلفية
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // تهيئة Remote Config
  await remoteConfigService.initialize();

  // تهيئة الألوان
  AppColors.initialize();

  // تهيئة الإعلانات بشكل مباشر
  await MobileAds.instance.initialize();

  // تحميل إعلان الفتح مباشرة بعد تهيئة الإعلانات
  // هذا سيضمن أن الإعلان جاهز عند بدء التطبيق
  print("🔄 تحميل إعلان الفتح مباشرة عند بدء التطبيق...");
  await appOpenAdService.loadAd();

  // إعدادات Firestore
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);

  // إعداد إشعارات Firebase
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // طلب الأذونات اللازمة للإشعارات
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  print('إعدادات الإشعارات: ${settings.authorizationStatus}');

  // التحقق من أول استخدام للتطبيق
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool firstTime = prefs.getBool('firstTime') ?? true;

  if (firstTime) {
    await prefs.setBool('firstTime', false);
  }

  // إضافة مستمع لحالة التطبيق
  WidgetsBinding.instance.addObserver(AppLifecycleObserver());

  // تهيئة خدمة الإشعارات
  final notificationService = NotificationService(navigatorKey: navigatorKey);
  await notificationService.initialize();

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

            // تم إزالة استدعاء restoreLastHymn المتأخر لتجنب التداخل مع استدعاءات أخرى
            // سيتم استدعاء restoreLastHymn في HymnsPage.initState فقط

            return hymnsCubit;
          },
        ),
        BlocProvider(create: (context) => NewsCubit()),
      ],
      child: MyApp(navigatorKey: navigatorKey, firstTime: firstTime),
    ),
  );
}

// تعديل فئة AppLifecycleObserver
class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('🔄 تغيرت حالة دورة حياة التطبيق: $state');

    if (state == AppLifecycleState.resumed) {
      // عند العودة من الخلفية، نتأكد من استئناف التشغيل إذا كان مطلوباً
      print("📱 التطبيق عاد من الخلفية");

      // استئناف تشغيل الصوت إذا كان مطلوباً
      audioService.resumePlaybackAfterNavigation();

      // تأخير تحميل إعلان الفتح لتجنب التنافس على الموارد
      Future.delayed(Duration(seconds: 3), () {
        appOpenAdService.loadAd();
      });
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      print('📱 التطبيق في الخلفية، جاري حفظ الحالة...');

      // حفظ حالة التشغيل قبل الانتقال للخلفية
      audioService.savePlaybackState();
    } else if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      print('📱 التطبيق منفصل أو مخفي، جاري حفظ الحالة...');

      // حفظ حالة التشغيل بشكل كامل عند إغلاق التطبيق
      audioService.saveStateOnAppClose();

      // الوصول إلى HymnsCubit من خلال BuildContext
      final context = navigatorKey.currentContext;
      if (context != null) {
        try {
          final hymnsCubit =
              BlocProvider.of<HymnsCubit>(context, listen: false);
          hymnsCubit.saveStateOnAppClose();
        } catch (e) {
          print('❌ خطأ في الوصول إلى HymnsCubit: $e');
        }
      }
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

    // عرض الإعلان عند فتح التطبيق لأول مرة
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // تقليل التأخير لعرض الإعلان بشكل أسرع
      await Future.delayed(Duration(seconds: 2));

      if (isFirstOpen) {
        print("🔄 محاولة عرض إعلان الفتح عند بدء التطبيق...");
        bool adShown = await appOpenAdService.showAdIfAvailable();
        print("📊 نتيجة عرض الإعلان: ${adShown ? 'تم العرض' : 'لم يتم العرض'}");

        // إذا لم يتم عرض الإعلان، حاول مرة أخرى بعد تأخير قصير
        if (!adShown) {
          print("⚠️ لم يتم عرض الإعلان، محاولة مرة أخرى بعد تأخير...");
          await Future.delayed(Duration(seconds: 1));
          await appOpenAdService.loadAd(); // تحميل الإعلان مرة أخرى
          await Future.delayed(Duration(seconds: 1));
          adShown = await appOpenAdService.showAdIfAvailable();
          print(
              "📊 نتيجة المحاولة الثانية: ${adShown ? 'تم العرض' : 'لم يتم العرض'}");
        }

        isFirstOpen = false;
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
      navigatorKey: widget.navigatorKey, // استخدام المفتاح العام
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.amber,
        fontFamily: 'Cairo',
      ),
      home: const IntroScreen(), // تعديل هنا: دائمًا ابدأ بشاشة المقدمة
      routes: {
        '/login': (context) => Login(),
        '/home': (context) => HomeScreen(),
        '/signup': (context) => SignupScreen(),
        '/profile': (context) => ProfileScreen(),
      },
    );
  }
}
