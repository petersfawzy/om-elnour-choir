import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_model.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_cubit.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';

class EditCopticCalendar extends StatefulWidget {
  CopticCalendarModel copticCalendarModel;
  EditCopticCalendar({required this.copticCalendarModel});

  @override
  State<EditCopticCalendar> createState() => _EditNoteState();
}

class _EditNoteState extends State<EditCopticCalendar> {
  TextEditingController titleController = TextEditingController();

  @override
  void initState() {
    titleController.text = widget.copticCalendarModel.titel;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text('Edit ${widget.copticCalendarModel.titel} Note',
            style: TextStyle(
                color: Colors.amber[200],
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          TextField(
            controller: titleController,
          ),
          SizedBox(height: 20),
          TextButton(
            child: Text(
              'Update',
              style: TextStyle(color: AppColors.backgroundColor),
            ),
            style: TextButton.styleFrom(backgroundColor: Colors.amber[100]),
            onPressed: () {
              BlocProvider.of<CopticCalendarCubit>(context).editCopticCalendar(
                  widget.copticCalendarModel, titleController.text);
              Navigator.pop(context);
            },
          )
        ],
      ),
    );
  }
}
