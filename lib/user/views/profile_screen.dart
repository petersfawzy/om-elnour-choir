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

  Future<void> getUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
      setState(() => isLoading = false);
    }
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating profile: $e")),
      );
    }
  }

  void logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
        title: Text('My Profile',
            style: TextStyle(
                color: AppColors.appamber,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
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
                  horizontal: screenWidth * 0.08, vertical: 20),
              child: ListView(
                children: [
                  Center(
                    child: InkWell(
                      onTap: () {
                        if (isEditable) {
                          pickImage();
                        }
                      },
                      child: Container(
                        height: 130,
                        width: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.appamber, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
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
                  ),
                  const SizedBox(height: 40.0),
                  _buildProfileField(
                      "Email Address", emailController, Icons.email, false),
                  _buildProfileField(
                      "Name", userNameController, Icons.person, isEditable),
                  _buildProfileField(
                      "Phone Number", phoneController, Icons.phone, isEditable),
                  const SizedBox(height: 30.0),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isEditable
                            ? AppColors.jeansColor
                            : AppColors.appamber,
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
                      child: Text(
                        isEditable ? 'Save' : 'Edit',
                        style: AppFonts.miniBackStyle.copyWith(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileField(String label, TextEditingController controller,
      IconData icon, bool isEnabled) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: controller,
        enabled: isEnabled,
        style: const TextStyle(fontSize: 16, color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
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
