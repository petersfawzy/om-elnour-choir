import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:om_elnour_choir/app_setting/views/home_screen.dart';
import 'package:om_elnour_choir/user/views/login_screen.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  String appVersion = "3.9.9";
  String latestVersion = "3.9.9";
  bool forceUpdate = false;
  bool isCheckingUpdate = true;

  @override
  void initState() {
    super.initState();
    _fetchRemoteConfig();
  }

  Future<void> _fetchRemoteConfig() async {
    final remoteConfig = FirebaseRemoteConfig.instance;

    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;

      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero,
      ));

      await remoteConfig.fetchAndActivate();

      setState(() {
        latestVersion = remoteConfig.getString('latest_version').isNotEmpty
            ? remoteConfig.getString('latest_version')
            : latestVersion;
        forceUpdate = remoteConfig.getBool('force_update');
      });

      _checkForUpdate();
    } catch (e) {
      print('❌ خطأ في جلب إعدادات التحديث: $e');
      _checkLoginStatus();
    }
  }

  void _checkForUpdate() {
    if (_isUpdateRequired(appVersion, latestVersion)) {
      if (forceUpdate) {
        _showUpdateDialog();
      } else {
        _checkLoginStatus();
      }
    } else {
      _checkLoginStatus();
    }
  }

  bool _isUpdateRequired(String currentVersion, String newVersion) {
    List<int> current = currentVersion.split('.').map(int.parse).toList();
    List<int> latest = newVersion.split('.').map(int.parse).toList();

    while (current.length < latest.length) {
      current.add(0);
    }

    for (int i = 0; i < latest.length; i++) {
      if (current[i] < latest[i]) return true;
      if (current[i] > latest[i]) return false;
    }
    return false;
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("تحديث مطلوب"),
        content: const Text("هناك إصدار جديد من التطبيق، يجب تحديثه للمتابعة."),
        actions: [
          TextButton(
            onPressed: () {
              _launchStore();
              _checkLoginStatus();
            },
            child: const Text("تحديث الآن"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkLoginStatus();
            },
            child: const Text("لاحقاً"),
          ),
        ],
      ),
    );
  }

  void _launchStore() async {
    String appStoreUrl = Platform.isAndroid
        ? "https://play.google.com/store/apps/details?id=com.egypt.redcherry.omelnourchoir"
        : "https://apps.apple.com/us/app/om-elnour-choir/id1660609952";

    Uri uri = Uri.parse(appStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _checkLoginStatus() async {
    print('🔄 جاري التحقق من حالة تسجيل الدخول...');
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) {
      print('❌ Widget غير موجود بعد');
      return;
    }

    try {
      print('🔍 التحقق من Firebase Auth...');
      User? user = FirebaseAuth.instance.currentUser;
      if (!mounted) {
        print('❌ Widget غير موجود بعد');
        return;
      }

      print('👤 حالة المستخدم: ${user != null ? "مسجل" : "غير مسجل"}');
      if (user != null) {
        print('✅ المستخدم مسجل، جاري الانتقال إلى HomeScreen...');
        // إذا كان المستخدم مسجل، انتقل إلى HomeScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        print('❌ المستخدم غير مسجل، جاري الانتقال إلى Login...');
        // إذا لم يكن المستخدم مسجل، انتقل إلى Login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Login()),
        );
      }
    } catch (e) {
      print('❌ خطأ في التحقق من حالة تسجيل الدخول: $e');
      if (mounted) {
        print('⚠️ حدث خطأ، جاري الانتقال إلى Login...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Login()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 150,
              width: 150,
              margin: const EdgeInsets.all(10.0),
              decoration: const BoxDecoration(
                image: DecorationImage(
                    image: AssetImage("assets/images/logo.png"),
                    fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 20),
            const Text('WELCOME TO',
                style: TextStyle(color: Colors.amberAccent, fontSize: 18)),
            const Text('OM ELNOUR CHOIR',
                style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text(
                'مُكَلِّمِينَ بَعْضُكُمْ بَعْضًا بِمَزَامِيرَ وَتَسَابِيحَ وَأَغَانِيَّ رُوحِيَّةٍ،',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.amberAccent, fontSize: 15)),
            const Text(
                'مُتَرَنِّمِينَ وَمُرَتِّلِينَ فِي قُلُوبِكُمْ لِلرَّبِّ." (أف ٥: ١٩).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.amberAccent, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
