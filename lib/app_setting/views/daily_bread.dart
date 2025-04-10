import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/daily_bread_states.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'edit_daily_bread.dart';
import 'add_daily_bread.dart';

class DailyBread extends StatefulWidget {
  const DailyBread({super.key});

  @override
  State<DailyBread> createState() => _DailyBreadState();
}

class _DailyBreadState extends State<DailyBread> with WidgetsBindingObserver {
  bool isAdmin = false;
  bool isOffline = false;
  DateTime? _lastCheckDate;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _checkConnectivity();
    _lastCheckDate = DateTime.now();

    // إضافة مراقب دورة حياة التطبيق
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // إزالة مراقب دورة حياة التطبيق
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // تنفيذ دالة didChangeAppLifecycleState لمراقبة حالة التطبيق
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // عند استئناف التطبيق، تحقق مما إذا كان يجب تحديث البيانات
      _checkConnectivity();
      _checkForNewDay();
    }
  }

  // التحقق مما إذا كان يوم جديد
  void _checkForNewDay() {
    if (!isOffline && _lastCheckDate != null) {
      final now = DateTime.now();
      final isNewDay = _lastCheckDate!.year != now.year ||
          _lastCheckDate!.month != now.month ||
          _lastCheckDate!.day != now.day;

      if (isNewDay) {
        print('📅 يوم جديد، جاري تحديث الخبز اليومي...');
        BlocProvider.of<DailyBreadCubit>(context).checkForUpdates();
        setState(() {
          _lastCheckDate = now;
        });
      }
    }
  }

  Future<void> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      isOffline = connectivityResult == ConnectivityResult.none;
    });
  }

  Future<void> _fetchUserRole() async {
    try {
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
    } catch (e) {
      print('❌ خطأ في جلب دور المستخدم: $e');
    }
  }

  Future<void> _refreshData() async {
    await _checkConnectivity();
    if (!isOffline) {
      await BlocProvider.of<DailyBreadCubit>(context)
          .fetchDailyBread(useCache: false);
      setState(() {
        _lastCheckDate = DateTime.now();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أنت غير متصل بالإنترنت. يتم عرض البيانات المخزنة.'),
          duration: Duration(seconds: 2),
        ),
      );
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
        actions: [
          // زر الإضافة للمسؤول فقط
          if (isAdmin)
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
        ],
      ),
      body: Column(
        children: [
          // عرض شريط تنبيه عندما يكون المستخدم غير متصل
          if (isOffline)
            Container(
              width: double.infinity,
              color: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: const Text(
                'أنت غير متصل بالإنترنت. يتم عرض البيانات المخزنة.',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          // محتوى الصفحة الرئيسي
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              color: AppColors.appamber,
              backgroundColor: AppColors.backgroundColor,
              child: BlocBuilder<DailyBreadCubit, DailyBreadStates>(
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
                          margin: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
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
                            onLongPress: isAdmin && !isOffline
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
                  } else if (state is DailyBreadError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(state.message),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refreshData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.appamber,
                              foregroundColor: AppColors.backgroundColor,
                            ),
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return const Center(
                        child: Text("حدث خطأ أثناء تحميل البيانات"));
                  }
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          AdBanner(key: UniqueKey(), cacheKey: 'daily_bread_screen'),
    );
  }
}
