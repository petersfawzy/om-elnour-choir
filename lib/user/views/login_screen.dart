import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:om_elnour_choir/app_setting/views/home_screen.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_fonts.dart';
import 'package:om_elnour_choir/shared/shared_widgets/field.dart';
import 'package:om_elnour_choir/shared/shared_widgets/snack.dart';
import 'package:om_elnour_choir/user/views/signup_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  bool isSecure = true;
  bool isLoading = false;

  // دالة تسجيل الدخول
  Future<void> loginUser() async {
    if (emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(snack(txt: 'Email Required'));
      return;
    }
    if (passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(snack(txt: 'Password Required'));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // تسجيل الدخول في Firebase Auth
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // الحصول على UID الخاص بالمستخدم
      String uid = userCredential.user!.uid;

      // البحث عن المستخدم في Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        // نجاح تسجيل الدخول والانتقال للصفحة الرئيسية
        ScaffoldMessenger.of(context)
            .showSnackBar(snack(txt: 'Login Successful', color: Colors.green));

        Navigator.pushReplacement(
            context, CupertinoPageRoute(builder: (_) => const HomeScreen()));
      } else {
        // المستخدم غير موجود في قاعدة البيانات
        ScaffoldMessenger.of(context).showSnackBar(
            snack(txt: 'User not found in database', color: Colors.redAccent));
        FirebaseAuth.instance.signOut();
      }
    } on FirebaseAuthException catch (e) {
      // التعامل مع أخطاء Firebase
      String errorMessage = "Login failed";
      if (e.code == 'user-not-found') {
        errorMessage = "No user found for this email.";
      } else if (e.code == 'wrong-password') {
        errorMessage = "Wrong password.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "Invalid email format.";
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(snack(txt: errorMessage, color: Colors.redAccent));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 150,
            width: 150,
            margin: const EdgeInsets.all(10.0),
            decoration: const BoxDecoration(
              image:
                  DecorationImage(image: AssetImage("assets/images/logo.png")),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Login To Your Account',
            style: TextStyle(fontSize: 30, color: Colors.amberAccent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          field(
              label: 'Email Address',
              icon: Icons.email,
              controller: emailController,
              textInputType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next),
          const SizedBox(height: 30.0),
          field(
              label: 'Password',
              icon: Icons.lock,
              controller: passwordController,
              textInputType: TextInputType.text,
              textInputAction: TextInputAction.done,
              isSecure: isSecure,
              suffixIcon: IconButton(
                icon: Icon(
                  isSecure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.amberAccent,
                  size: 15,
                ),
                onPressed: () {
                  setState(() {
                    isSecure = !isSecure;
                  });
                },
              )),
          const SizedBox(height: 15.0),
          Align(
            alignment: Alignment.bottomRight,
            child: InkWell(
                onTap: () {},
                child: const Text(
                  'Forget Password ?',
                  style: TextStyle(color: Colors.amberAccent),
                )),
          ),
          const SizedBox(height: 15.0),
          Column(
            children: [
              TextButton(
                style: TextButton.styleFrom(
                    backgroundColor: Colors.amber[200],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    fixedSize: const Size(200, 50)),
                onPressed: isLoading ? null : loginUser,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Login',
                        style: AppFonts.miniBackStyle,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 30.0),
          InkWell(
            onTap: () {
              Navigator.push(context,
                  CupertinoPageRoute(builder: (_) => const SignupScreen()));
            },
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account ? Sign up",
                  style: TextStyle(color: Colors.amberAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
