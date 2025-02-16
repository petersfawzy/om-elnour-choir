import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';

class EditHymns extends StatefulWidget {
  HymnsModel hymnsModel;
  EditHymns({required this.hymnsModel});

  @override
  State<EditHymns> createState() => _EditHymnsState();
}

class _EditHymnsState extends State<EditHymns> {
  TextEditingController titleController = TextEditingController();

  @override
  void initState() {
    titleController.text = widget.hymnsModel.songName;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text('Edit',
            style: TextStyle(
                color: Colors.amber[200],
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              onPressed: () {
                BlocProvider.of<HymnsCubit>(context)
                    .editHymn(widget.hymnsModel, titleController.text);
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
