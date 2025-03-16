import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_cubit.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';

class AddVerce extends StatefulWidget {
  const AddVerce({super.key});

  @override
  State<AddVerce> createState() => _AddVerceState();
}

class _AddVerceState extends State<AddVerce> {
  TextEditingController titleController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor,
          leading: BackBtn(),
          actions: [
            IconButton(
                onPressed: () {
                  String verseText = titleController.text.trim();
                  if (verseText.isNotEmpty) {
                    BlocProvider.of<VerceCubit>(context)
                        .createVerce(title: verseText);
                    Navigator.pop(context);
                  }
                },
                icon: Icon(
                  Icons.check,
                  color: AppColors.appamber,
                ))
          ],
        ),
        body: ListView(
          children: [
            TextField(
              controller: titleController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                  fillColor: AppColors.appamber,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(40))),
            ),
            SizedBox(height: 5),
          ],
        ));
  }
}
