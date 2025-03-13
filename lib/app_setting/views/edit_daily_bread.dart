import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_cubit.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';

class EditDailyBread extends StatefulWidget {
  final String docId;
  final String initialContent;

  const EditDailyBread(
      {super.key, required this.docId, required this.initialContent});

  @override
  State<EditDailyBread> createState() => _EditDailyBreadState();
}

class _EditDailyBreadState extends State<EditDailyBread> {
  late TextEditingController contentController;

  @override
  void initState() {
    super.initState();
    contentController = TextEditingController(text: widget.initialContent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: const Text("تعديل الخبز اليومي",
            style: TextStyle(color: Colors.amber)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              if (contentController.text.isEmpty) return;

              BlocProvider.of<DailyBreadCubit>(context)
                  .editDailyBread(widget.docId, contentController.text);

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
