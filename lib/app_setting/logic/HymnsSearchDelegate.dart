import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';

class HymnsSearchDelegate extends StatelessWidget {
  final HymnsCubit hymnsCubit;

  HymnsSearchDelegate(this.hymnsCubit);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: "بحث عن ترنيمة...",
              hintStyle: TextStyle(color: Colors.grey.withOpacity(0.7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.appamber),
              ),
              prefixIcon: Icon(Icons.search, color: AppColors.appamber),
            ),
            style: TextStyle(color: Colors.black),
            onChanged: (query) {
              hymnsCubit.searchHymns(query); // تحديث نتائج البحث
            },
          ),
        ),
        Expanded(
          child: BlocBuilder<HymnsCubit, List<HymnsModel>>(
            builder: (context, hymns) {
              if (hymns.isEmpty) {
                return Center(
                  child: Text(
                    "لا توجد ترانيم",
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                );
              }

              return ListView.builder(
                itemCount: hymns.length,
                itemBuilder: (context, index) {
                  final hymn = hymns[index];
                  return ListTile(
                    title: Text(hymn.songName),
                    onTap: () {
                      hymnsCubit.playHymn(hymn);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
