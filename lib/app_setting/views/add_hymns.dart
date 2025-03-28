import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';

class AddHymns extends StatefulWidget {
  @override
  _AddHymnsState createState() => _AddHymnsState();
}

class _AddHymnsState extends State<AddHymns> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _youtubeUrlController = TextEditingController();
  String? _selectedCategory;
  String? _selectedAlbum;
  String? _selectedFilePath;
  List<String> _categories = [];
  List<String> _albums = [];

  @override
  void initState() {
    super.initState();
    _fetchCategoriesAndAlbums();
  }

  Future<void> _fetchCategoriesAndAlbums() async {
    var categoriesSnapshot =
        await FirebaseFirestore.instance.collection('categories').get();
    var albumsSnapshot =
        await FirebaseFirestore.instance.collection('albums').get();

    setState(() {
      _categories =
          categoriesSnapshot.docs.map((doc) => doc['name'].toString()).toList();
      _albums =
          albumsSnapshot.docs.map((doc) => doc['name'].toString()).toList();
    });
  }

  Future<void> _pickAudioFile() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
      });
    }
  }

  void _addHymn() {
    if (_nameController.text.isNotEmpty &&
        _selectedFilePath != null &&
        _selectedCategory != null &&
        _selectedAlbum != null) {
      context.read<HymnsCubit>().createHymn(
            songName: _nameController.text,
            songUrl: _selectedFilePath!,
            songCategory: _selectedCategory!,
            songAlbum: _selectedAlbum!,
            youtubeUrl: _youtubeUrlController.text.isNotEmpty
                ? _youtubeUrlController.text
                : null,
          );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("يرجى ملء جميع الحقول المطلوبة")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text("إضافة ترنيمة جديدة",
            style: TextStyle(color: AppColors.appamber)),
        leading: BackBtn(),
      ),
      body: Container(
        color: AppColors.backgroundColor,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                  labelText: "اسم الترنيمة",
                  labelStyle: TextStyle(color: AppColors.appamber)),
              style: TextStyle(color: AppColors.appamber),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _categories.map((category) {
                return DropdownMenuItem(
                    value: category,
                    child: Text(category,
                        style: TextStyle(color: AppColors.appamber)));
              }).toList(),
              onChanged: (value) => setState(() => _selectedCategory = value),
              decoration: InputDecoration(
                  labelText: "التصنيف",
                  labelStyle: TextStyle(color: AppColors.appamber)),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedAlbum,
              items: _albums.map((album) {
                return DropdownMenuItem(
                    value: album,
                    child: Text(album,
                        style: TextStyle(color: AppColors.appamber)));
              }).toList(),
              onChanged: (value) => setState(() => _selectedAlbum = value),
              decoration: InputDecoration(
                  labelText: "الألبوم",
                  labelStyle: TextStyle(color: AppColors.appamber)),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _pickAudioFile,
              icon: Icon(Icons.upload_file, color: AppColors.backgroundColor),
              label: Text(
                  _selectedFilePath == null
                      ? "اختيار ملف صوتي"
                      : "تم اختيار الملف",
                  style: TextStyle(color: AppColors.backgroundColor)),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.appamber),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _youtubeUrlController,
              decoration: InputDecoration(
                  labelText: "رابط YouTube (اختياري)",
                  labelStyle: TextStyle(color: AppColors.appamber)),
              style: TextStyle(color: AppColors.appamber),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addHymn,
              child: Text("إضافة الترنيمة",
                  style: TextStyle(color: AppColors.backgroundColor)),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.appamber),
            ),
          ],
        ),
      ),
    );
  }
}
