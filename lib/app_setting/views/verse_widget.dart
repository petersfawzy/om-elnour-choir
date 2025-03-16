import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_states.dart';

class VerseWidget extends StatelessWidget {
  const VerseWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VerceCubit, VerceState>(
      builder: (context, state) {
        if (state is VerceLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is VerceLoaded) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.appamber,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              state.verse,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          );
        } else {
          return const Center(child: Text("❌ لا توجد آية متاحة"));
        }
      },
    );
  }
}
