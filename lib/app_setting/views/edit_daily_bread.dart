import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_model.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';

class EditDailyBread extends StatefulWidget {
  DailyBreadModel dailyBreadModel;
  EditDailyBread({required this.dailyBreadModel});

  @override
  State<EditDailyBread> createState() => _EditDailyBreadtate();
}

class _EditDailyBreadtate extends State<EditDailyBread> {
  TextEditingController titleController = TextEditingController();

  @override
  void initState() {
    titleController.text = widget.dailyBreadModel.titel;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text('Edit Daily Bread',
            style: TextStyle(
                color: Colors.amber[200],
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              onPressed: () {
                BlocProvider.of<DailyBreadCubit>(context).editDailyBread(
                    widget.dailyBreadModel, titleController.text);
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
