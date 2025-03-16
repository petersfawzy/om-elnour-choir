import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';

class AddHymns extends StatefulWidget {
  const AddHymns({super.key});

  @override
  State<AddHymns> createState() => _AddHymnsState();
}

class _AddHymnsState extends State<AddHymns> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        leading: BackBtn(),
        title: Text('Add Hymn', style: TextStyle(color: AppColors.appamber)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                BlocProvider.of<HymnsCubit>(context).createHymn(
                  title: _titleController.text.trim(),
                  url: _urlController.text.trim(),
                  category: "Default", // لازم تحدد الفئة
                  album: "Default", // لازم تحدد الألبوم
                  youtubeUrl: null, // ممكن تخليه اختياري
                );
                Navigator.pop(context);
              }
            },
            icon: Icon(Icons.check, color: AppColors.appamber),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "اسم الترنيمة",
                  labelStyle: TextStyle(color: AppColors.appamber),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.appamber),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "⚠️ أدخل اسم الترنيمة";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _urlController,
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "رابط الصوت",
                  labelStyle: TextStyle(color: AppColors.appamber),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.appamber),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "⚠️ أدخل رابط الصوت";
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
