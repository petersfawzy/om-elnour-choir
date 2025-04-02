import 'package:flutter/material.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_model.dart';
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
  void dispose() {
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        leading: BackBtn(),
        title: Text('Edit Coptic Calendar',
            style: TextStyle(color: AppColors.appamber)),
        centerTitle: true,
        actions: [
          // زر الحذف
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.backgroundColor,
                  title: Text('تأكيد الحذف',
                      style: TextStyle(color: AppColors.appamber)),
                  content: Text('هل أنت متأكد من حذف هذا الحدث؟',
                      style: TextStyle(color: AppColors.appamber)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('إلغاء',
                          style: TextStyle(color: AppColors.appamber)),
                    ),
                    TextButton(
                      onPressed: () {
                        BlocProvider.of<CopticCalendarCubit>(context)
                            .deleteCopticCalendar(
                                widget.copticCalendarModel.id);
                        Navigator.pop(context); // إغلاق الحوار
                        Navigator.pop(context); // العودة للشاشة السابقة
                      },
                      child: Text('حذف', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            icon: Icon(Icons.delete, color: Colors.red),
          ),
          // زر الحفظ
          IconButton(
            onPressed: () {
              if (contentController.text.isEmpty) return;

              BlocProvider.of<CopticCalendarCubit>(context).editCopticCalendar(
                widget.copticCalendarModel.id,
                contentController.text,
              );

              Navigator.pop(context);
            },
            icon: Icon(Icons.check, color: AppColors.appamber),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            // عرض التاريخ (غير قابل للتعديل)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.appamber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.appamber),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: AppColors.appamber),
                  SizedBox(width: 8),
                  Text(
                    "التاريخ: ${widget.copticCalendarModel.date}",
                    style: TextStyle(
                      color: AppColors.appamber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 15),
            // حقل تعديل المحتوى
            TextField(
              controller: contentController,
              textAlign: TextAlign.right,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "أدخل النص...",
                fillColor: AppColors.appamber,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                hintStyle: TextStyle(
                    color: AppColors.backgroundColor.withOpacity(0.7)),
              ),
              style: TextStyle(color: AppColors.backgroundColor),
            ),
          ],
        ),
      ),
    );
  }
}
