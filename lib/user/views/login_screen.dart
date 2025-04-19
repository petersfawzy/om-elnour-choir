import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:om_elnour_choir/shared/shared_widgets/scaffold_with_background.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:om_elnour_choir/user/logic/auth_service.dart';
import 'package:om_elnour_choir/services/remote_config_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController forgotPasswordEmailController =
      TextEditingController();
  final AuthService _authService = AuthService();
  final RemoteConfigService _remoteConfigService = RemoteConfigService();

  bool isSecure = true;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    forgotPasswordEmailController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (isLoading) return;

    setState(() => isLoading = true);

    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال بريد إلكتروني صالح'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال كلمة المرور'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
      return;
    }

    final userCredential = await _authService.signInWithEmailAndPassword(
      email,
      password,
      context,
    );

    if (userCredential != null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  // عرض مربع حوار نسيت كلمة المرور
  void _showForgotPasswordDialog() {
    forgotPasswordEmailController.text = emailController.text.trim();
    final textColor = _remoteConfigService.getInputTextColor();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نسيت كلمة المرور؟', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أدخل بريدك الإلكتروني وسنرسل لك رابطًا لإعادة تعيين كلمة المرور.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: forgotPasswordEmailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'البريد الإلكتروني',
                labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
                prefixIcon: Icon(Icons.email, color: AppColors.appamber),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = forgotPasswordEmailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى إدخال البريد الإلكتروني'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.of(context).pop();

              // إرسال بريد إعادة تعيين كلمة المرور
              await _authService.resetPassword(email, context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.appamber,
            ),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // الحصول على لون النص من Remote Config
    final textColor = _remoteConfigService.getInputTextColor();

    return ScaffoldWithBackground(
      appBar: AppBar(
        title: const Text("Login", style: TextStyle(color: Colors.amber)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackBtn(),
        actions: [
          IconButton(
            icon: const Icon(Icons.healing, color: Colors.amber),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('إصلاح قاعدة البيانات'),
                  content: const Text(
                    'هذه الميزة تحاول إصلاح عدم التزامن بين Firebase Authentication وقاعدة بيانات Firestore. هل تريد المتابعة؟',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _authService.repairDatabase(context);
                      },
                      child: const Text('إصلاح'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'إصلاح قاعدة البيانات',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                Image.asset('assets/images/logo.png', height: 150),
                const SizedBox(height: 30),
                field(
                  label: "Email",
                  icon: Icons.email,
                  controller: emailController,
                  textInputType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  textColor: textColor, // إضافة لون النص
                ),
                const SizedBox(height: 20),
                field(
                  label: "Password",
                  icon: Icons.lock,
                  controller: passwordController,
                  textInputType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  isSecure: isSecure,
                  textColor: textColor, // إضافة لون النص
                  suffixIcon: IconButton(
                    icon: Icon(
                      isSecure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.amber,
                    ),
                    onPressed: () {
                      setState(() => isSecure = !isSecure);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isLoading ? null : _showForgotPasswordDialog,
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(color: Colors.amber),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isLoading ? null : login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.appamber,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          "Login",
                          style: TextStyle(fontSize: 18),
                        ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(color: Colors.white),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/signup');
                      },
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(color: Colors.amber),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // تعريف دالة field داخل الكلاس لتجنب الأخطاء
  Widget field({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required TextInputType textInputType,
    required TextInputAction textInputAction,
    Widget suffixIcon = const SizedBox(),
    bool isSecure = false,
    List<TextInputFormatter> formaters = const [],
    bool isEnabled = true,
    Color iconColor = Colors.grey,
    Color textColor = Colors.white,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        border: _inputBorder(Colors.amberAccent),
        focusedBorder: _inputBorder(Colors.amberAccent),
        errorBorder: _inputBorder(Colors.red),
        focusedErrorBorder: _inputBorder(Colors.red),
        labelText: label,
        labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20.0),
        suffixIcon: suffixIcon,
      ),
      obscureText: isSecure,
      textInputAction: textInputAction,
      keyboardType: textInputType,
      inputFormatters: formaters,
      enabled: isEnabled,
    );
  }

  OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: color, width: 0.5));
  }
}
