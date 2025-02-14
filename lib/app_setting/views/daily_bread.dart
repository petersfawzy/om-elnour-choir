import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_states.dart';
import 'package:om_elnour_choir/app_setting/views/add_daily_bread.dart';
import 'package:om_elnour_choir/app_setting/views/edit_daily_bread.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';

class DailyBread extends StatefulWidget {
  const DailyBread({super.key});

  @override
  State<DailyBread> createState() => _DailyBreadState();
}

class _DailyBreadState extends State<DailyBread> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Daily Bread',
          style: TextStyle(color: Colors.amber),
        ),
        centerTitle: true,
        backgroundColor: AppColors.backgroundColor,
        leading: BackBtn(),
        actions: [
          IconButton(
              onPressed: () {
                Navigator.push(context,
                    CupertinoPageRoute(builder: (_) => AddDailyBread()));
              },
              icon: Icon(
                Icons.add,
                color: Colors.amber[200],
              ))
        ],
      ),
      body: BlocBuilder<DailyBreadCubit, DailyBreadStates>(
        builder: (context, state) => ListView(
          children: [
            for (int i =
                    BlocProvider.of<DailyBreadCubit>(context).dailyList.length -
                        1;
                i >= 0;
                i--)
              InkWell(
                // onTap: () {},
                onLongPress: () {
                  BlocProvider.of<DailyBreadCubit>(context).deletDailyBread(i);
                },
                child: Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.amber[200]),
                  margin: EdgeInsets.all(10),
                  padding: EdgeInsets.all(10),
                  child: ListTile(
                    title: Text(
                      BlocProvider.of<DailyBreadCubit>(context)
                          .dailyList[i]
                          .titel,
                      style: TextStyle(
                          color: AppColors.backgroundColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.edit),
                      color: AppColors.backgroundColor,
                      iconSize: 20,
                      onPressed: () {
                        Navigator.push(
                            context,
                            CupertinoPageRoute(
                                builder: (BuildContext _) => EditDailyBread(
                                    dailyBreadModel:
                                        BlocProvider.of<DailyBreadCubit>(
                                                context)
                                            .dailyList[i])));
                      },
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
