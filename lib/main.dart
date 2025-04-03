import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/hymn_repository.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/news_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_cubit.dart';
import 'package:om_elnour_choir/app_setting/views/home_screen.dart';
import 'package:om_elnour_choir/app_setting/views/intro_screen.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/user/views/login_screen.dart';
import 'package:om_elnour_choir/user/views/profile_screen.dart';
import 'package:om_elnour_choir/user/views/signup_screen.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🔔 إشعار في الخلفية: ${message.notification?.title}");
}

final MyAudioService audioService = MyAudioService();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ التأكد من تهيئة Firebase مرة واحدة فقط
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  await MobileAds.instance.initialize();
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);

  FirebaseMessaging messaging = FirebaseMessaging.instance;
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // String? token = await messaging.getToken();
  // print('📱 FCM Token: $token');

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool firstTime = prefs.getBool('firstTime') ?? true;

  if (firstTime) {
    await prefs.setBool('firstTime', false);
  }

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => CopticCalendarCubit()),
        BlocProvider(create: (context) => DailyBreadCubit()),
        BlocProvider(create: (context) => VerceCubit()),
        BlocProvider(
          create: (context) {
            final hymnsCubit = HymnsCubit(HymnsRepository(), audioService);
            hymnsCubit
                .restoreLastHymn(); // ✅ استعادة آخر ترنيمة تلقائيًا عند بدء التطبيق
            return hymnsCubit;
          },
        ),
        BlocProvider(create: (context) => NewsCubit()),
      ],
      child: MyApp(firstTime: firstTime),
    ),
  );
}

class MyApp extends StatefulWidget {
  final bool firstTime;
  const MyApp({super.key, required this.firstTime});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupFirebaseMessaging();
  }

  void _setupFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 إشعار وارد: ${message.notification?.title}");
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📬 تم فتح التطبيق من الإشعار: ${message.notification?.title}");
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
