// import 'package:carea/shared/shared_widgets/nav_bar.dart';
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
          const SizedBox(
            height: 20,
          ),
          const Text(
            'Login To Your Account',
            style: TextStyle(fontSize: 30, color: Colors.amberAccent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(
            height: 20,
          ),
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
                icon: const Icon(Icons.remove_red_eye),
                color: Colors.amberAccent,
                iconSize: 15,
                onPressed: () {
                  isSecure = !isSecure;
                  setState(() {});
                },
              )),
          const SizedBox(height: 15.0),
          Align(
            alignment: Alignment.bottomRight,
            child: InkWell(
                onTap: () {},
                child: const Text(
                  'Forget Password ?  ',
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
                onPressed: () {
                  if (emailController.text.isEmpty) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(snack(txt: 'Email Required'));
                  } else if (passwordController.text.isEmpty) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(snack(txt: 'Password Required'));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                        snack(txt: 'Success', color: Colors.amberAccent));
                    Navigator.pushReplacement(context,
                        CupertinoPageRoute(builder: (_) => const HomeScreen()));
                    // Navigator.pushReplacement(
                    // context,
                    // CupertinoPageRoute(
                    // builder: (_) => const BottomNavBarScreen()));
                  }
                },
                child: Text(
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
    // );
  }
}
