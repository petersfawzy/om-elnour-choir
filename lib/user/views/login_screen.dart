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
  TextEditingController userInputController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  bool isSecure = true;
  bool isLoading = false;

  @override
  void dispose() {
    userInputController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// ✅ **التأكد مما إذا كان المدخل بريدًا إلكترونيًا أم رقم هاتف**
  bool isEmail(String input) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(input);
  }

  /// ✅ **تسجيل الدخول بالبريد أو رقم الهاتف**
  Future<void> loginUser() async {
    if (userInputController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(snack(txt: 'Enter Email or Phone'));
      return;
    }
    if (passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(snack(txt: 'Enter Password'));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      UserCredential userCredential;

      if (isEmail(userInputController.text)) {
        /// 📧 **تسجيل الدخول بالبريد**
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: userInputController.text.trim(),
          password: passwordController.text.trim(),
        );
      } else {
        /// 📱 **تسجيل الدخول برقم الهاتف**
        QuerySnapshot userQuery = await FirebaseFirestore.instance
            .collection('userData')
            .where('phone', isEqualTo: userInputController.text.trim())
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          throw FirebaseAuthException(
              code: 'user-not-found', message: 'No user found for this phone.');
        }

        String email = userQuery.docs.first['email'];

        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: passwordController.text.trim(),
        );
      }

      String uid = userCredential.user!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        ScaffoldMessenger.of(context)
            .showSnackBar(snack(txt: 'Login Successful', color: Colors.green));

        Future.delayed(const Duration(milliseconds: 300), () {
          Navigator.pushReplacement(
              context, CupertinoPageRoute(builder: (_) => const HomeScreen()));
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            snack(txt: 'User not found in database', color: Colors.redAccent));
        FirebaseAuth.instance.signOut();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Login failed";
      if (e.code == 'user-not-found') {
        errorMessage = "No user found for this email/phone.";
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

  /// ✅ **إعادة تعيين كلمة السر (للبريد فقط)**
  Future<void> resetPassword() async {
    if (userInputController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(snack(txt: 'Enter your email first!'));
      return;
    }
    if (!isEmail(userInputController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(snack(
          txt: 'Password reset only available for email!',
          color: Colors.redAccent));
      return;
    }
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: userInputController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
          snack(txt: 'Password reset email sent!', color: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          snack(txt: 'Failed to send reset email', color: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: constraints.maxWidth > 600 ? 200 : 150,
                    width: constraints.maxWidth > 600 ? 200 : 150,
                    margin: const EdgeInsets.all(10.0),
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                          image: AssetImage("assets/images/logo.png")),
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
                      label: 'Email or Phone',
                      icon: Icons.person,
                      controller: userInputController,
                      textInputType: TextInputType.text,
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
                          size: 20,
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
                        onTap: resetPassword,
                        child: const Text(
                          'Forgot Password?',
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
                            ? const CircularProgressIndicator(
                                color: Colors.white)
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
                      Navigator.push(
                          context,
                          CupertinoPageRoute(
                              builder: (_) => const SignupScreen()));
                    },
                    child: const Text(
                      "Don't have an account? Sign up",
                      style: TextStyle(color: Colors.amberAccent),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
