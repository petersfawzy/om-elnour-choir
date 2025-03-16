import 'package:flutter/material.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:intl/intl.dart';

class AddCopticCalendar extends StatefulWidget {
  const AddCopticCalendar({super.key});

  @override
  State<AddCopticCalendar> createState() => _AddCopticCalendarState();
}

class _AddCopticCalendarState extends State<AddCopticCalendar> {
  TextEditingController contentController = TextEditingController();
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor,
          leading: BackBtn(),
          title: Text('Add Coptic Calendar',
              style: TextStyle(color: AppColors.appamber)),
          centerTitle: true,
          actions: [
            IconButton(
                onPressed: () {
                  if (contentController.text.isEmpty) return;

                  BlocProvider.of<CopticCalendarCubit>(context).createCal(
                    content: contentController.text,
                    date: selectedDate,
                  );

                  Navigator.pop(context);
                },
                icon: Icon(Icons.check, color: AppColors.appamber))
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [
              TextField(
                controller: contentController,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: "أدخل النص...",
                  fillColor: AppColors.appamber,
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ],
          ),
        ));
  }
}
