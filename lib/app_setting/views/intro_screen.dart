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
    if (!mounted) return;

    User? user = FirebaseAuth.instance.currentUser;

    /// 🚀 **التوجيه بناءً على حالة المستخدم**
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
    final orientation = MediaQuery.of(context).orientation;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            double logoSize = screenWidth * 0.3; // نسبة من عرض الشاشة
            double fontSize = screenWidth * 0.04; // نسبة من عرض الشاشة
            double textSpacing = screenHeight * 0.02; // نسبة من ارتفاع الشاشة

            /// ✅ **الوضع العمودي (Portrait)**
            if (orientation == Orientation.portrait) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: screenHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      /// ✅ **اللوجو**
                      Container(
                        height: logoSize,
                        width: logoSize,
                        margin: EdgeInsets.all(screenWidth * 0.03),
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage("assets/images/logo.png"),
                          ),
                        ),
                      ),
                      SizedBox(height: textSpacing),

                      /// ✅ **عنوان الترحيب**
                      Text(
                        'WELCOME TO',
                        style: TextStyle(
                            color: Colors.amberAccent, fontSize: fontSize),
                      ),
                      Text(
                        'OM ELNOUR CHOIR',
                        style: TextStyle(
                            color: Colors.amberAccent, fontSize: fontSize),
                      ),

                      SizedBox(height: textSpacing),

                      /// ✅ **الآية الكتابية**
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                        child: Column(
                          children: [
                            Text(
                              'مُكَلِّمِينَ بَعْضُكُمْ بَعْضًا بِمَزَامِيرَ وَتَسَابِيحَ وَأَغَانِيَّ رُوحِيَّةٍ،',
                              style: TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: fontSize * 0.7),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              'مُتَرَنِّمِينَ وَمُرَتِّلِينَ فِي قُلُوبِكُمْ لِلرَّبِّ." (أف ٥: ١٩).',
                              style: TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: fontSize * 0.8),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            /// ✅ **الوضع الأفقي (Landscape)**
            else {
              return Center(
                child: Container(
                  width: screenWidth,
                  height: screenHeight,
                  color: AppColors.backgroundColor, // ✅ تغطية الشاشة بالكامل
                  alignment: Alignment.center, // ✅ ضمان توسيط المحتوى
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly, // ✅ توزيع أفضل للعناصر
                      children: [
                        /// ✅ **اللوجو بجانب النصوص**
                        Container(
                          height: logoSize * 0.8,
                          width: logoSize * 0.8,
                          margin: EdgeInsets.only(right: screenWidth * 0.03),
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage("assets/images/logo.png"),
                            ),
                          ),
                        ),

                        /// ✅ **النصوص بجانب اللوجو**
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'WELCOME TO',
                                style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: fontSize),
                              ),
                              Text(
                                'OM ELNOUR CHOIR',
                                style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: fontSize),
                              ),
                              SizedBox(height: textSpacing),

                              /// ✅ **الآية الكتابية**
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: screenWidth * 0.02),
                                child: Column(
                                  children: [
                                    Text(
                                      'مُكَلِّمِينَ بَعْضُكُمْ بَعْضًا بِمَزَامِيرَ وَتَسَابِيحَ وَأَغَانِيَّ رُوحِيَّةٍ،',
                                      style: TextStyle(
                                          color: Colors.amberAccent,
                                          fontSize: fontSize * 0.8),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      'مُتَرَنِّمِينَ وَمُرَتِّلِينَ فِي قُلُوبِكُمْ لِلرَّبِّ." (أف ٥: ١٩).',
                                      style: TextStyle(
                                          color: Colors.amberAccent,
                                          fontSize: fontSize * 0.8),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
