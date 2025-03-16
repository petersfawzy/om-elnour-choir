import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/field.dart';
import 'package:om_elnour_choir/shared/shared_widgets/snack.dart';
import 'package:om_elnour_choir/user/logic/otp_verification_screen.dart';

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
  bool isLoading = false;
  String verificationMethod = 'Email';

  @override
  void dispose() {
    emailController.dispose();
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> requestPermissions() async {
    await Permission.photos.request();
    await Permission.camera.request();
  }

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> signup() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    String email = emailController.text.trim();
    String phone = phoneController.text.trim();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();
    String name = nameController.text.trim();

    if (name.isEmpty) {
      showError('Enter your name');
      return;
    }
    if (password.isEmpty || password.length < 6) {
      showError('Password must be at least 6 characters');
      return;
    }
    if (password != confirmPassword) {
      showError('Passwords do not match');
      return;
    }

    try {
      if (verificationMethod == "Email") {
        if (email.isEmpty) {
          showError('Enter a valid email');
          return;
        }

        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await FirebaseFirestore.instance
            .collection("userData")
            .doc(userCredential.user!.uid)
            .set({
          "uid": userCredential.user!.uid,
          "name": name,
          "email": email,
          "phone": phone,
          "profileImage": "assets/images/logo.png", // ✅ إضافة الصورة الافتراضية
        });

        await userCredential.user?.sendEmailVerification();
        navigateToVerification(email, true);
      } else {
        if (phone.isEmpty || !RegExp(r"^[0-9]+$").hasMatch(phone)) {
          showError('Enter a valid phone number');
          return;
        }

        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: "+2$phone",
          verificationCompleted: (PhoneAuthCredential credential) {},
          verificationFailed: (FirebaseAuthException e) {
            showError("Phone verification failed: ${e.message}");
          },
          codeSent: (String verificationId, int? resendToken) {
            navigateToVerification(verificationId, false);
          },
          codeAutoRetrievalTimeout: (String verificationId) {},
        );
      }
    } catch (e) {
      showError('Signup Failed: ${e.toString()}');
    }

    setState(() => isLoading = false);
  }

  void showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(snack(txt: message, color: Colors.red));
    setState(() => isLoading = false);
  }

  void navigateToVerification(String id, bool isEmail) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OTPVerificationScreen(
          verificationId: id,
          isEmailVerification: isEmail,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Signup", style: TextStyle(color: Colors.amber)),
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: BackBtn(),
      ),
      backgroundColor: AppColors.backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                Image.asset('assets/images/logo.png', height: 130),
                const SizedBox(height: 10),
                field(
                    label: "Name",
                    icon: Icons.person,
                    controller: nameController,
                    textInputType: TextInputType.name,
                    textInputAction: TextInputAction.next),
                const SizedBox(height: 10),
                field(
                    label: "Email",
                    icon: Icons.email,
                    controller: emailController,
                    textInputType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next),
                const SizedBox(height: 10),
                field(
                    label: "Phone",
                    icon: Icons.phone,
                    controller: phoneController,
                    textInputType: TextInputType.phone,
                    textInputAction: TextInputAction.next),
                const SizedBox(height: 10),
                field(
                  label: "Password",
                  icon: Icons.lock,
                  controller: passwordController,
                  textInputType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  isSecure: isSecure,
                  suffixIcon: IconButton(
                    icon: Icon(
                        isSecure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.amber),
                    onPressed: () {
                      setState(() => isSecure = !isSecure);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                field(
                  label: "Confirm Password",
                  icon: Icons.lock,
                  controller: confirmPasswordController,
                  textInputType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  isSecure: isConfirmSecure,
                  suffixIcon: IconButton(
                    icon: Icon(
                        isConfirmSecure
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.amber),
                    onPressed: () {
                      setState(() => isConfirmSecure = !isConfirmSecure);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Verify via:",
                        style: TextStyle(color: Colors.amber)),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: verificationMethod,
                      dropdownColor: AppColors.backgroundColor,
                      items: ["Email", "SMS"]
                          .map((method) => DropdownMenuItem(
                              value: method,
                              child: Text(method,
                                  style: TextStyle(color: Colors.amber))))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => verificationMethod = value!),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isLoading ? null : signup,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  child: isLoading
                      ? CircularProgressIndicator(color: Colors.black)
                      : Text("Signup", style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
