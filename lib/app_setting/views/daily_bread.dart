import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_states.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';
import 'add_daily_bread.dart';
import 'edit_daily_bread.dart';

class DailyBread extends StatefulWidget {
  const DailyBread({super.key});

  @override
  State<DailyBread> createState() => _DailyBreadState();
}

class _DailyBreadState extends State<DailyBread> {
  @override
  void initState() {
    super.initState();
    BlocProvider.of<DailyBreadCubit>(context).fetchDailyBread();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: const Text("Daily Bread", style: TextStyle(color: Colors.amber)),
        centerTitle: true,
        leading: BackBtn(),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.amber, size: 30),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddDailyBread()),
              );
              BlocProvider.of<DailyBreadCubit>(context).fetchDailyBread();
            },
          ),
        ],
      ),
      body: BlocBuilder<DailyBreadCubit, DailyBreadStates>(
        builder: (context, state) {
          if (state is DailyBreadLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is DailyBreadLoaded) {
            return ListView.builder(
              itemCount: state.dailyItems.length,
              itemBuilder: (context, index) {
                var item = state.dailyItems[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: Colors.amber[300],
                  child: ListTile(
                    title: Text(item['content'], textAlign: TextAlign.right),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () async {
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
                      },
                    ),
                  ),
                );
              },
            );
          } else if (state is DailyBreadEmptyState) {
            return const Center(child: Text("لا يوجد خبز يومي متاح"));
          } else {
            return const Center(child: Text("حدث خطأ أثناء تحميل البيانات"));
          }
        },
      ),
      bottomNavigationBar: const AdBanner(),
    );
  }
}
