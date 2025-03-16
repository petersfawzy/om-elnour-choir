import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';

class AddNews extends StatefulWidget {
  const AddNews({super.key});

  @override
  State<AddNews> createState() => _AddNewsState();
}

class _AddNewsState extends State<AddNews> {
  TextEditingController contentController = TextEditingController();
  File? _image;
  bool isLoading = false;

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadNews() async {
    if (contentController.text.isEmpty && _image == null) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    String? imageUrl;
    if (_image != null) {
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('news_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(_image!);
      imageUrl = await ref.getDownloadURL();
    }

    await FirebaseFirestore.instance.collection('news').add({
      'content': contentController.text.trim(),
      'imageUrl': imageUrl ?? "",
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      isLoading = false;
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        leading: BackBtn(),
        title: Text('Add News', style: TextStyle(color: AppColors.appamber)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: isLoading ? null : _uploadNews,
            icon: isLoading
                ? CircularProgressIndicator()
                : Icon(Icons.check, color: AppColors.appamber),
          )
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          TextField(
            controller: contentController,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: "اكتب الخبر هنا...",
              fillColor: AppColors.appamber,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          SizedBox(height: 10),
          if (_image != null)
            Image.file(_image!, height: 200, fit: BoxFit.cover),
          TextButton.icon(
            onPressed: _pickImage,
            icon: Icon(Icons.image, color: AppColors.appamber),
            label:
                Text("إضافة صورة", style: TextStyle(color: AppColors.appamber)),
          ),
        ],
      ),
    );
  }
}
