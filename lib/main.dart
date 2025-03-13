import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/app_setting/logic/news_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_cubit.dart';
import 'package:om_elnour_choir/app_setting/views/home_screen.dart';
import 'package:om_elnour_choir/app_setting/views/intro_screen.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/user/views/login_screen.dart';
import 'package:om_elnour_choir/user/views/profile_screen.dart';
import 'package:om_elnour_choir/user/views/signup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  await Firebase.initializeApp();
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => CopticCalendarCubit()),
        BlocProvider(create: (context) => DailyBreadCubit()),
        BlocProvider(create: (context) => VerceCubit()),
        BlocProvider(
          create: (context) =>
              HymnsCubit(Myaudioservice(), DefaultCacheManager()),
        ),
        BlocProvider(create: (context) => NewsCubit())
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  HymnsCubit? hymnsCubit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      hymnsCubit = context.read<HymnsCubit>();
      restoreLastHymn();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final hymnsCubit = context.read<HymnsCubit>();

    if (state == AppLifecycleState.inactive) {
      // ✅ لا توقف الترانيم، فقط احفظ الموضع عند تصغير التطبيق
      saveLastHymnState();
    } else if (state == AppLifecycleState.resumed) {
      // ✅ لا تقم بإعادة تشغيل الترانيم، دعها تستمر
      restoreLastHymn();
    } else if (state == AppLifecycleState.detached) {
      // ✅ عند إغلاق التطبيق بالكامل، أوقف الترانيم
      hymnsCubit.stopHymn();
    }
  }

  void saveLastHymnState() async {
    if (hymnsCubit?.currentHymn == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastPosition_${hymnsCubit!.currentHymn!.songUrl}',
        hymnsCubit!.currentPosition.inSeconds);
    await prefs.setString('lastHymnUrl', hymnsCubit!.currentHymn!.songUrl);
    await prefs.setString('lastHymnName', hymnsCubit!.currentHymn!.songName);
  }

  void restoreLastHymn() async {
    final hymnsCubit = context.read<HymnsCubit>();
    final prefs = await SharedPreferences.getInstance();

    String? lastHymnUrl = prefs.getString('lastHymnUrl');
    String? lastHymnName = prefs.getString('lastHymnName');
    int? lastPosition = prefs.getInt('lastPosition_$lastHymnUrl');

    if (lastHymnUrl != null && lastHymnName != null) {
      HymnsModel hymn = HymnsModel(
        id: 'unknown',
        songName: lastHymnName,
        songUrl: lastHymnUrl,
        category: 'unknown',
        album: 'unknown',
        views: 0,
      );

      hymnsCubit.restoreLastHymn(hymn, lastPosition ?? 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: IntroScreen(),
      routes: {
        '/login': (context) => Login(),
        '/home': (context) => HomeScreen(),
        '/signup': (context) => SignupScreen(),
        '/profile': (context) => ProfileScreen(),
      },
    );
  }
}
