import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/news_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/news_model.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';

class EditNews extends StatefulWidget {
  NewsModel newsModel;
  EditNews({required this.newsModel});

  @override
  State<EditNews> createState() => _EditNewsState();
}

class _EditNewsState extends State<EditNews> {
  TextEditingController titleController = TextEditingController();

  @override
  void initState() {
    titleController.text = widget.newsModel.NewsTitle;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text('Edit News',
            style: TextStyle(
                color: Colors.amber[200],
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              onPressed: () {
                BlocProvider.of<NewsCubit>(context)
                    .editNews(widget.newsModel, titleController.text);
                Navigator.pop(context);
              },
              icon: Icon(
                Icons.check,
                color: Colors.amber[200],
              ))
        ],
      ),
      body: ListView(
        children: [
          TextField(
            controller: titleController,
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
