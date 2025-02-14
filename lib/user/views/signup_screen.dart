import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/field.dart';
import 'package:om_elnour_choir/shared/shared_widgets/snack.dart';
import 'package:om_elnour_choir/user/views/login_screen.dart';
import 'package:om_elnour_choir/user/views/profile_screen.dart';

import '../../shared/shared_theme/app_fonts.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
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
                image: DecorationImage(
                  image: NetworkImage(
                      'https://scontent.fcai16-1.fna.fbcdn.net/v/t39.30808-6/317447083_104679542484214_1593274143128685249_n.jpg?_nc_cat=101&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=JS0Q59ySFYgQ7kNvgHTeDKd&_nc_zt=23&_nc_ht=scontent.fcai16-1.fna&_nc_gid=AQ9o2WB1f7oyN19TbLaWE4S&oh=00_AYB61wF66dfzEGxQ5AHkibdqhafkB149wWET1nyQglYeyg&oe=679C12EE'),
                  fit: BoxFit.contain,
                ),
                shape: BoxShape.circle),
          ),
          // Ink.image(image: NetworkImage('https://scontent.fcai16-1.fna.fbcdn.net/v/t39.30808-6/317447083_104679542484214_1593274143128685249_n.jpg?_nc_cat=101&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=JS0Q59ySFYgQ7kNvgHTeDKd&_nc_zt=23&_nc_ht=scontent.fcai16-1.fna&_nc_gid=AQ9o2WB1f7oyN19TbLaWE4S&oh=00_AYB61wF66dfzEGxQ5AHkibdqhafkB149wWET1nyQglYeyg&oe=679C12EE')),
          const SizedBox(
            height: 20,
          ),
          const Text(
            'Creat Your Account',
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
                color: Colors.grey,
                iconSize: 15,
                onPressed: () {
                  isSecure = !isSecure;
                  setState(() {});
                },
              )),
          const SizedBox(height: 30.0),
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
                        snack(txt: 'Success', color: Colors.green));
                    Navigator.pushReplacement(
                        context,
                        CupertinoPageRoute(
                            builder: (_) => const ProfileScreen()));
                  }
                },
                child: Text(
                  'Signup',
                  style: AppFonts.miniBackStyle,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          const SizedBox(height: 30.0),
          InkWell(
            onTap: () {
              Navigator.push(
                  context, CupertinoPageRoute(builder: (_) => const Login()));
            },
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "alreay have an account?! signin",
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
