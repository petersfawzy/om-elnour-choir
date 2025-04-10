import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui; // إضافة استيراد صريح لمكتبة dart:ui
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
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class CopticCalendar extends StatefulWidget {
  const CopticCalendar({super.key});

  @override
  State<CopticCalendar> createState() => _CopticCalendarState();
}

class _CopticCalendarState extends State<CopticCalendar>
    with WidgetsBindingObserver {
  bool isAdmin = false;
  String _arabicDate = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUserRole();
    _initializeArabicDate();

    // التحقق من تغير اليوم عند بدء الشاشة
    BlocProvider.of<CopticCalendarCubit>(context).checkForDayChange();
    BlocProvider.of<CopticCalendarCubit>(context).fetchCopticCalendar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // التحقق من تغير اليوم عند العودة إلى التطبيق
      BlocProvider.of<CopticCalendarCubit>(context).checkForDayChange();
    }
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

  Future<void> _initializeArabicDate() async {
    // تهيئة البيانات المحلية العربية
    await initializeDateFormatting('ar', null);

    // الحصول على التاريخ الحالي بالعربية
    final now = DateTime.now();
    final arabicDateFormat = DateFormat('EEEE d MMMM yyyy', 'ar');
    setState(() {
      _arabicDate = arabicDateFormat.format(now);
    });
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
            return Center(
                child: CircularProgressIndicator(color: AppColors.appamber));
          } else if (state is CopticCalendarLoadedState) {
            if (state.copticCalendarItems.isEmpty) {
              return Center(
                child: Text(
                  "لا توجد أحداث قبطية اليوم",
                  style: TextStyle(
                    color: AppColors.appamber,
                    fontSize: 18,
                  ),
                ),
              );
            }

            return Column(
              children: [
                // عنوان التاريخ بالعربية
                Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  margin: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.appamber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppColors.appamber, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, color: AppColors.appamber),
                          SizedBox(width: 8),
                          Text(
                            "سنكسار اليوم",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.appamber,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      // استخدام Directionality مع TextDirection.rtl من مكتبة dart:ui
                      Directionality(
                        textDirection: ui.TextDirection.rtl,
                        child: Text(
                          _arabicDate,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.appamber,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                // قائمة الأحداث
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: state.copticCalendarItems.length,
                    itemBuilder: (context, index) {
                      var item = state.copticCalendarItems[index];

                      // تنسيق وقت الإضافة إذا كان متاحًا
                      String timeAdded = "";
                      if (item.dateAdded != null) {
                        DateTime dateTime = item.dateAdded!.toDate();
                        timeAdded = DateFormat('h:mm a').format(dateTime);
                      }

                      return Card(
                        color: AppColors.appamber,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        margin: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // محتوى الحدث
                            Padding(
                              padding: const EdgeInsets.all(12.0),
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

                            // وقت الإضافة (إذا كان متاحًا)
                            if (timeAdded.isNotEmpty)
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                              ),
                          ],
                        ),
                      ).gestureDetector(
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
                      );
                    },
                  ),
                ),
              ],
            );
          } else if (state is CopticCalendarEmptyState) {
            return Center(
              child: Text(
                "لا توجد أحداث قبطية اليوم",
                style: TextStyle(
                  color: AppColors.appamber,
                  fontSize: 18,
                ),
              ),
            );
          } else {
            return Center(
              child: Text(
                "حدث خطأ أثناء تحميل البيانات",
                style: TextStyle(
                  color: AppColors.appamber,
                  fontSize: 18,
                ),
              ),
            );
          }
        },
      ),
      bottomNavigationBar:
          AdBanner(key: UniqueKey(), cacheKey: 'coptic_calendar_screen'),
    );
  }
}

// امتداد للـ Widget لإضافة gestureDetector
extension GestureDetectorExtension on Widget {
  Widget gestureDetector({GestureLongPressCallback? onLongPress}) {
    if (onLongPress == null) return this;
    return GestureDetector(
      onLongPress: onLongPress,
      child: this,
    );
  }
}
