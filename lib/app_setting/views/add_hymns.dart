import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';

class AddHymns extends StatefulWidget {
  const AddHymns({super.key});

  @override
  State<AddHymns> createState() => _AddHymnsState();
}

class _AddHymnsState extends State<AddHymns> {
  TextEditingController titleController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        leading: BackBtn(),
        title: Text('Add Hymns', style: TextStyle(color: Colors.amber[200])),
        centerTitle: true,
        actions: [
          IconButton(
              onPressed: () {
                if (titleController.text.isEmpty) {
                  return;
                }
                BlocProvider.of<HymnsCubit>(context)
                    .creatHymn(title: titleController.text);
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
          TextField(controller: titleController),
          SizedBox(height: 20),
          // TextButton(
          //   style: TextButton.styleFrom(backgroundColor: Colors.amber[200]),
          //   onPressed: () {
          //     if (titleController.text.isEmpty) {
          //       return;
          //     }
          //     BlocProvider.of<HymnsCubit>(context)
          //         .creatHymn(title: titleController.text);
          //     Navigator.pop(context);
          //   },
          //   child: Text(
          //     'Add',
          //     style: TextStyle(color: AppColors.backgroundColor),
          //   ),
          // )
        ],
      ),
    );
  }
}
