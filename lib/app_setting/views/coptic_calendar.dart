import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/coptic_calendar_states.dart';
import 'package:om_elnour_choir/app_setting/views/add_coptic_calendar.dart';
import 'package:om_elnour_choir/app_setting/views/edit_coptic_calendar.dart';

class CopticCalendar extends StatefulWidget {
  const CopticCalendar({super.key});

  @override
  State<CopticCalendar> createState() => _CopticCalendarState();
}

class _CopticCalendarState extends State<CopticCalendar> {
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    BlocProvider.of<CopticCalendarCubit>(context).fetchCopticCalendar();
  }

  Future<void> _fetchUserRole() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      var userDoc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(userId)
          .get();
      if (userDoc.exists && userDoc.data()?['role'] == "admin") {
        setState(() {
          isAdmin = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text('Coptic Calendar',
            style: TextStyle(color: AppColors.appamber)),
        centerTitle: true,
        backgroundColor: AppColors.backgroundColor,
        leading: BackBtn(),
        actions: isAdmin
            ? [
                IconButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => AddCopticCalendar()),
                    );
                    BlocProvider.of<CopticCalendarCubit>(context)
                        .fetchCopticCalendar();
                  },
                  icon: Icon(Icons.add, color: AppColors.appamber),
                )
              ]
            : [],
      ),
      body: BlocBuilder<CopticCalendarCubit, CopticCalendarStates>(
        builder: (context, state) {
          if (state is CopticCalendarLoadingState) {
            return Center(child: CircularProgressIndicator());
          } else if (state is CopticCalendarLoadedState) {
            if (state.copticCalendarItems.isEmpty) {
              return Center(child: Text("لا توجد أحداث قبطية اليوم"));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: state.copticCalendarItems.length,
              itemBuilder: (context, index) {
                var item = state.copticCalendarItems[index];
                return Card(
                  color: AppColors.appamber,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  margin:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  child: ListTile(
                    title: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        item.content,
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.backgroundColor,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    onLongPress: isAdmin
                        ? () async {
                            await Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => EditCopticCalendar(
                                    copticCalendarModel: item),
                              ),
                            );
                            BlocProvider.of<CopticCalendarCubit>(context)
                                .fetchCopticCalendar();
                          }
                        : null,
                  ),
                );
              },
            );
          } else {
            return Center(child: Text("حدث خطأ أثناء تحميل البيانات"));
          }
        },
      ),
      bottomNavigationBar: AdBanner(key: UniqueKey()),
    );
  }
}
