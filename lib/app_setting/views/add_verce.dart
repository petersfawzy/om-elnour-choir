import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_states.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';

class AddVerce extends StatefulWidget {
  const AddVerce({super.key});

  @override
  State<AddVerce> createState() => _AddVerceState();
}

class _AddVerceState extends State<AddVerce> {
  TextEditingController contentController = TextEditingController();
  // تغيير تهيئة selectedDate لتكون اليوم التالي (غداً) بدلاً من اليوم الحالي
  DateTime selectedDate = DateTime.now().add(Duration(days: 1));
  bool isLoading = false;

  // تنسيق التاريخ بالصيغة المطلوبة (يوم/شهر/سنة)
  String get formattedDate =>
      "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}";

  // عرض منتقي التاريخ
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.appamber,
              onPrimary: Colors.white,
              onSurface: AppColors.appamber,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.appamber,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text("إضافة آية جديدة",
            style: TextStyle(color: AppColors.appamber)),
        leading: BackBtn(),
        actions: [
          BlocConsumer<VerceCubit, VerceState>(
            listener: (context, state) {
              if (state is VerceLoaded) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("تم حفظ الآية بنجاح")),
                );
                Navigator.pop(context);
              } else if (state is VerceError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red),
                );
                setState(() {
                  isLoading = false;
                });
              }
            },
            builder: (context, state) {
              return isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.appamber),
                      ),
                    )
                  : IconButton(
                      onPressed: () {
                        String verseText = contentController.text.trim();
                        if (verseText.isNotEmpty) {
                          setState(() {
                            isLoading = true;
                          });
                          BlocProvider.of<VerceCubit>(context).createVerce(
                              content: verseText, date: formattedDate);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("الرجاء إدخال محتوى الآية")),
                          );
                        }
                      },
                      icon: Icon(
                        Icons.check,
                        color: AppColors.appamber,
                      ),
                    );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // عرض التاريخ المحدد
            Card(
              elevation: 3,
              color: AppColors.backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: AppColors.appamber, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      "تاريخ عرض الآية",
                      style: TextStyle(
                        color: AppColors.appamber,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formattedDate,
                          style: TextStyle(
                            color: AppColors.appamber,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () => _selectDate(context),
                          icon: Icon(Icons.calendar_today,
                              color: AppColors.backgroundColor),
                          label: Text("تغيير التاريخ",
                              style:
                                  TextStyle(color: AppColors.backgroundColor)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.appamber,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            // حقل إدخال محتوى الآية
            Expanded(
              child: Card(
                elevation: 3,
                color: AppColors.backgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: AppColors.appamber, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: contentController,
                    textAlign: TextAlign.right,
                    // تجنب استخدام TextDirection تمامًا
                    maxLines: null,
                    expands: true,
                    style: TextStyle(
                      color: AppColors.appamber,
                      fontSize: 18,
                    ),
                    decoration: InputDecoration(
                      hintText: "أدخل محتوى الآية هنا...",
                      hintStyle:
                          TextStyle(color: AppColors.appamber.withOpacity(0.5)),
                      // تجنب استخدام TextDirection تمامًا
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                      // استخدام خصائص أخرى لتحقيق نفس النتيجة
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
