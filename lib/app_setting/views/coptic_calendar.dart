import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:om_elnour_choir/app_setting/views/edit_coptic_calendar.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_states.dart';
import 'package:om_elnour_choir/app_setting/views/add_coptic_calendar.dart';

class CopticCalendar extends StatefulWidget {
  const CopticCalendar({super.key});

  @override
  State<CopticCalendar> createState() => _CopticCalendarState();
}

class _CopticCalendarState extends State<CopticCalendar> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Coptic Calendar',
          style: TextStyle(color: Colors.amber),
        ),
        centerTitle: true,
        backgroundColor: AppColors.backgroundColor,
        leading: BackBtn(),
        actions: [
          IconButton(
              onPressed: () {
                Navigator.push(context,
                    CupertinoPageRoute(builder: (_) => AddCopticCalendar()));
              },
              icon: Icon(
                Icons.add,
                color: Colors.amber[200],
              ))
        ],
      ),
      body: BlocBuilder<CopticCalendarCubit, CopticCalendarStates>(
        builder: (context, state) => ListView(
          children: [
            for (int i = BlocProvider.of<CopticCalendarCubit>(context)
                        .copticCal
                        .length -
                    1;
                i >= 0;
                i--)
              InkWell(
                // onTap: () {},
                onLongPress: () {
                  BlocProvider.of<CopticCalendarCubit>(context)
                      .deletCopticCalendar(i);
                },
                child: Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.amber[200]),
                  margin: EdgeInsets.all(10),
                  padding: EdgeInsets.all(10),
                  child: ListTile(
                    title: Text(
                      BlocProvider.of<CopticCalendarCubit>(context)
                          .copticCal[i]
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
                                builder: (BuildContext _) => EditCopticCalendar(
                                    copticCalendarModel:
                                        BlocProvider.of<CopticCalendarCubit>(
                                                context)
                                            .copticCal[i])));
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
