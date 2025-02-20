import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:om_elnour_choir/shared/shared_widgets/field.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_fonts.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends State<ProfileScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  bool isEditable = false;
  bool isLoading = true;
  String? profileImageUrl;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    getUserData();
  }

  /// ✅ **جلب بيانات المستخدم من Firestore**
  Future<void> getUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        print("No user is signed in.");
        setState(() => isLoading = false);
        return;
      }

      print("Current User UID: ${user.uid}");

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        print("User document does not exist!");
        setState(() => isLoading = false);
        return;
      }

      setState(() {
        emailController.text = user.email ?? '';
        userNameController.text = userDoc['name'] ?? '';
        phoneController.text = userDoc['phoneNumber'] ?? '';
        profileImageUrl = userDoc['profileImage'] ?? '';
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching user data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
      setState(() => isLoading = false);
    }
  }

  /// ✅ **اختيار صورة من المعرض**
  Future<void> pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      await uploadProfileImage();
    }
  }

  /// ✅ **رفع الصورة إلى Firebase Storage وتحديث Firestore**
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile image updated successfully")),
      );
    } catch (e) {
      print("Error uploading image: $e");
    }
  }

  /// ✅ **حفظ البيانات في Firestore**
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

        setState(() {
          isEditable = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully")),
        );
      }
    } catch (e) {
      print("Error updating user data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating profile: $e")),
      );
    }
  }

  /// ✅ **تسجيل الخروج**
  void logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        leading: BackBtn(),
        elevation: 0.0,
        backgroundColor: AppColors.backgroundColor,
        title: Text('My Profile', style: TextStyle(color: Colors.amber[200])),
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
              padding: const EdgeInsets.all(10.0),
              child: ListView(
                children: [
                  Column(
                    children: [
                      InkWell(
                        onTap: () {
                          if (isEditable) {
                            pickImage();
                          }
                        },
                        child: Container(
                          height: 150,
                          width: 150,
                          margin: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: profileImageUrl != null &&
                                      profileImageUrl!.isNotEmpty
                                  ? NetworkImage(profileImageUrl!)
                                  : const AssetImage('assets/images/logo.png')
                                      as ImageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 50.0),
                  field(
                    label: 'Email Address',
                    icon: Icons.email,
                    controller: emailController,
                    textInputType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    isEnabled: false,
                  ),
                  const SizedBox(height: 30.0),
                  field(
                    label: 'name',
                    icon: Icons.person,
                    controller: userNameController,
                    textInputType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    isEnabled: isEditable,
                  ),
                  const SizedBox(height: 30.0),
                  field(
                    label: 'phoneNumber',
                    icon: Icons.phone,
                    controller: phoneController,
                    textInputType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    isEnabled: isEditable,
                  ),
                  const SizedBox(height: 30.0),
                  Column(
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: isEditable
                              ? AppColors.jeansColor
                              : Colors.amber[200],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
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
                        child: Text(isEditable ? 'Save' : 'Edit',
                            style: AppFonts.miniBackStyle),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
