import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/shared/shared_widgets/field.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_fonts.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:om_elnour_choir/user/views/login_screen.dart';
import 'package:om_elnour_choir/user/logic/auth_service.dart';
import 'package:om_elnour_choir/services/remote_config_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends State<ProfileScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  final RemoteConfigService _remoteConfigService = RemoteConfigService();
  final DefaultCacheManager _cacheManager = DefaultCacheManager();

  bool isEditable = false;
  bool isLoading = false; // بدء بدون تحميل
  bool _obscurePassword = true;
  String? profileImageUrl;
  File? _selectedImage;

  // إضافة متغير للتحكم في تحميل البيانات
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    print('🔄 تم تهيئة ProfileScreen');

    // تحميل البيانات المخزنة محليًا أولاً (سريع)
    _loadCachedUserData();

    // ثم تحميل البيانات من Firebase (قد يستغرق وقتًا)
    _loadUserDataFromFirebase();
  }

  // دالة جديدة لتحميل البيانات المخزنة محليًا
  Future<void> _loadCachedUserData() async {
    try {
      print('🔄 جاري تحميل البيانات المخزنة محليًا...');
      final prefs = await SharedPreferences.getInstance();
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        print('⚠️ لا يوجد مستخدم مسجل الدخول');
        return;
      }

      final cachedUserData = prefs.getString('user_data_$userId');
      if (cachedUserData != null) {
        final userData = json.decode(cachedUserData) as Map<String, dynamic>;

        if (mounted) {
          setState(() {
            emailController.text = userData['email'] ?? '';
            userNameController.text = userData['name'] ?? '';
            phoneController.text = userData['phoneNumber'] ?? '';
            profileImageUrl = userData['profileImage'];
            _dataLoaded = true;
          });
        }

        print('✅ تم تحميل البيانات المخزنة محليًا بنجاح');
      } else {
        print('⚠️ لا توجد بيانات مخزنة محليًا');
      }
    } catch (e) {
      print('❌ خطأ في تحميل البيانات المخزنة محليًا: $e');
    }
  }

  // دالة جديدة لتحميل البيانات من Firebase
  Future<void> _loadUserDataFromFirebase() async {
    if (_dataLoaded && !isLoading) {
      print('✅ البيانات محملة بالفعل، تخطي تحميل البيانات من Firebase');
      return;
    }

    try {
      print('🔄 جاري تحميل بيانات المستخدم من Firebase...');

      // لا نعرض مؤشر التحميل إذا كانت البيانات المخزنة محليًا متاحة
      if (!_dataLoaded) {
        setState(() => isLoading = true);
      }

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        print('⚠️ لا يوجد مستخدم مسجل الدخول');
        return;
      }

      // التحقق من وجود الصورة في التخزين المؤقت
      final cacheKey = 'profile_image_${user.uid}';

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        setState(() => isLoading = false);
        print('⚠️ لا توجد بيانات للمستخدم في Firestore');
        return;
      }

      // تحديث بيانات المستخدم
      if (mounted) {
        final userData = userDoc.data() as Map<String, dynamic>;

        setState(() {
          emailController.text = user.email ?? '';
          userNameController.text = userData['name'] ?? '';
          phoneController.text = userData['phoneNumber'] ?? '';
          profileImageUrl = userData['profileImage'] ?? '';
          isLoading = false;
          _dataLoaded = true;
        });

        // حفظ البيانات محليًا للاستخدام المستقبلي
        _saveUserDataLocally(user.email ?? '', userData);
      }

      print('✅ تم تحميل بيانات المستخدم من Firebase بنجاح');

      // تخزين الصورة في التخزين المؤقت إذا كانت متاحة
      if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
        try {
          // التحقق مما إذا كانت الصورة موجودة في التخزين المؤقت
          final fileInfo = await _cacheManager.getFileFromCache(cacheKey);

          if (fileInfo == null) {
            // إذا لم تكن موجودة، قم بتنزيلها وتخزينها
            await _cacheManager.downloadFile(
              profileImageUrl!,
              key: cacheKey,
              force: false,
            );
            print('✅ تم تخزين صورة الملف الشخصي في التخزين المؤقت');
          } else {
            print('✅ تم استخدام صورة الملف الشخصي من التخزين المؤقت');
          }
        } catch (e) {
          print('⚠️ خطأ في تخزين الصورة في التخزين المؤقت: $e');
        }
      }
    } catch (e) {
      print('❌ خطأ في تحميل بيانات المستخدم من Firebase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("خطأ في تحميل البيانات: $e")));
        setState(() => isLoading = false);
      }
    }
  }

  // دالة جديدة لحفظ بيانات المستخدم محليًا
  Future<void> _saveUserDataLocally(
      String email, Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) return;

      final dataToSave = {
        'email': email,
        'name': userData['name'] ?? '',
        'phoneNumber': userData['phoneNumber'] ?? '',
        'profileImage': userData['profileImage'] ?? '',
      };

      await prefs.setString('user_data_$userId', json.encode(dataToSave));
      print('✅ تم حفظ بيانات المستخدم محليًا');
    } catch (e) {
      print('❌ خطأ في حفظ بيانات المستخدم محليًا: $e');
    }
  }

  // دالة لإعادة تحميل البيانات عند الحاجة
  void reloadUserData() {
    setState(() {
      _dataLoaded = false;
      isLoading = true;
    });
    _loadUserDataFromFirebase();
  }

  Future<void> pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          isLoading = true;
        });

        await uploadProfileImage();
      } else {
        print("لم يتم اختيار صورة");
      }
    } catch (e) {
      print("خطأ في اختيار الصورة: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ في اختيار الصورة: $e")),
      );
    }
  }

  Future<void> uploadProfileImage() async {
    try {
      if (_selectedImage == null) return;

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String filePath = 'profile_images/${user.uid}.jpg';
      UploadTask uploadTask =
          FirebaseStorage.instance.ref(filePath).putFile(_selectedImage!);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('userData')
          .doc(user.uid)
          .update({'profileImage': downloadUrl});

      setState(() {
        profileImageUrl = downloadUrl;
      });

      // تحديث التخزين المؤقت
      final cacheKey = 'profile_image_${user.uid}';

      // حذف الصورة القديمة من التخزين المؤقت
      await _cacheManager.removeFile(cacheKey);

      // تخزين الصورة الجديدة
      await _cacheManager.downloadFile(
        downloadUrl,
        key: cacheKey,
        force: true,
      );

      // تحديث البيانات المخزنة محليًا
      final prefs = await SharedPreferences.getInstance();
      final cachedUserData = prefs.getString('user_data_${user.uid}');
      if (cachedUserData != null) {
        final userData = json.decode(cachedUserData) as Map<String, dynamic>;
        userData['profileImage'] = downloadUrl;
        await prefs.setString('user_data_${user.uid}', json.encode(userData));
      }

      // إعادة تحميل البيانات
      reloadUserData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم تحديث صورة الملف الشخصي بنجاح")),
      );
    } catch (e) {
      print("خطأ في رفع الصورة: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ في رفع الصورة: $e")),
      );
    }
  }

  Future<void> saveUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('userData')
            .doc(user.uid)
            .update({
          'name': userNameController.text,
          'phoneNumber': phoneController.text,
        });

        // تحديث البيانات المخزنة محليًا
        final prefs = await SharedPreferences.getInstance();
        final cachedUserData = prefs.getString('user_data_${user.uid}');
        if (cachedUserData != null) {
          final userData = json.decode(cachedUserData) as Map<String, dynamic>;
          userData['name'] = userNameController.text;
          userData['phoneNumber'] = phoneController.text;
          await prefs.setString('user_data_${user.uid}', json.encode(userData));
        }

        setState(() {
          isEditable = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم تحديث الملف الشخصي بنجاح")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ في تحديث الملف الشخصي: $e")),
      );
    }
  }

  // تعديل دالة تسجيل الخروج لمسح البيانات المخزنة محليًا
  void logout() async {
    try {
      // مسح بيانات المستخدم
      await context.read<HymnsCubit>().clearUserData();

      // مسح البيانات المخزنة محليًا
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_data_$userId');
      }

      // تسجيل الخروج
      await FirebaseAuth.instance.signOut();

      // الانتقال إلى شاشة تسجيل الدخول
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => Login()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ في تسجيل الخروج: $e")),
        );
      }
    }
  }

  // عرض مربع حوار حذف الحساب
  void _showDeleteAccountDialog() {
    // الحصول على لون النص من Remote Config
    final textColor = _remoteConfigService.getInputTextColor();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundColor,
        title: const Text(
          'حذف الحساب',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.amber),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'هل أنت متأكد من رغبتك في حذف حسابك؟ هذا الإجراء لا يمكن التراجع عنه.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'كلمة المرور للتأكيد',
                labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.amberAccent, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.amberAccent, width: 0.5),
                ),
                prefixIcon: Icon(Icons.lock, color: Colors.amber),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                filled: true,
                fillColor: Colors.black.withOpacity(0.2),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              passwordController.clear();
            },
            child: const Text('إلغاء', style: TextStyle(color: Colors.amber)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى إدخال كلمة المرور للتأكيد'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.of(context).pop();

              // حذف الحساب
              final success = await _authService.deleteAccount(
                passwordController.text,
                context,
              );

              passwordController.clear();

              if (success && mounted) {
                // مسح بيانات المستخدم
                await context.read<HymnsCubit>().clearUserData();

                // مسح البيانات المخزنة محليًا
                final userId = FirebaseAuth.instance.currentUser?.uid;
                if (userId != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('user_data_$userId');
                }

                // الانتقال إلى شاشة تسجيل الدخول
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => Login()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('حذف الحساب'),
          ),
        ],
      ),
    );
  }

  // عرض مربع حوار تغيير كلمة المرور
  void _showChangePasswordDialog() {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    // الحصول على لون النص من Remote Config
    final textColor = _remoteConfigService.getInputTextColor();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.backgroundColor,
          title: const Text(
            'تغيير كلمة المرور',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.amber),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // حقل كلمة المرور الحالية
                _buildPasswordField(
                  controller: currentPasswordController,
                  obscure: obscureCurrentPassword,
                  label: 'كلمة المرور الحالية',
                  textColor: textColor,
                  toggleObscure: () {
                    setState(() {
                      obscureCurrentPassword = !obscureCurrentPassword;
                    });
                  },
                ),
                const SizedBox(height: 15),

                // حقل كلمة المرور الجديدة
                _buildPasswordField(
                  controller: newPasswordController,
                  obscure: obscureNewPassword,
                  label: 'كلمة المرور الجديدة',
                  textColor: textColor,
                  toggleObscure: () {
                    setState(() {
                      obscureNewPassword = !obscureNewPassword;
                    });
                  },
                ),
                const SizedBox(height: 15),

                // حقل تأكيد كلمة المرور الجديدة
                _buildPasswordField(
                  controller: confirmPasswordController,
                  obscure: obscureConfirmPassword,
                  label: 'تأكيد كلمة المرور الجديدة',
                  textColor: textColor,
                  toggleObscure: () {
                    setState(() {
                      obscureConfirmPassword = !obscureConfirmPassword;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('إلغاء', style: TextStyle(color: Colors.amber)),
            ),
            ElevatedButton(
              onPressed: () async {
                // التحقق من صحة المدخلات
                if (currentPasswordController.text.isEmpty ||
                    newPasswordController.text.isEmpty ||
                    confirmPasswordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يرجى ملء جميع الحقول'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('كلمات المرور الجديدة غير متطابقة'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يجب أن تكون كلمة المرور 6 أحرف على الأقل'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop();

                // تغيير كلمة المرور
                await _changePassword(
                  currentPasswordController.text,
                  newPasswordController.text,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.appamber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('تغيير كلمة المرور'),
            ),
          ],
        ),
      ),
    );
  }

  // دالة مساعدة لإنشاء حقل كلمة المرور بنفس أسلوب التطبيق
  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool obscure,
    required String label,
    required Color textColor,
    required VoidCallback toggleObscure,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.amberAccent, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.amberAccent, width: 0.5),
        ),
        prefixIcon: Icon(Icons.lock, color: Colors.amber),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility : Icons.visibility_off,
            color: Colors.amber,
          ),
          onPressed: toggleObscure,
        ),
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
      ),
    );
  }

  // دالة تغيير كلمة المرور
  Future<void> _changePassword(
      String currentPassword, String newPassword) async {
    try {
      setState(() {
        isLoading = true;
      });

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception('لا يوجد مستخدم مسجل الدخول');
      }

      // إعادة المصادقة
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // تغيير كلمة المرور
      await user.updatePassword(newPassword);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تغيير كلمة المرور بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'حدث خطأ أثناء تغيير كلمة المرور';

      if (e.code == 'wrong-password') {
        errorMessage = 'كلمة المرور الحالية غير صحيحة';
      } else if (e.code == 'requires-recent-login') {
        errorMessage =
            'يرجى تسجيل الخروج وإعادة تسجيل الدخول ثم المحاولة مرة أخرى';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ غير متوقع: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        leading: const BackBtn(),
        elevation: 0.0,
        backgroundColor: AppColors.backgroundColor,
        title: Text(
          'My Profile',
          style: TextStyle(
            color: AppColors.appamber,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.amber),
            onPressed: logout,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.08,
                vertical: 20,
              ),
              child: ListView(
                children: [
                  Center(
                    child: InkWell(
                      onTap: () {
                        // السماح بتغيير الصورة دائمًا، بغض النظر عن حالة isEditable
                        pickImage();
                      },
                      child: Stack(
                        children: [
                          Container(
                            height: 130,
                            width: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.appamber,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: profileImageUrl != null &&
                                      profileImageUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: profileImageUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          CircularProgressIndicator(),
                                      errorWidget: (context, url, error) =>
                                          Image.asset(
                                        'assets/images/logo.png',
                                        fit: BoxFit.cover,
                                      ),
                                      cacheKey:
                                          'profile_image_${FirebaseAuth.instance.currentUser?.uid}',
                                    )
                                  : Image.asset(
                                      'assets/images/logo.png',
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          // إضافة أيقونة الكاميرا للإشارة إلى إمكانية تغيير الصورة
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.appamber,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40.0),
                  _buildProfileField(
                    "Email Address",
                    emailController,
                    Icons.email,
                    false,
                  ),
                  _buildProfileField(
                    "Name",
                    userNameController,
                    Icons.person,
                    isEditable,
                  ),
                  _buildProfileField(
                    "Phone Number",
                    phoneController,
                    Icons.phone,
                    isEditable,
                  ),
                  const SizedBox(height: 30.0),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isEditable
                            ? AppColors.jeansColor
                            : AppColors.appamber,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        fixedSize: const Size(200, 50),
                      ),
                      onPressed: () {
                        if (isEditable) {
                          saveUserData();
                        } else {
                          setState(() {
                            isEditable = true;
                          });
                        }
                      },
                      child: Text(
                        isEditable ? 'Save' : 'Edit',
                        style: AppFonts.miniBackStyle.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // زر تغيير كلمة المرور
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('تغيير كلمة المرور'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.appamber,
                        foregroundColor: AppColors.backgroundColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        fixedSize: const Size(200, 50),
                      ),
                      onPressed: _showChangePasswordDialog,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // زر حذف الحساب
                  Center(
                    child: TextButton.icon(
                      onPressed: _showDeleteAccountDialog,
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.red,
                      ),
                      label: const Text(
                        'حذف الحساب',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileField(
    String label,
    TextEditingController controller,
    IconData icon,
    bool isEnabled,
  ) {
    // استخدام لون النص من Remote Config
    final textColor = _remoteConfigService.getInputTextColor();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: controller,
        enabled: isEnabled,
        style: TextStyle(
            fontSize: 16, color: textColor), // استخدام اللون من Remote Config
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 14,
            color: textColor.withOpacity(0.8), // استخدام نفس اللون مع شفافية
          ),
          prefixIcon: Icon(icon, color: AppColors.appamber),
          filled: true,
          fillColor: Colors.black.withOpacity(0.2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
