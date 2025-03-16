import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_model.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_cubit.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';

class EditCopticCalendar extends StatefulWidget {
  final CopticCalendarModel copticCalendarModel;

  const EditCopticCalendar({super.key, required this.copticCalendarModel});

  @override
  State<EditCopticCalendar> createState() => _EditCopticCalendarState();
}

class _EditCopticCalendarState extends State<EditCopticCalendar> {
  late TextEditingController contentController;

  @override
  void initState() {
    super.initState();
    contentController =
        TextEditingController(text: widget.copticCalendarModel.content);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text("تعديل التقويم القبطي",
            style: TextStyle(color: AppColors.appamber)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              if (contentController.text.isEmpty) return;

              BlocProvider.of<CopticCalendarCubit>(context).editCopticCalendar(
                widget
                    .copticCalendarModel.id, // استخدمت الـ ID بدل تحويل الكائن
                contentController.text,
              );

              Navigator.pop(context);
            },
            icon: const Icon(Icons.check, color: Colors.green),
          )
        ],
        leading: BackBtn(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: TextField(
          controller: contentController,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: "عدل النص...",
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
      ),
    );
  }
}
