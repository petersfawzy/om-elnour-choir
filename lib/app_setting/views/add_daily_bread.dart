import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_cubit.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:intl/intl.dart';

class AddDailyBread extends StatefulWidget {
  const AddDailyBread({super.key});

  @override
  State<AddDailyBread> createState() => _AddDailyBreadState();
}

class _AddDailyBreadState extends State<AddDailyBread> {
  TextEditingController contentController = TextEditingController();
  DateTime selectedDate = DateTime.now()
      .add(Duration(days: 1)); // ✅ التاريخ الافتراضي هو اليوم التالي

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        leading: BackBtn(),
        title: Text("Add Daily Bread",
            style: TextStyle(color: AppColors.appamber)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              if (contentController.text.isEmpty) return;

              /// ✅ ضبط التوقيت ليكون من بداية اليوم إلى نهايته حسب التوقيت المحلي
              DateTime startOfDay = DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                0,
                0,
                0,
              );

              DateTime endOfDay = DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                23,
                59,
                59,
              );

              BlocProvider.of<DailyBreadCubit>(context).createDaily(
                content: contentController.text,
                date: startOfDay, // ✅ نخزن اليوم من بدايته
              );

              Navigator.pop(context);
            },
            icon: const Icon(Icons.check, color: Colors.green),
          ),
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 20),

            /// ✅ زر اختيار التاريخ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('yyyy-MM-dd').format(selectedDate),
                  style: TextStyle(fontSize: 18, color: AppColors.appamber),
                ),
                IconButton(
                  icon: Icon(Icons.calendar_today, color: AppColors.appamber),
                  onPressed: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );

                    if (pickedDate != null) {
                      setState(() {
                        selectedDate = pickedDate;
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
