import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_states.dart';
import 'package:om_elnour_choir/app_setting/views/HymnsPage.dart';
import 'package:om_elnour_choir/app_setting/views/about_us.dart';
import 'package:om_elnour_choir/app_setting/views/add_verce.dart';
import 'package:om_elnour_choir/app_setting/views/coptic_calendar.dart';
import 'package:om_elnour_choir/app_setting/views/daily_bread.dart';
import 'package:om_elnour_choir/app_setting/views/news.dart';
import 'package:om_elnour_choir/app_setting/views/notifications_screen.dart';
import 'package:om_elnour_choir/main.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/scaffold_with_background.dart';
import 'package:om_elnour_choir/user/views/profile_screen.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:om_elnour_choir/services/remote_config_service.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart'; // أو المسار الصحيح
import 'package:package_info_plus/package_info_plus.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ignore_battery_optimization/ignore_battery_optimization.dart';
import 'package:android_intent_plus/android_intent.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late Future<String?> _userNameFuture;
  bool showSocialIcons = false;
  bool isAdmin = false;
  final RemoteConfigService _remoteConfigService = RemoteConfigService();
  int _unreadNotificationsCount = 0;
  bool _batteryDialogShown = false;
  // إضافة متغيرات لإعلان الفتح
  bool _isAdShown = false;
  // إضافة متغير لتتبع ما إذا كان Widget لا يزال موجودًا
  bool _isMounted = true;
  bool _isCheckingUpdate = false;
  final bool _isTestingMode = true; // غيّر إلى false في الإنتاج إذا أردت
  bool _isUpdateCheckComplete = false;
  bool _isUpdateDialogOpen = false;
  bool _isNavigating = false;
  final String _packageName =
      "com.egypt.redcherry.omelnourchoir"; // غيّر حسب باكدجك
  final String _appStoreId = "1660609952"; // هذا هو ID الصحيح من رابط المتجر

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      maybeShowBatteryDialog(context);
      _checkForUpdates(); // ← أضف هذا السطر هنا
    });
    // استدعاء fetchVerse مباشرة بدلاً من checkForVerseUpdate
    Future.delayed(Duration.zero, () {
      print('🔄 جاري تحميل الآية مباشرة...');
      context.read<VerceCubit>().fetchVerse();
    });

    _userNameFuture = _getUserName();
    // إضافة مراقب دورة حياة التطبيق
    WidgetsBinding.instance.addObserver(this);
    // تحديث عدد الإشعارات غير المقروءة
    _updateUnreadNotificationsCount();
    // عرض إعلان الفتح بعد بناء الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // _showOpenAd();
    });
  }

  @override
  void dispose() {
    // تعيين المتغير لمنع استدعاء setState بعد التخلص من الـ widget
    _isMounted = false;

    // إزالة مراقب دورة حياة التطبيق
    WidgetsBinding.instance.removeObserver(this);

    print('🧹 تم التخلص من HomeScreen');
    super.dispose();
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    const platform = MethodChannel('omelnour/battery_optimization');
    try {
      final bool ignoring =
          await platform.invokeMethod('isIgnoringBatteryOptimizations');
      return ignoring;
    } catch (e) {
      return false; // في حالة الخطأ اعتبر أنه غير مستثنى
    }
  }

  // دالة لتحديث عدد الإشعارات غير المقروءة
  Future<void> _updateUnreadNotificationsCount() async {
    if (!_isMounted) return;

    try {
      if (notificationService != null) {
        final count = await notificationService!.getUnreadCount();
        if (_isMounted) {
          setState(() {
            _unreadNotificationsCount = count;
          });
        }
      }
    } catch (e) {
      print('❌ خطأ في تحديث عدد الإشعارات غير المقروءة: $e');
    }
  }

  // تنفيذ دالة didChangeAppLifecycleState لمراقبة حالة التطبيق
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isMounted) return; // التحقق من أن الـ widget لا يزال موجودًا

    if (state == AppLifecycleState.resumed) {
      // عند استئناف التطبيق، تحقق مما إذا كان يجب تحديث الآية
      context.read<VerceCubit>().checkForVerseUpdate();

      // تحديث عدد الإشعارات غير المقروءة
      _updateUnreadNotificationsCount();

      // لا نعرض الإعلان عند العودة من الخلفية، فقط نقوم بتحميله
      Future.delayed(Duration(seconds: 3), () {
        if (_isMounted) {
          // _appOpenAdService.loadAd();
        }
      });
    }
  }

  Future<void> _fetchUserRole() async {
    if (!_isMounted) return; // التحقق من أن الـ widget لا يزال موجودًا

    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      var userDoc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(userId)
          .get();
      if (userDoc.exists && userDoc.data()?['role'] == "admin") {
        if (_isMounted) {
          setState(() {
            isAdmin = true;
          });
        }
      }
    }
  }

  Future<String?> _getUserName() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String? name = user.displayName;
        if (name == null || name.isEmpty) {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('userData')
              .doc(user.uid)
              .get();
          if (userDoc.exists) {
            return (userDoc.data() as Map<String, dynamic>)['name'] ??
                "My Profile";
          }
        }
        return name;
      }
    } catch (e) {
      print("Error fetching user name: $e");
    }
    return "My Profile";
  }

  void _toggleSocialIcons() {
    if (!_isMounted) return; // التحقق من أن الـ widget لا يزال موجودًا

    setState(() {
      showSocialIcons = !showSocialIcons;
    });
  }

  // دالة للتعامل مع ضغطة زر الرجوع
  Future<bool> _onWillPop() async {
    if (!_isMounted) return false; // التحقق من أن الـ widget لا يزال موجودًا

    try {
      // استخدام قناة المنصة لتصغير التطبيق
      if (Platform.isAndroid) {
        // على Android، استخدم قناة المنصة لاستدعاء moveTaskToBack
        const platform = MethodChannel('com.egypt.redcherry.omelnourchoir/app');
        await platform.invokeMethod('moveTaskToBack');

        // إظهار رسالة للمستخدم
        if (_isMounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تصغير التطبيق، يعمل الآن في الخلفية'),
              duration: Duration(seconds: 1),
            ),
          );
        }

        return false; // منع إغلاق التطبيق
      } else {
        // على iOS، لا يمكن تصغير التطبيق بنفس الطريقة
        // يمكن إظهار رسالة للمستخدم
        if (_isMounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('اضغط على زر الصفحة الرئيسية لتصغير التطبيق'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        return false; // منع إغلاق التطبيق
      }
    } catch (e) {
      print('❌ خطأ في تصغير التطبيق: $e');

      // في حالة الخطأ، نعود إلى السلوك الافتراضي
      return false;
    }
  }

  // دالة لتحديث الألوان من Remote Config
  Future<void> _refreshRemoteConfig() async {
    if (!_isMounted) return; // التحقق من أن الـ widget لا يزال موجودًا

    try {
      await _remoteConfigService.refresh();
      AppColors.updateFromRemoteConfig();
      // إعادة بناء الواجهة لتطبيق الألوان الجديدة
      if (_isMounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث الألوان بنجاح')),
        );
      }
    } catch (e) {
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحديث الألوان: $e')),
        );
      }
    }
  }

  // دالة للتحقق من الألوان الحالية (للتصحيح)
  void _debugColors() {
    if (!_isMounted) return; // التحقق من أن الـ widget لا يزال موجودًا

    AppColors.debugColors();

    // عرض رسالة للمستخدم
    if (_isMounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم طباعة معلومات الألوان في سجل التصحيح'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // أضف هذه الدالة في فئة _HomeScreenState
  void _showAllConfigValues() {
    if (!_isMounted) return; // التحقق من أن الـ widget لا يزال موجودًا

    final configValues = _remoteConfigService.getAllConfigValues();

    // طباعة جميع القيم في سجل التصحيح
    print('📊 جميع قيم التكوين:');
    configValues.forEach((key, value) {
      print('$key: $value');
    });

    // عرض رسالة للمستخدم
    if (_isMounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم طباعة جميع قيم التكوين في سجل التصحيح'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // دالة للانتقال إلى شاشة الملف الشخصي
  void _navigateToProfile() {
    if (!_isMounted) return; // التحقق من أن الـ widget لا يزال موجودًا

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  // دالة للانتقال إلى شاشة الإشعارات
  void _navigateToNotifications() async {
    if (!_isMounted || notificationService == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationsScreen(
          notificationService: notificationService!,
        ),
      ),
    );

    // تحديث عدد الإشعارات غير المقروءة بعد العودة من شاشة الإشعارات
    _updateUnreadNotificationsCount();
  }

  // تعديل دالة _shareVerse لاستخدام نص ورابط من Remote Config
  Future<void> _shareVerse(String verse) async {
    if (!_isMounted) return; // التحقق من أن الـ widget لا يزال موجودًا

    try {
      print('🔄 بدء مشاركة الآية: $verse'); // إضافة سجل تصحيح

      // الحصول على رابط التطبيق ونص المشاركة من Remote Config
      final String appLink = _remoteConfigService.getShareAppLink();
      final String shareText = _remoteConfigService.getShareVerseText();

      print('📱 رابط التطبيق: $appLink'); // إضافة سجل تصحيح
      print('📝 نص المشاركة: $shareText'); // إضافة سجل تصحيح

      // تنسيق النص بشكل أبسط لتجنب المشاكل
      final String textToShare = "$verse\n\n$shareText\n$appLink";

      print('📤 النص الكامل للمشاركة: $textToShare'); // إضافة سجل تصحيح

      // استخدام طريقة أبسط للمشاركة
      final result = await Share.share(
        textToShare,
        subject: 'آية من تطبيق كورال أم النور',
      );

      print('✅ تم فتح نافذة المشاركة بنجاح');
      // print('📊 نتيجة المشاركة: $result');
    } catch (e) {
      print('❌ خطأ في المشاركة: $e');

      // في حالة حدوث خطأ، نسخ النص إلى الحافظة كحل بديل
      try {
        final String appLink = _remoteConfigService.getShareAppLink();
        final String shareText = _remoteConfigService.getShareVerseText();
        final String textToShare = "$verse\n\n$shareText\n$appLink";
        await Clipboard.setData(ClipboardData(text: textToShare));

        // إظهار رسالة للمستخدم في حالة فشل المشاركة
        if (_isMounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'تم نسخ الآية إلى الحافظة. يمكنك لصقها في أي تطبيق للمشاركة.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (clipboardError) {
        print('❌ خطأ في نسخ النص إلى الحافظة: $clipboardError');
        if (_isMounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشلت عملية المشاركة: $e'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  // تعديل بناء الشاشة الرئيسية لتحسين التوزيع والسماح بالتمرير
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    bool isWideScreen = screenWidth > 800;

    // استخدام WillPopScope للتحكم في سلوك زر الرجوع
    return WillPopScope(
      onWillPop: _onWillPop,
      child: ScaffoldWithBackground(
        appBar: PreferredSize(
          // تعديل ارتفاع AppBar ليكون أكثر تناسبًا في الوضع الأفقي
          preferredSize: Size.fromHeight(
              isLandscape ? screenHeight * 0.12 : screenHeight * 0.07),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: screenWidth * 0.02,
            // تعديل العنوان ليظهر كاملاً في جميع الأوضاع
            title: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Om Elnour Choir', // إظهار الاسم كاملاً في جميع الأوضاع
                style: TextStyle(
                  color: AppColors.appamber,
                  // تعديل حجم الخط ليكون متناسقًا مع باقي النصوص
                  fontSize:
                      isLandscape ? screenWidth * 0.028 : screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            centerTitle: false,
            actions: [
              // إضافة زر الإشعارات مع عداد الإشعارات غير المقروءة
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications,
                        color: AppColors.appamber,
                        // تعديل حجم الأيقونة لتكون متناسقة مع باقي العناصر
                        size: isLandscape
                            ? screenWidth * 0.028
                            : screenWidth * 0.06,
                      ),
                      padding: EdgeInsets.all(screenWidth * 0.01),
                      constraints: BoxConstraints(), // إزالة القيود الافتراضية
                      visualDensity:
                          VisualDensity.compact, // تقليل المساحة المستخدمة
                      onPressed: _navigateToNotifications,
                    ),
                    if (_unreadNotificationsCount > 0)
                      Positioned(
                        right: screenWidth * 0.01,
                        top: screenWidth * 0.01,
                        child: Container(
                          padding: EdgeInsets.all(screenWidth * 0.005),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius:
                                BorderRadius.circular(screenWidth * 0.02),
                          ),
                          constraints: BoxConstraints(
                            minWidth: isLandscape
                                ? screenWidth * 0.025
                                : screenWidth * 0.04,
                            minHeight: isLandscape
                                ? screenWidth * 0.025
                                : screenWidth * 0.04,
                          ),
                          child: Center(
                            child: Text(
                              _unreadNotificationsCount > 9
                                  ? '9+'
                                  : _unreadNotificationsCount.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                // تعديل حجم الخط ليكون متناسقًا
                                fontSize: isLandscape
                                    ? screenWidth * 0.016
                                    : screenWidth * 0.025,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // دمج أيقونة الشخص واسم المستخدم في عنصر واحد قابل للنقر
              Padding(
                padding: EdgeInsets.only(
                  right: screenWidth * 0.02,
                  left: screenWidth * 0.02,
                ),
                child: FutureBuilder<String?>(
                  future: _userNameFuture,
                  builder: (context, snapshot) {
                    // تحديد اسم المستخدم المعروض بناءً على حجم الشاشة
                    String displayName = "Profile";
                    if (snapshot.data != null) {
                      // تعديل منطق عرض الاسم ليظهر كاملاً في الوضع الأفقي عندما يكون هناك مساحة كافية
                      if (screenWidth < 360) {
                        // للشاشات الصغيرة جدًا فقط، عرض الاسم الأول
                        displayName = snapshot.data!.split(' ').first;
                      } else if (isLandscape && screenWidth < 600) {
                        // في الوضع الأفقي للشاشات المتوسطة، عرض الاسم كاملاً إذا كان قصيرًا
                        displayName = snapshot.data!.length > 15
                            ? snapshot.data!.split(' ').first
                            : snapshot.data!;
                      } else {
                        // في باقي الحالات، عرض الاسم كاملاً إذا كان مناسبًا
                        displayName =
                            snapshot.data!.length > 20 && screenWidth < 800
                                ? snapshot.data!.split(' ').first
                                : snapshot.data!;
                      }
                    }

                    return InkWell(
                      onTap: _navigateToProfile,
                      borderRadius: BorderRadius.circular(screenWidth * 0.04),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          // تعديل الحشو ليكون متناسقًا
                          horizontal: isLandscape
                              ? screenWidth * 0.018
                              : screenWidth * 0.02,
                          vertical: isLandscape
                              ? screenWidth * 0.01
                              : screenWidth * 0.01,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(screenWidth * 0.04),
                          border: Border.all(
                            color: AppColors.appamber.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person,
                              color: AppColors.appamber,
                              // تعديل حجم الأيقونة ليكون متناسقًا مع النص
                              size: isLandscape
                                  ? screenWidth * 0.024
                                  : screenWidth * 0.045,
                            ),
                            SizedBox(width: screenWidth * 0.01),
                            Text(
                              displayName,
                              style: TextStyle(
                                color: AppColors.appamber,
                                fontWeight: FontWeight.bold,
                                // تعديل حجم الخط ليكون متناسقًا مع عنوان التطبيق
                                fontSize: isLandscape
                                    ? screenWidth * 0.024
                                    : screenWidth * 0.035,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // استخدام Stack مع SafeArea لضمان عدم تداخل الإعلان مع المحتوى
        body: SafeArea(
          child: Stack(
            children: [
              // المحتوى الرئيسي
              SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: screenWidth * (isLandscape ? 0.02 : 0.03),
                    right: screenWidth * (isLandscape ? 0.02 : 0.03),
                    top: screenHeight * (isLandscape ? 0.01 : 0.015),
                    // زيادة الهامش السفلي لضمان عدم تداخل المحتوى مع الإعلان
                    bottom: screenHeight * 0.15,
                  ),
                  child: Column(
                    children: [
                      // مربع الآية - بدون ارتفاع ثابت
                      _buildVerseContainer(),

                      // مسافة بين الآية والأزرار
                      SizedBox(
                          height: screenHeight * (isLandscape ? 0.02 : 0.025)),

                      // الأزرار
                      BlocBuilder<VerceCubit, VerceState>(
                        builder: (context, state) {
                          // Debug print to check the state
                          print('🔍 VerceCubit state: ${state.runtimeType}');

                          // Extract verse from state if available
                          String? verse;
                          if (state is VerceLoaded) {
                            verse = state.verse;
                            print('📜 Verse loaded: $verse');
                          } else {
                            print(
                                '⚠️ Verse not loaded, state: ${state.runtimeType}');
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isAdmin) _buildAddVerseButton(),
                              if (isAdmin && verse != null)
                                SizedBox(
                                    width: screenWidth *
                                        0.02), // زيادة المسافة بين الزرين
                              if (verse != null) _buildShareVerseButton(verse),
                              // If no verse is loaded but we're not in loading state, show a disabled button
                              if (verse == null && state is! VerceLoading)
                                _buildDisabledShareButton(),
                            ],
                          );
                        },
                      ),

                      // مسافة بين الأزرار والشبكة
                      SizedBox(
                          height: screenHeight * (isLandscape ? 0.025 : 0.03)),

                      // الشبكة
                      isLandscape
                          ? _buildLandscapeGrid(screenWidth, screenHeight)
                          : _buildPortraitGrid(screenWidth, screenHeight),
                    ],
                  ),
                ),
              ),

              // تعديل موضع الإعلان ليكون في أسفل الشاشة تمامًا
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AdBanner(
                  key: ValueKey('home_screen_ad_banner'),
                  cacheKey: 'home_screen',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // تعديل دالة _buildVerseContainer لتتكيف مع حجم المحتوى
  Widget _buildVerseContainer() {
    return BlocBuilder<VerceCubit, VerceState>(
      builder: (context, state) {
        // حساب حجم الخط المتغير بناءً على حجم الشاشة
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;

        // تعديل حجم خط الآية في الوضع الرأسي
        // استخدام نسب مئوية لحساب حجم الخط والهوامش
        final fontSizePercentage =
            isLandscape ? 0.025 : 0.042; // زيادة حجم الخط في الوضع الرأسي
        final fontSize = screenWidth * fontSizePercentage;

        // تحسين الهوامش والحشو باستخدام نسب مئوية
        final paddingPercentage = isLandscape ? 0.025 : 0.035;
        final paddingVertical =
            screenHeight * paddingPercentage * 0.5; // تقليل الحشو الرأسي
        final paddingHorizontal = screenWidth * paddingPercentage;

        // حساب نصف قطر الحواف كنسبة من عرض الشاشة
        final borderRadiusPercentage = 0.03;
        final borderRadius = screenWidth * borderRadiusPercentage;

        if (state is VerceLoading) {
          return Container(
            // استخدام عرض تلقائي بدلاً من double.infinity
            width: screenWidth * 0.9, // 90% من عرض الشاشة كحد أقصى
            constraints: BoxConstraints(
              minHeight: screenHeight * 0.15, // حد أدنى للارتفاع
            ),
            margin: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05), // هوامش خارجية
            padding: EdgeInsets.symmetric(
              vertical: paddingVertical,
              horizontal: paddingHorizontal,
            ),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: AppColors.appamber.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.appamber),
              ),
            ),
          );
        } else if (state is VerceLoaded) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                width: screenWidth * 0.9, // 90% من عرض الشاشة كحد أقصى
                margin: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05), // هوامش خارجية
                padding: EdgeInsets.symmetric(
                  vertical: paddingVertical,
                  horizontal: paddingHorizontal,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: AppColors.appamber.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                // استخدام IntrinsicHeight لضبط الارتفاع وفقًا للمحتوى
                child: IntrinsicHeight(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                    child: Text(
                      state.verse,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.appamber,
                        height: 1.4, // زيادة تباعد السطور لتحسين القراءة
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        } else {
          return Container(
            width: screenWidth * 0.9, // 90% من عرض الشاشة كحد أقصى
            constraints: BoxConstraints(
              minHeight: screenHeight * 0.15, // حد أدنى للارتفاع
            ),
            margin: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05), // هوامش خارجية
            padding: EdgeInsets.symmetric(
              vertical: paddingVertical,
              horizontal: paddingHorizontal,
            ),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: AppColors.appamber.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                "❌ لا توجد آية متاحة",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.appamber,
                  fontSize: fontSize,
                ),
              ),
            ),
          );
        }
      },
    );
  }

  // تحسين مظهر زر إضافة الآية
  Widget _buildAddVerseButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // تعديل حجم خط زر إضافة الآية في الوضع الرأسي
    // حساب حجم الخط والهوامش كنسب مئوية
    final fontSize = screenWidth *
        (isLandscape ? 0.018 : 0.03); // زيادة حجم الخط في الوضع الرأسي
    final horizontalPadding = screenWidth * 0.03;
    final verticalPadding = screenHeight * 0.015;
    final borderRadius = screenWidth * 0.015;

    // طباعة قيم الألوان للتحقق
    print('🎨 لون الخلفية لزر الإضافة: ${AppColors.appamber}');
    print('🎨 لون النص لزر الإضافة: ${AppColors.backgroundColor}');

    return ElevatedButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddVerce()),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.appamber,
        foregroundColor: AppColors.backgroundColor,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        elevation: 3, // إضافة ارتفاع للزر
      ),
      child: Text(
        "Add Verse",
        style: TextStyle(
          color: AppColors.backgroundColor,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }

  // تعديل دالة _buildShareVerseButton لتطابق تصميم زر إضافة الآية تمامًا
  Widget _buildShareVerseButton(String verse) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // تعديل حجم خط زر مشاركة الآية في الوضع الرأسي
    // حساب حجم الخط والهوامش كنسب مئوية - نفس القيم المستخدمة في _buildAddVerseButton
    final fontSize = screenWidth *
        (isLandscape ? 0.018 : 0.03); // زيادة حجم الخط في الوضع الرأسي
    final horizontalPadding = screenWidth * 0.03;
    final verticalPadding = screenHeight * 0.015;
    final borderRadius = screenWidth * 0.015;

    // طباعة قيم الألوان للتحقق
    print('🎨 لون الخلفية لزر المشاركة: ${AppColors.appamber}');
    print('🎨 لون النص لزر المشاركة: ${AppColors.backgroundColor}');

    return ElevatedButton(
      onPressed: () {
        print('🔘 تم النقر على زر مشاركة الآية'); // إضافة سجل تصحيح
        _shareVerse(verse);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.appamber,
        foregroundColor: AppColors.backgroundColor,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        elevation: 3, // إضافة ارتفاع للزر
      ),
      child: Text(
        "مشاركة الآية",
        style: TextStyle(
          color: AppColors.backgroundColor,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }

  // تعديل دالة _buildLandscapeGrid لاستخدام Wrap
  Widget _buildLandscapeGrid(double screenWidth, double screenHeight) {
    // حساب حجم الأيقونة كنسبة من عرض الشاشة
    bool isWideScreen = screenWidth > 800;
    double iconSizePercentage = isWideScreen ? 0.08 : 0.12;
    double iconSize = screenWidth * iconSizePercentage;

    // استخدام نسب مئوية لحساب المسافات
    double spacing = screenWidth * 0.015;
    double runSpacing = screenHeight * 0.01; // تقليل المسافة بين الصفوف

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center, // توسيط العناصر أفقياً
        spacing: spacing, // المسافة بين العناصر أفقياً
        runSpacing: runSpacing, // المسافة بين الصفوف
        children: _gridItems(iconSize, screenHeight),
      ),
    );
  }

  // تعديل دالة _buildPortraitGrid للعودة إلى استخدام GridView مع تقليل المسافة بين الصفوف
  Widget _buildPortraitGrid(double screenWidth, double screenHeight) {
    // استخدام نسب مئوية لحساب المسافات والأحجام
    double crossAxisSpacing = screenWidth * 0.02;
    double mainAxisSpacing = 0; // إزالة المسافة بين الصفوف تمامًا

    // حساب حجم الأيقونة كنسبة من عرض الشاشة
    double iconSizePercentage = screenWidth > 600 ? 0.15 : 0.2;
    double iconSize = screenWidth * iconSizePercentage;

    // حساب الحد الأقصى لعرض كل عنصر
    // نستخدم قيمة أكبر قليلاً من حجم الأيقونة المعدل لضمان توزيع مناسب
    double maxCrossAxisExtent = iconSize * 1.2 * 2.2;

    // تعديل نسبة العرض إلى الارتفاع بناءً على نسبة الشاشة - زيادة القيمة لتقليل الارتفاع
    double childAspectRatio = screenWidth > 600 ? 1.3 : 1.2;

    return Container(
      width: screenWidth,
      child: GridView.builder(
        physics: NeverScrollableScrollPhysics(), // منع التمرير الداخلي
        shrinkWrap: true, // السماح للشبكة بالتقلص حسب محتواها
        itemCount: _gridItems(iconSize, screenHeight).length,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxCrossAxisExtent,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          childAspectRatio: childAspectRatio,
        ),
        itemBuilder: (context, index) =>
            _gridItems(iconSize, screenHeight)[index],
      ),
    );
  }

  // تعديل دالة _gridItems لتغيير ترتيب أيقونة الترانيم بناءً على اتجاه الشاشة
  List<Widget> _gridItems(double iconSize, double screenHeight) {
    // تحديد ما إذا كان الجهاز في الوضع الأفقي
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // تعديل حجم الخط بناءً على عرض الشاشة بدلاً من حجم الأيقونة
    final screenWidth = MediaQuery.of(context).size.width;
    // تصغير حجم الخط في الوضع الأفقي ليتناسب مع حجم الأيقونة
    final fontSize = isLandscape ? screenWidth * 0.018 : screenWidth * 0.045;

    // إنشاء أيقونة الترانيم
    Widget hymnsItem = _buildGridItem(
      "assets/images/hymnsCropped.png",
      "Hymns",
      HymnsPage(audioService: context.read<HymnsCubit>().audioService),
      iconSize,
      fontSize,
      screenHeight,
    );

    // إنشاء باقي العناصر
    List<Widget> otherItems = [
      _buildGridItem("assets/images/ourDailyBreadCropped.png", "Daily Bread",
          const DailyBread(), iconSize, fontSize, screenHeight),
      _buildGridItem("assets/images/newsCropped.png", "News", const NewsPage(),
          iconSize, fontSize, screenHeight),
      _buildGridItem(
          "assets/images/copticCalendarCropped.png",
          "Coptic Calendar",
          const CopticCalendar(),
          iconSize,
          fontSize,
          screenHeight),
      _buildGridItem("assets/images/aboutUsCropped.png", "About Us",
          const AboutUs(), iconSize, fontSize, screenHeight),
      InkWell(
        onTap: _toggleSocialIcons,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // إضافة إطار شفاف حول الأيقونة
            Container(
              width: iconSize * 1.2 * 1.15,
              height: iconSize * 1.2 * 1.15,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(iconSize * 1.2 * 0.2),
                border: Border.all(
                  color: AppColors.appamber.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Image.asset(
                  "assets/images/ourSocialMediaCropped.png",
                  width: iconSize * 1.2,
                  height: iconSize * 1.2,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(
                height:
                    isLandscape ? screenHeight * 0.008 : screenHeight * 0.015),
            Text("Social Media",
                style: TextStyle(
                    fontSize: fontSize,
                    color: AppColors.appamber,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    ];

    // ترتيب العناصر بناءً على اتجاه الشاشة
    List<Widget> items;
    if (isLandscape) {
      // في الوضع الأفقي: الترانيم في المقدمة (الموضع الأول)
      items = [hymnsItem, ...otherItems];
    } else {
      // في الوضع الرأسي: الترانيم في الموضع الثاني
      items = [otherItems[0], hymnsItem, ...otherItems.sublist(1)];
    }

    // إضافة أيقونات وسائل التواصل الاجتماعي إذا كانت مفعلة
    if (showSocialIcons) {
      items.addAll([
        _buildSocialMediaItem(
            "assets/images/facebookCropped.png",
            "Facebook",
            "https://www.facebook.com/OmElnourChoir",
            iconSize,
            fontSize,
            screenHeight),
        _buildSocialMediaItem(
            "assets/images/youtubeCropped.png",
            "YouTube",
            "https://www.youtube.com/@-omelnourchoir-dokki4265",
            iconSize,
            fontSize,
            screenHeight),
        _buildSocialMediaItem(
            "assets/images/instagramCropped.png",
            "Instagram",
            "https://www.instagram.com/omelnourchoirofficial/#",
            iconSize,
            fontSize,
            screenHeight),
      ]);
    }

    return items;
  }

  // تحسين دالة _buildGridItem لتقبل حجم الأيقونة وحجم الخط وارتفاع الشاشة كمعلمات واستخدام نسب مئوية
  Widget _buildGridItem(String imagePath, String title, Widget screen,
      double iconSize, double fontSize, double screenHeight) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // حساب المسافة بين الصورة والنص كنسبة من ارتفاع الشاشة
    final spacingHeight =
        isLandscape ? screenHeight * 0.008 : screenHeight * 0.015;

    // زيادة حجم الأيقونة بنسبة 20%
    final adjustedIconSize = iconSize * 1.2;

    return InkWell(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (context) => screen)),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: adjustedIconSize * 1.15,
            height: adjustedIconSize * 1.15,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.appamber.withOpacity(0.3),
                width: 1.5,
              ),
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(adjustedIconSize * 0.2),
              // border: Border.all( ... )  // ← احذف أو علّق هذا السطر نهائياً
            ),
            child: Center(
              child: Image.asset(
                imagePath,
                width: adjustedIconSize,
                height: adjustedIconSize,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(height: spacingHeight),
          Text(
            title,
            style: TextStyle(
              fontSize: fontSize,
              color: AppColors.appamber,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // تعديل دالة _buildSocialMediaItem لتقبل حجم الأيقونة وحجم الخط وارتفاع الشاشة كمعلمات
  Widget _buildSocialMediaItem(String imagePath, String title, String url,
      double iconSize, double fontSize, double screenHeight) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // حساب المسافة بين الصورة والنص كنسبة من ارتفاع الشاشة
    final spacingHeight =
        isLandscape ? screenHeight * 0.008 : screenHeight * 0.015;

    // زيادة حجم الأيقونة بنسبة 20%
    final adjustedIconSize = iconSize * 1.2;

    return InkWell(
      onTap: () async {
        if (!_isMounted) return;
        final Uri uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (_isMounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text("❌ لا يمكن فتح الرابط")));
          }
        }
      },
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: adjustedIconSize * 1.15,
            height: adjustedIconSize * 1.15,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.appamber.withOpacity(0.3),
                width: 1.5,
              ),
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(adjustedIconSize * 0.2),
              // border: Border.all( ... )  // ← احذف أو علّق هذا السطر نهائياً
            ),
            child: Center(
              child: Image.asset(
                imagePath,
                width: adjustedIconSize,
                height: adjustedIconSize,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(height: spacingHeight),
          Text(
            title,
            style: TextStyle(
              fontSize: fontSize,
              color: AppColors.appamber,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // تعديل دالة _buildDisabledShareButton لتطابق تصميم زر إضافة الآية
  Widget _buildDisabledShareButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // تعديل حجم خط زر مشاركة الآية المعطل في الوضع الرأسي
    // حساب حجم الخط والهوامش كنسب مئوية - نفس القيم المستخدمة في _buildAddVerseButton
    final fontSize = screenWidth *
        (isLandscape ? 0.018 : 0.03); // زيادة حجم الخط في الوضع الرأسي
    final horizontalPadding = screenWidth * 0.03;
    final verticalPadding = screenHeight * 0.015;
    final borderRadius = screenWidth * 0.015;

    return ElevatedButton(
      onPressed: null, // زر معطل
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.appamber.withOpacity(0.5),
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: Text(
        "مشاركة الآية",
        style: TextStyle(
          color: AppColors.backgroundColor.withOpacity(0.5),
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }

  // دالة التحقق من وجود تحديثات
  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdate || _isNavigating) return;

    if (mounted) {
      setState(() {
        _isCheckingUpdate = true;
      });
    }

    try {
      print('🔄 جاري التحقق من وجود تحديثات...');

      final packageInfo = await PackageInfo.fromPlatform();
      print(
          '📱 إصدار التطبيق الحالي: ${packageInfo.version} (${packageInfo.buildNumber})');

      // التحقق يتم دائمًا في كل البيئات
      if (mounted) {
        if (Platform.isAndroid) {
          await _checkAndroidUpdates();
        } else if (Platform.isIOS) {
          await _checkIOSUpdates(packageInfo.version);
        }
      }
    } catch (e) {
      print('❌ خطأ عام في التحقق من التحديثات: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
          _isUpdateCheckComplete = true;
        });
        // إذا كان لديك منطق انتظار تحميل الموارد أضفه هنا
        // _checkAllResourcesLoaded();
      }
    }
  }

  // دالة التحقق من تحديثات Android
  Future<void> _checkAndroidUpdates() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      print('📊 معلومات تحديث Android:');
      print('- توفر التحديث: ${updateInfo.updateAvailability}');
      print('- الإصدار المتاح: ${updateInfo.availableVersionCode}');

      if (mounted &&
          updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        print('✅ يوجد تحديث متاح لـ Android');
        try {
          await InAppUpdate.startFlexibleUpdate();
          if (mounted) {
            await InAppUpdate.completeFlexibleUpdate();
          }
        } catch (e) {
          print('❌ فشل في بدء التحديث المرن: $e');
          if (mounted) {
            _showAndroidUpdateDialog(immediate: false);
          }
        }
      } else {
        print('✅ تطبيق Android محدث بالفعل');
      }
    } catch (e) {
      print('❌ خطأ في التحقق من تحديثات Android: $e');
      print(
          '⚠️ هذا الخطأ متوقع في بيئة التطوير أو عندما يكون التطبيق غير مثبت من متجر Google Play');
      // اعرض رسالة التحديث دائماً في حالة الخطأ
      if (mounted) {
        _showAndroidUpdateDialog(immediate: false);
      }
    }
  }

  // دالة التحقق من تحديثات iOS
  Future<void> _checkIOSUpdates(String currentVersion) async {
    try {
      final response = await http.get(
        Uri.parse('https://itunes.apple.com/lookup?id=$_appStoreId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['resultCount'] > 0) {
          final storeVersion = data['results'][0]['version'];
          print('📊 معلومات تحديث iOS:');
          print('- الإصدار الحالي: $currentVersion');
          print('- الإصدار المتاح في App Store: $storeVersion');

          if (_isNewerVersion(storeVersion, currentVersion)) {
            print('✅ يوجد تحديث متاح لـ iOS');
            if (mounted) {
              _showIOSUpdateDialog();
            }
          } else {
            print('✅ تطبيق iOS محدث بالفعل');
          }
        }
      } else {
        print('❌ فشل في الاتصال بـ iTunes API: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ خطأ في التحقق من تحديثات iOS: $e');
      if (_isTestingMode && mounted) {
        _showIOSUpdateDialog();
      }
    }
  }

  // مقارنة الإصدارات لمعرفة ما إذا كان الإصدار الجديد أحدث
  bool _isNewerVersion(String storeVersion, String currentVersion) {
    List<int> storeVersionParts =
        storeVersion.split('.').map((part) => int.tryParse(part) ?? 0).toList();

    List<int> currentVersionParts = currentVersion
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();

    while (storeVersionParts.length < currentVersionParts.length) {
      storeVersionParts.add(0);
    }
    while (currentVersionParts.length < storeVersionParts.length) {
      currentVersionParts.add(0);
    }

    for (int i = 0; i < storeVersionParts.length; i++) {
      if (storeVersionParts[i] > currentVersionParts[i]) {
        return true;
      } else if (storeVersionParts[i] < currentVersionParts[i]) {
        return false;
      }
    }

    return false;
  }

  // عرض مربع حوار تحديث Android
  void _showAndroidUpdateDialog({required bool immediate}) {
    if (!mounted || _isNavigating || _isUpdateDialogOpen) return;

    _isUpdateDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: !immediate,
      builder: (context) => WillPopScope(
        onWillPop: () async => !immediate,
        child: AlertDialog(
          title: Row(
            children: [
              Image.asset('assets/images/logo.png', width: 40, height: 40),
              const SizedBox(width: 10),
              const Text('تحديث متاح'),
            ],
          ),
          content: const Text(
            'يوجد تحديث جديد للتطبيق. هل ترغب في تحديث التطبيق الآن؟',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            if (!immediate)
              TextButton(
                onPressed: () {
                  _isUpdateDialogOpen = false;
                  Navigator.pop(context);
                },
                child: const Text('لاحقًا'),
              ),
            ElevatedButton(
              onPressed: () {
                _isUpdateDialogOpen = false;
                Navigator.pop(context);
                _openGooglePlayStore();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.appamber,
                foregroundColor: Colors.black,
              ),
              child: const Text('تحديث الآن'),
            ),
          ],
        ),
      ),
    ).then((_) {
      _isUpdateDialogOpen = false;
    });
  }

  // عرض مربع حوار تحديث iOS
  void _showIOSUpdateDialog() {
    if (!mounted || _isNavigating) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => WillPopScope(
        onWillPop: () async => true,
        child: AlertDialog(
          title: Row(
            children: [
              Image.asset('assets/images/logo.png', width: 40, height: 40),
              const SizedBox(width: 10),
              const Text('تحديث جديد متاح'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'يوجد إصدار جديد من التطبيق. يرجى تحديث التطبيق للاستمتاع بأحدث الميزات وإصلاحات الأخطاء.',
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[200],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.app_shortcut, size: 50, color: Colors.blue),
                      const SizedBox(height: 10),
                      const Text(
                        'تحديث App Store',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لاحقًا'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _openAppStore();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('تحديث الآن'),
            ),
          ],
        ),
      ),
    );
  }

  // فتح متجر Google Play
  Future<void> _openGooglePlayStore() async {
    if (!mounted || _isNavigating) return;

    try {
      final url = 'market://details?id=$_packageName';
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        await launch(
            'https://play.google.com/store/apps/details?id=$_packageName');
      }
    } catch (e) {
      print('❌ فشل في فتح متجر Google Play: $e');
    }
  }

  // فتح متجر App Store
  Future<void> _openAppStore() async {
    if (!mounted || _isNavigating) return;

    try {
      final url = 'https://apps.apple.com/app/id$_appStoreId';
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        await launch('https://apps.apple.com/app/id$_appStoreId');
      }
    } catch (e) {
      print('❌ فشل في فتح متجر App Store: $e');
    }
  }

  Future<void> maybeShowBatteryDialog(BuildContext context) async {
    if (!Platform.isAndroid || _batteryDialogShown) return;
    _batteryDialogShown = true;
    if (!mounted) return;

    final isIgnoring = await isIgnoringBatteryOptimizations();
    if (!isIgnoring) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('تحسين البطارية مفعل'),
          content: Text(
              'قد يؤثر تحسين البطارية على تشغيل الترانيم في الخلفية أو التشغيل التلقائي. يُفضل استثناء التطبيق من تحسين البطارية.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('لاحقًا'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                openBatteryOptimizationSettings();
              },
              child: Text('فتح الإعدادات'),
            ),
          ],
        ),
      );
    }
  }

  void openBatteryOptimizationSettings() async {
    if (Platform.isAndroid) {
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:${await _getPackageName()}',
      );
      await intent.launch();
    }
  }

// أضف هذه الدالة المساعدة لجلب اسم الباكدج
  Future<String> _getPackageName() async {
    final info = await PackageInfo.fromPlatform();
    return info.packageName;
  }
}
