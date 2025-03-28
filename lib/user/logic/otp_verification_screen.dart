import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/snack.dart';
import 'package:om_elnour_choir/app_setting/views/home_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String verificationId;
  final bool isEmailVerification;

  const OTPVerificationScreen({
    super.key,
    required this.verificationId,
    required this.isEmailVerification,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final TextEditingController otpController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  Future<void> verifyOTP() async {
    String otp = otpController.text.trim();

    if (otp.length != 6 && !widget.isEmailVerification) {
      ScaffoldMessenger.of(context).showSnackBar(
        snack(txt: "Enter a valid 6-digit OTP", color: Colors.red),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      if (widget.isEmailVerification) {
        // التحقق عبر الإيميل
        await FirebaseAuth.instance.signInWithEmailLink(
          email: widget.verificationId, // الإيميل هو الـ verificationId
          emailLink: otp, // يجب أن يكون الرابط المستلم في الإيميل
        );
      } else {
        // التحقق عبر SMS
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: widget.verificationId,
          smsCode: otp,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        snack(txt: "OTP Verified Successfully", color: Colors.green),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        snack(txt: "Verification Failed: $e", color: Colors.red),
      );
    }

    setState(() => isLoading = false);
  }

  void resendOTP() {
    // TODO: إضافة كود إعادة إرسال OTP حسب طريقة التحقق
    ScaffoldMessenger.of(context).showSnackBar(
      snack(txt: "Resend OTP feature not implemented yet", color: Colors.blue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text(
          "OTP Verification",
          style: TextStyle(color: Colors.amber),
        ),
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Enter the ${widget.isEmailVerification ? 'Email Verification Link' : '6-digit OTP'} sent to your ${widget.isEmailVerification ? 'Email' : 'Phone'}",
              style: const TextStyle(fontSize: 16, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: otpController,
              keyboardType: widget.isEmailVerification
                  ? TextInputType.text
                  : TextInputType.number,
              maxLength: widget.isEmailVerification ? null : 6,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide:
                      const BorderSide(color: Colors.amberAccent, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide:
                      const BorderSide(color: Colors.amberAccent, width: 0.5),
                ),
                counterText: "",
                labelText: widget.isEmailVerification
                    ? "Paste Email Link"
                    : "OTP Code",
                labelStyle: const TextStyle(color: Colors.grey),
              ),
              inputFormatters: widget.isEmailVerification
                  ? null
                  : [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : verifyOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text("Verify OTP", style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: resendOTP,
              child: const Text(
                "Resend OTP",
                style: TextStyle(color: Colors.amberAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
