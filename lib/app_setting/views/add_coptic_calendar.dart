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
  // تعيين التاريخ الافتراضي ليكون غداً (اليوم التالي)
  late DateTime selectedDate;
  final TextEditingController dateController = TextEditingController();
  bool _isSubmitting = false; // إضافة متغير لتتبع حالة الإرسال

  @override
  void initState() {
    super.initState();
    // تعيين التاريخ الافتراضي ليكون غداً
    selectedDate = DateTime.now().add(Duration(days: 1));
    // تعيين التاريخ في حقل التاريخ
    dateController.text = DateFormat('d/M/yyyy').format(selectedDate);
  }

  @override
  void dispose() {
    contentController.dispose();
    dateController.dispose();
    super.dispose();
  }

  // دالة لعرض منتقي التاريخ
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.appamber, // لون الأزرار والتحديد
              onPrimary: AppColors.backgroundColor, // لون النص عند التحديد
              onSurface: AppColors.appamber, // لون النص العادي
              surface: AppColors.backgroundColor, // لون خلفية الشاشة
              surfaceTint:
                  AppColors.backgroundColor, // يمنع ظهور أي تأثيرات شفافة
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.appamber, // لون أزرار التحديد
              ),
            ),
            dialogTheme: DialogTheme(
              backgroundColor: AppColors.backgroundColor, // لون خلفية النافذة
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        dateController.text = DateFormat('d/M/yyyy').format(selectedDate);
      });
    }
  }

  // دالة جديدة لإضافة المحتوى مع معالجة الحالة
  Future<void> _addContent() async {
    if (contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الرجاء إدخال المحتوى')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true; // تعيين حالة الإرسال إلى true
    });

    try {
      await BlocProvider.of<CopticCalendarCubit>(context).createCal(
        content: contentController.text,
        date: selectedDate,
      );

      // انتظار لحظة للتأكد من اكتمال العملية
      await Future.delayed(Duration(milliseconds: 500));

      // إعادة تحميل البيانات قبل العودة
      await BlocProvider.of<CopticCalendarCubit>(context).fetchCopticCalendar();

      // العودة مع إرجاع true للإشارة إلى نجاح العملية
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _isSubmitting = false; // إعادة تعيين حالة الإرسال
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الإضافة: $e')),
      );
    }
  }

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
            _isSubmitting
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.appamber),
                    ),
                  )
                : IconButton(
                    onPressed: _addContent, // استخدام الدالة الجديدة
                    icon: Icon(Icons.check, color: AppColors.appamber))
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [
              // حقل اختيار التاريخ
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: TextField(
                    controller: dateController,
                    decoration: InputDecoration(
                      hintText: "اختر التاريخ...",
                      fillColor: AppColors.appamber,
                      filled: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15)),
                      prefixIcon: Icon(Icons.calendar_today,
                          color: AppColors.backgroundColor),
                    ),
                    style: TextStyle(color: AppColors.backgroundColor),
                  ),
                ),
              ),
              SizedBox(height: 15),
              // حقل إدخال المحتوى
              TextField(
                controller: contentController,
                textAlign: TextAlign.right,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: "أدخل النص...",
                  fillColor: AppColors.appamber,
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                  hintStyle: TextStyle(
                      color: AppColors.backgroundColor.withOpacity(0.7)),
                ),
                style: TextStyle(color: AppColors.backgroundColor),
              ),
            ],
          ),
        ));
  }
}
