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
import 'package:om_elnour_choir/services/app_open_ad_service.dart';

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

  // إضافة متغيرات لإعلان الفتح
  bool _isAdShown = false;

  // إضافة متغير لتتبع ما إذا كان Widget لا يزال موجودًا
  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();

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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Om Elnour Choir',
              style: TextStyle(color: AppColors.appamber)),
          centerTitle: false,
          actions: [
            // إضافة زر الإشعارات مع عداد الإشعارات غير المقروءة
            Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications, color: AppColors.appamber),
                  onPressed: _navigateToNotifications,
                ),
                if (_unreadNotificationsCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadNotificationsCount > 9
                            ? '9+'
                            : _unreadNotificationsCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            // دمج أيقونة الشخص واسم المستخدم في عنصر واحد قابل للنقر
            FutureBuilder<String?>(
              future: _userNameFuture,
              builder: (context, snapshot) {
                return InkWell(
                  onTap: _navigateToProfile,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    margin: EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppColors.appamber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.appamber.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, color: AppColors.appamber, size: 20),
                        SizedBox(width: 6),
                        Text(
                          snapshot.data ?? "My Profile",
                          style: TextStyle(
                            color: AppColors.appamber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        // استخدام Stack لوضع الإعلان في الأسفل
        body: Stack(
          children: [
            // المحتوى الرئيسي مع هامش سفلي لتجنب تداخله مع الإعلان
            Positioned.fill(
              bottom: MediaQuery.of(context).size.height *
                  0.08, // استخدام نسبة من ارتفاع الشاشة
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * (isLandscape ? 0.02 : 0.03),
                      vertical: screenHeight * (isLandscape ? 0.01 : 0.015)),
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
            ),

            // الإعلان في الأسفل
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.of(context).size.height *
                  0.08, // استخدام نسبة من ارتفاع الشاشة
              child: AdBanner(
                key: ValueKey('home_screen_ad_banner'),
                cacheKey: 'home_screen',
              ),
            ),
          ],
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
              color: AppColors.appamber.withOpacity(0.1),
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
                  color: AppColors.appamber.withOpacity(0.1),
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
              color: AppColors.appamber.withOpacity(0.1),
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

  // تعديل دالة _gridItems لتقبل حجم الأيقونة وارتفاع الشاشة كمعلمات
  List<Widget> _gridItems(double iconSize, double screenHeight) {
    // تحديد ما إذا كان الجهاز في الوضع الأفقي
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // تعديل حجم الخط بناءً على عرض الشاشة بدلاً من حجم الأيقونة
    final screenWidth = MediaQuery.of(context).size.width;
    // تصغير حجم الخط في الوضع الأفقي ليتناسب مع حجم الأيقونة
    final fontSize = isLandscape ? screenWidth * 0.018 : screenWidth * 0.045;

    List<Widget> items = [
      _buildGridItem("assets/images/ourDailyBreadCropped.png", "Daily Bread",
          const DailyBread(), iconSize, fontSize, screenHeight),
      _buildGridItem(
        "assets/images/hymnsCropped.png",
        "Hymns",
        HymnsPage(audioService: context.read<HymnsCubit>().audioService),
        iconSize,
        fontSize,
        screenHeight,
      ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // إضافة إطار شفاف حول الأيقونة
            Container(
              width: iconSize * 1.2 * 1.15,
              height: iconSize * 1.2 * 1.15,
              decoration: BoxDecoration(
                color: AppColors.appamber.withOpacity(0.1),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // إضافة إطار شفاف حول الأيقونة
          Container(
            width: adjustedIconSize * 1.15,
            height: adjustedIconSize * 1.15,
            decoration: BoxDecoration(
              color: AppColors.appamber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(adjustedIconSize * 0.2),
              border: Border.all(
                color: AppColors.appamber.withOpacity(0.3),
                width: 1.5,
              ),
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
        if (!_isMounted) return; // التحقق من أن الـ widget لا يزال موجودًا

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // إضافة إطار شفاف حول الأيقونة
          Container(
            width: adjustedIconSize * 1.15,
            height: adjustedIconSize * 1.15,
            decoration: BoxDecoration(
              color: AppColors.appamber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(adjustedIconSize * 0.2),
              border: Border.all(
                color: AppColors.appamber.withOpacity(0.3),
                width: 1.5,
              ),
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
}
