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
      // تحديث البيانات
      _refreshData();
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
        if (!mounted) return; // أضف هذا السطر
        setState(() {
          isAdmin = true;
        });
      }
    }
  }

  // دالة لتحويل الأرقام الإنجليزية إلى أرقام عربية
  String _convertToArabicNumbers(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }

    return input;
  }

  Future<void> _initializeArabicDate() async {
    await initializeDateFormatting('ar', null);
    final now = DateTime.now();
    final arabicDateFormat = DateFormat('EEEE d MMMM yyyy', 'ar');
    String formattedDate = arabicDateFormat.format(now);
    formattedDate = _convertToArabicNumbers(formattedDate);

    if (!mounted) return; // أضف هذا السطر
    setState(() {
      _arabicDate = formattedDate;
    });
  }

  // دالة لحساب حجم الخط المتغير
  double _calculateFontSize(
      BuildContext context, double baseSize, double multiplier) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // استخدام القيمة الأصغر بين العرض والارتفاع للحصول على حجم خط متناسق
    final smallerDimension = isLandscape ? screenHeight : screenWidth;

    // تعديل معامل الحجم حسب الاتجاه
    final fontSizeMultiplier = isLandscape ? multiplier * 1.2 : multiplier;

    // استخدام قيمة أساسية ثابتة مع إضافة القيمة المتغيرة
    return baseSize + (smallerDimension * fontSizeMultiplier * 0.1);
  }

  // دالة لحساب قيم التصميم المتغيرة (الهوامش، الحشو، نصف القطر)
  Map<String, dynamic> _calculateResponsiveValues(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // استخدام القيمة الأصغر بين العرض والارتفاع
    final smallerDimension = isLandscape ? screenHeight : screenWidth;

    // حساب القيم المتغيرة
    return {
      'containerPadding': EdgeInsets.symmetric(
        vertical: 12.0 + (smallerDimension * 0.01),
        horizontal: 16.0 + (smallerDimension * 0.02),
      ),
      'containerMargin': EdgeInsets.all(10.0 + (smallerDimension * 0.01)),
      'borderRadius': 15.0 + (smallerDimension * 0.01),
      'borderWidth': 1.0 + (smallerDimension * 0.002),
      'cardPadding': EdgeInsets.all(12.0 + (smallerDimension * 0.015)),
      'cardMargin': EdgeInsets.symmetric(
        vertical: 8.0 + (smallerDimension * 0.008),
        horizontal: 10.0 + (smallerDimension * 0.01),
      ),
      'shadowBlur': 8.0 + (smallerDimension * 0.01),
      'shadowOffset': Offset(0, 2 + (smallerDimension * 0.003)),
    };
  }

  // دالة لتحديث البيانات
  Future<void> _refreshData() async {
    await BlocProvider.of<CopticCalendarCubit>(context).fetchCopticCalendar();
    if (mounted) {
      setState(() {});
    }
  }

  // تعديل دالة build لاستخدام القيم المتغيرة
  @override
  Widget build(BuildContext context) {
    // حساب أحجام الخط المختلفة
    final titleFontSize = _calculateFontSize(context, 18.0, 0.05);
    final dateFontSize = _calculateFontSize(context, 16.0, 0.04);
    final contentFontSize = _calculateFontSize(context, 18.0, 0.05);
    final emptyMessageFontSize = _calculateFontSize(context, 18.0, 0.05);

    // حساب قيم التصميم المتغيرة
    final responsiveValues = _calculateResponsiveValues(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text('Coptic Calendar',
            style: TextStyle(color: AppColors.appamber)),
        centerTitle: true,
        backgroundColor: AppColors.backgroundColor,
        leading: BackBtn(),
        actions: [
          if (isAdmin)
            IconButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => AddCopticCalendar()),
                );

                // إذا تمت الإضافة بنجاح، قم بتحديث البيانات
                if (result == true) {
                  // إعادة تحميل البيانات
                  await _refreshData();
                }
              },
              icon: Icon(Icons.add, color: AppColors.appamber),
            ),
        ],
      ),
      body: Stack(
        children: [
          // المحتوى الرئيسي مع هامش سفلي لتجنب تداخله مع الإعلان
          Positioned.fill(
            bottom: 60, // ارتفاع الإعلان تقريباً
            child: RefreshIndicator(
              onRefresh: _refreshData,
              color: AppColors.appamber,
              backgroundColor: AppColors.backgroundColor,
              child: BlocBuilder<CopticCalendarCubit, CopticCalendarStates>(
                builder: (context, state) {
                  if (state is CopticCalendarLoadingState) {
                    return Center(
                        child: CircularProgressIndicator(
                            color: AppColors.appamber));
                  } else if (state is CopticCalendarLoadedState) {
                    if (state.copticCalendarItems.isEmpty) {
                      return Center(
                        child: Text(
                          "لا توجد أحداث قبطية اليوم",
                          style: TextStyle(
                            color: AppColors.appamber,
                            fontSize: emptyMessageFontSize,
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        // عنوان التاريخ بالعربية
                        Container(
                          padding: responsiveValues['containerPadding'],
                          margin: responsiveValues['containerMargin'],
                          decoration: BoxDecoration(
                            color: AppColors.appamber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(
                                responsiveValues['borderRadius']),
                            border: Border.all(
                              color: AppColors.appamber,
                              width: responsiveValues['borderWidth'],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.appamber.withOpacity(0.2),
                                blurRadius: responsiveValues['shadowBlur'],
                                offset: responsiveValues['shadowOffset'],
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.calendar_today,
                                      color: AppColors.appamber),
                                  SizedBox(width: 8),
                                  Text(
                                    "سنكسار اليوم",
                                    style: TextStyle(
                                      fontSize: titleFontSize,
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
                                    fontSize: dateFontSize,
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

                              // تحويل أي أرقام في المحتوى إلى أرقام عربية
                              String arabicContent =
                                  _convertToArabicNumbers(item.content);

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 10),
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.appamber,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          AppColors.appamber.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onLongPress: isAdmin
                                      ? () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  EditCopticCalendar(
                                                copticCalendarModel: item,
                                              ),
                                            ),
                                          );
                                          if (result == true) {
                                            await _refreshData();
                                          }
                                        }
                                      : null,
                                  // استخدام SingleChildScrollView لضمان إمكانية التمرير داخل العنصر
                                  child: SingleChildScrollView(
                                    child: Text(
                                      arabicContent,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: contentFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.appamber,
                                        height: 1.3, // إضافة تباعد بين الأسطر
                                        letterSpacing:
                                            0.5, // زيادة المسافة بين الحروف قليلاً
                                      ),
                                    ),
                                  ),
                                ),
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
                          fontSize: emptyMessageFontSize,
                        ),
                      ),
                    );
                  } else {
                    return Center(
                      child: Text(
                        "حدث خطأ أثناء تحميل البيانات",
                        style: TextStyle(
                          color: AppColors.appamber,
                          fontSize: emptyMessageFontSize,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ),

          // الإعلان في الأسفل
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AdBanner(
              key: ValueKey('coptic_calendar_ad_banner'),
              cacheKey: 'coptic_calendar_screen',
            ),
          ),
        ],
      ),
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
