import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_fonts.dart';
import 'package:om_elnour_choir/shared/shared_widgets/field.dart';
import 'package:om_elnour_choir/shared/shared_widgets/snack.dart';
import 'package:om_elnour_choir/user/views/login_screen.dart';
import 'package:om_elnour_choir/user/views/profile_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  bool isSecure = true;
  bool isConfirmSecure = true;

  File? _image;
  final ImagePicker _picker = ImagePicker();

  /// ✅ اختيار صورة من المعرض
  Future<void> pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  /// ✅ رفع الصورة إلى Firebase Storage
  Future<String?> uploadImageToFirebase() async {
    if (_image == null) return null;

    try {
      String fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
      Reference ref =
          FirebaseStorage.instance.ref().child("profile_images/$fileName");
      await ref.putFile(_image!);
      return await ref.getDownloadURL();
    } catch (e) {
      print("❌ خطأ أثناء رفع الصورة: $e");
      return null;
    }
  }

  /// ✅ التحقق من صحة المدخلات وإنشاء الحساب في Firebase
  Future<void> signup() async {
    String email = emailController.text.trim();
    String phone = phoneController.text.trim();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();
    String name = nameController.text.trim();

    if (email.isEmpty ||
        !RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
            .hasMatch(email)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(snack(txt: 'Enter a valid email', color: Colors.red));
      return;
    }
    if (name.isEmpty || !RegExp(r"^[a-zA-Z\s]+$").hasMatch(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
          snack(txt: 'Enter a valid name (letters only)', color: Colors.red));
      return;
    }
    if (phone.isEmpty || !RegExp(r"^[0-9]+$").hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
          snack(txt: 'Enter a valid phone number', color: Colors.red));
      return;
    }
    if (password.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(snack(
          txt: 'Password must be at least 6 characters', color: Colors.red));
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
          snack(txt: 'Passwords do not match', color: Colors.red));
      return;
    }

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String? imageUrl = await uploadImageToFirebase();

      // ✅ حفظ بيانات المستخدم في Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': name,
        'email': email,
        'phone': phone,
        'profileImage': imageUrl ?? '',
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(snack(txt: 'Signup Successful', color: Colors.green));

      Navigator.pushReplacement(
          context, CupertinoPageRoute(builder: (_) => const ProfileScreen()));
    } catch (e) {
      print("❌ خطأ أثناء التسجيل: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(snack(txt: 'Signup Failed: $e', color: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: pickImage,
            child: CircleAvatar(
              radius: 75,
              backgroundColor: Colors.amber[200],
              backgroundImage: _image != null
                  ? FileImage(_image!) as ImageProvider
                  : const AssetImage("assets/images/logo.png"),
              child: _image == null
                  ? const Icon(Icons.camera_alt, color: Colors.white, size: 40)
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Create Your Account',
            style: TextStyle(fontSize: 30, color: Colors.amberAccent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          field(
              label: 'Name',
              icon: Icons.person,
              controller: nameController,
              textInputType: TextInputType.text,
              textInputAction: TextInputAction.next),
          const SizedBox(height: 20),
          field(
              label: 'Phone Number',
              icon: Icons.phone,
              controller: phoneController,
              textInputType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              formaters: [FilteringTextInputFormatter.digitsOnly]),
          const SizedBox(height: 20),
          field(
              label: 'Email Address',
              icon: Icons.email,
              controller: emailController,
              textInputType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              formaters: [
                FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9@._-]"))
              ]),
          const SizedBox(height: 20),
          field(
              label: 'Password',
              icon: Icons.lock,
              controller: passwordController,
              textInputType: TextInputType.text,
              textInputAction: TextInputAction.next,
              isSecure: isSecure,
              suffixIcon: IconButton(
                icon: const Icon(Icons.remove_red_eye),
                color: Colors.grey,
                iconSize: 15,
                onPressed: () {
                  setState(() {
                    isSecure = !isSecure;
                  });
                },
              )),
          const SizedBox(height: 20),
          field(
              label: 'Confirm Password',
              icon: Icons.lock,
              controller: confirmPasswordController,
              textInputType: TextInputType.text,
              textInputAction: TextInputAction.done,
              isSecure: isConfirmSecure,
              suffixIcon: IconButton(
                icon: const Icon(Icons.remove_red_eye),
                color: Colors.grey,
                iconSize: 15,
                onPressed: () {
                  setState(() {
                    isConfirmSecure = !isConfirmSecure;
                  });
                },
              )),
          const SizedBox(height: 30),
          TextButton(
            style: TextButton.styleFrom(
                backgroundColor: Colors.amber[200],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                fixedSize: const Size(200, 50)),
            onPressed: signup,
            child: Text('Signup', style: AppFonts.miniBackStyle),
          ),
        ],
      ),
    );
  }
}
