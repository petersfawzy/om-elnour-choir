import 'package:flutter/material.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';

class AddCopticCalendar extends StatefulWidget {
  const AddCopticCalendar({super.key});

  @override
  State<AddCopticCalendar> createState() => _AddCopticCalendarState();
}

class _AddCopticCalendarState extends State<AddCopticCalendar> {
  TextEditingController titleController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor,
          leading: BackBtn(),
          title: Text('Add Coptic Calendar',
              style: TextStyle(color: Colors.amber[200])),
          centerTitle: true,
          actions: [
            IconButton(
                onPressed: () {
                  if (titleController.text.isEmpty) {
                    return;
                  }
                  BlocProvider.of<CopticCalendarCubit>(context)
                      .creatCal(title: titleController.text);
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
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                  fillColor: Colors.amber[200],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(40))),
            ),
            SizedBox(height: 5),
          ],
        ));
  }
}
