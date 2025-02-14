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
        ),
        body: ListView(
          children: [
            TextField(
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                  fillColor: Colors.amber[200],
                  // labelStyle: TextStyle(color: Colors.amber[200], fontSize: 25),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(40))),
            ),
            SizedBox(height: 5),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isEmpty) {
                  return;
                }
                BlocProvider.of<VerceCubit>(context)
                    .creatVerce(title: titleController.text);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  )),
              child: Text('Add Verse'),
            ),
          ],
        ));
  }
}
