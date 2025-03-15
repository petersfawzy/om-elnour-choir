import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:om_elnour_choir/app_setting/views/home_screen.dart';
import 'package:om_elnour_choir/user/views/login_screen.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io'; // 📌 لتحديد النظام (iOS / Android)

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  String appVersion = "1.0.0"; // 📌 إصدار التطبيق الحالي
  String latestVersion = "3.9.9"; // 📌 أحدث إصدار متاح
  bool forceUpdate = true; // 📌 هل التحديث إجباري؟
  bool isCheckingUpdate = true; // 📌 لتجنب التنقل أثناء فحص التحديث

  @override
  void initState() {
    super.initState();
    _fetchRemoteConfig();
  }

  /// ✅ **تحميل البيانات من `Firebase Remote Config`**
  Future<void> _fetchRemoteConfig() async {
    final remoteConfig = FirebaseRemoteConfig.instance;

    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version; // الحصول على إصدار التطبيق الحالي

      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero, // ⚡ التحديث الفوري
      ));

      await remoteConfig.fetchAndActivate();

      setState(() {
        latestVersion = remoteConfig.getString('latest_version').isNotEmpty
            ? remoteConfig.getString('latest_version')
            : latestVersion;
        forceUpdate = remoteConfig.getBool('force_update');
      });

      print(
          "📢 الإصدار الحالي: $appVersion | آخر إصدار: $latestVersion | إجباري؟ $forceUpdate");

      // التحقق من وجود تحديث
      _checkForUpdate();
    } catch (e) {
      print("🔥 خطأ أثناء جلب `Remote Config`: $e");
      _checkLoginStatus(); // إذا فشل الجلب، ننتقل مباشرةً
    }
  }

  /// ✅ **التحقق من التحديثات**
  void _checkForUpdate() {
    if (_isUpdateRequired(appVersion, latestVersion)) {
      if (forceUpdate) {
        _showUpdateDialog(); // 🚨 رسالة تحديث إجباري
      } else {
        _checkLoginStatus(); // ✅ متابعة التشغيل بدون تحديث
      }
    } else {
      _checkLoginStatus(); // ✅ لا حاجة للتحديث
    }
  }

  /// ✅ **مقارنة الإصدارات**
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

  /// ✅ **عرض رسالة التحديث الإجباري**
  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // المستخدم لا يستطيع إغلاقها بدون تحديث
      builder: (context) => AlertDialog(
        title: const Text("تحديث مطلوب"),
        content: const Text("هناك إصدار جديد من التطبيق، يجب تحديثه للمتابعة."),
        actions: [
          TextButton(
            onPressed: () => _launchStore(),
            child: const Text("تحديث الآن"),
          ),
        ],
      ),
    );
  }

  /// ✅ **فتح متجر التطبيقات**
  void _launchStore() async {
    String appStoreUrl = Platform.isAndroid
        ? "https://play.google.com/store/apps/details?id=com.example.om_elnour_choir" // استبدله برابط التطبيق الحقيقي
        : "https://apps.apple.com/app/id123456789"; // استبدله برابط التطبيق في App Store

    try {
      if (await canLaunchUrl(Uri.parse(appStoreUrl))) {
        await launchUrl(Uri.parse(appStoreUrl),
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print("⚠️ خطأ أثناء محاولة فتح المتجر: $e");
    }
  }

  /// ✅ **التحقق من تسجيل الدخول**
  void _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2)); // ⏳ تأخير بسيط
    if (!mounted) return;

    User? user = FirebaseAuth.instance.currentUser;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => user != null ? const HomeScreen() : const Login(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Center(
        child: isCheckingUpdate
            ? const CircularProgressIndicator() // 🔄 عرض تحميل أثناء فحص التحديث
            : const SizedBox(), // فارغ إذا لم يكن هناك تحديث
      ),
    );
  }
}
