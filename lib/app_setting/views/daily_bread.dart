import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_states.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';
import 'edit_daily_bread.dart';
import 'add_daily_bread.dart';

class DailyBread extends StatefulWidget {
  const DailyBread({super.key});

  @override
  State<DailyBread> createState() => _DailyBreadState();
}

class _DailyBreadState extends State<DailyBread> {
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    BlocProvider.of<DailyBreadCubit>(context).fetchDailyBread();
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
        title: Text("Daily Bread", style: TextStyle(color: AppColors.appamber)),
        centerTitle: true,
        backgroundColor: AppColors.backgroundColor,
        leading: BackBtn(),
        actions: isAdmin
            ? [
                IconButton(
                  icon: Icon(Icons.add, color: AppColors.appamber, size: 30),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AddDailyBread()),
                    );
                    BlocProvider.of<DailyBreadCubit>(context).fetchDailyBread();
                  },
                ),
              ]
            : [],
      ),
      body: BlocBuilder<DailyBreadCubit, DailyBreadStates>(
        builder: (context, state) {
          if (state is DailyBreadLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is DailyBreadLoaded) {
            if (state.dailyItems.isEmpty) {
              return const Center(child: Text("لا يوجد خبز يومي متاح"));
            }

            return ListView.builder(
              itemCount: state.dailyItems.length,
              itemBuilder: (context, index) {
                var item = state.dailyItems[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: AppColors.appamber,
                  child: ListTile(
                    title: Text(
                      item['content'],
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.backgroundColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onLongPress: isAdmin
                        ? () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditDailyBread(
                                  docId: item['id'],
                                  initialContent: item['content'],
                                ),
                              ),
                            );
                            BlocProvider.of<DailyBreadCubit>(context)
                                .fetchDailyBread();
                          }
                        : null,
                  ),
                );
              },
            );
          } else {
            return const Center(child: Text("حدث خطأ أثناء تحميل البيانات"));
          }
        },
      ),
      bottomNavigationBar: const AdBanner(),
    );
  }
}
