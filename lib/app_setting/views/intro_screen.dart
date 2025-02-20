import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:om_elnour_choir/app_setting/views/home_screen.dart';
import 'package:om_elnour_choir/user/views/login_screen.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  /// ✅ **التحقق من تسجيل الدخول**
  void _checkLoginStatus() async {
    await Future.delayed(
        const Duration(seconds: 4)); // ⏳ تأخير بسيط قبل الانتقال

    if (!mounted)
      return; // ✅ تجنب الأخطاء في حالة خروج المستخدم من الصفحة قبل التحميل

    User? user = FirebaseAuth.instance.currentUser;

    /// 🚀 **التوجيه بناءً على حالة المستخدم**
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => user != null ? const HomeScreen() : const Login(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// ✅ **اللوجو**
            Container(
              height: 150,
              width: 150,
              margin: const EdgeInsets.all(10.0),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/logo.png"),
                ),
              ),
            ),
            const SizedBox(height: 20),

            /// ✅ **عنوان الترحيب**
            const Text(
              'WELCOME TO',
              style: TextStyle(color: Colors.amberAccent, fontSize: 18),
            ),
            const Text(
              'OM ELNOUR CHOIR',
              style: TextStyle(color: Colors.amberAccent, fontSize: 18),
            ),

            const SizedBox(height: 10),

            /// ✅ **الآية الكتابية**
            const Text(
              'مُكَلِّمِينَ بَعْضُكُمْ بَعْضًا بِمَزَامِيرَ وَتَسَابِيحَ وَأَغَانِيَّ رُوحِيَّةٍ،',
              style: TextStyle(color: Colors.amberAccent, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const Text(
              'مُتَرَنِّمِينَ وَمُرَتِّلِينَ فِي قُلُوبِكُمْ لِلرَّبِّ." (أف ٥: ١٩).',
              style: TextStyle(color: Colors.amberAccent, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
