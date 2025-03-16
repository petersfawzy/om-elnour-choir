import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';

class EditNews extends StatefulWidget {
  final String docId;
  final String initialContent;
  final String? imageUrl;

  EditNews(
      {super.key,
      required this.docId,
      required this.initialContent,
      this.imageUrl});

  @override
  State<EditNews> createState() => _EditNewsState();
}

class _EditNewsState extends State<EditNews> {
  TextEditingController contentController = TextEditingController();
  File? _newImage;
  bool isLoading = false;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    contentController.text = widget.initialContent;
    _currentImageUrl = widget.imageUrl;
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateNews() async {
    if (contentController.text.isEmpty &&
        _newImage == null &&
        _currentImageUrl == null) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    String? newImageUrl = _currentImageUrl;
    if (_newImage != null) {
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('news_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(_newImage!);
      newImageUrl = await ref.getDownloadURL();
    }

    await FirebaseFirestore.instance
        .collection('news')
        .doc(widget.docId)
        .update({
      'content': contentController.text.trim(),
      'imageUrl': newImageUrl ?? "",
    });

    setState(() {
      isLoading = false;
    });

    Navigator.pop(context);
  }

  Future<void> _deleteImage() async {
    setState(() {
      _currentImageUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text('Edit News',
            style: TextStyle(
                color: AppColors.appamber,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: isLoading ? null : _updateNews,
            icon: isLoading
                ? CircularProgressIndicator()
                : Icon(Icons.check, color: AppColors.appamber),
          )
        ],
        leading: BackBtn(),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          TextField(
            controller: contentController,
            decoration: InputDecoration(
              hintText: "تعديل الخبر...",
              fillColor: AppColors.appamber,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          SizedBox(height: 10),
          if (_currentImageUrl != null)
            Column(
              children: [
                Image.network(_currentImageUrl!,
                    height: 200, fit: BoxFit.cover),
                TextButton.icon(
                  onPressed: _deleteImage,
                  icon: Icon(Icons.delete, color: Colors.red),
                  label:
                      Text("حذف الصورة", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          if (_newImage != null)
            Image.file(_newImage!, height: 200, fit: BoxFit.cover),
          TextButton.icon(
            onPressed: _pickImage,
            icon: Icon(Icons.image, color: AppColors.appamber),
            label: Text("استبدال الصورة",
                style: TextStyle(color: AppColors.appamber)),
          ),
        ],
      ),
    );
  }
}
