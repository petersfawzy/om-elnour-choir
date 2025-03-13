import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_cubit.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';

class AddDailyBread extends StatefulWidget {
  const AddDailyBread({super.key});

  @override
  State<AddDailyBread> createState() => _AddDailyBreadState();
}

class _AddDailyBreadState extends State<AddDailyBread> {
  TextEditingController contentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        leading: BackBtn(),
        title:
            Text("Add Daily Bread", style: TextStyle(color: Colors.amber[300])),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              if (contentController.text.isEmpty) return;

              BlocProvider.of<DailyBreadCubit>(context)
                  .createDaily(content: contentController.text);

              Navigator.pop(context);
            },
            icon: const Icon(Icons.check, color: Colors.green),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: TextField(
          controller: contentController,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: "أدخل النص...",
            fillColor: Colors.amber[300],
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
      ),
    );
  }
}
