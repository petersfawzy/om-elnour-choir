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
import 'package:om_elnour_choir/main.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/scaffold_with_background.dart';
import 'package:om_elnour_choir/user/views/profile_screen.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:om_elnour_choir/services/remote_config_service.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:om_elnour_choir/services/app_open_ad_service.dart'; // إضافة استيراد خدمة إعلان الفتح

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

  // إضافة متغيرات لإعلان الفتح
  late AppOpenAdService _appOpenAdService;
  bool _isAdShown = false;

  // إضافة متغير لتتبع ما إذا كان Widget لا يزال موجودًا
  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    context.read<VerceCubit>().fetchVerse();
    _userNameFuture = _getUserName();

    // إضافة مراقب دورة حياة التطبيق
    WidgetsBinding.instance.addObserver(this);

    // الوصول إلى خدمة إعلان الفتح
    _appOpenAdService =
        appOpenAdService; // افترض أن appOpenAdService هو متغير عام

    // عرض إعلان الفتح بعد بناء الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOpenAd();
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

  // دالة جديدة لعرض إعلان الفتح
  Future<void> _showOpenAd() async {
    if (_isAdShown || !_isMounted)
      return; // تجنب عرض الإعلان مرتين أو بعد التخلص من الـ widget

    try {
      print('🔄 محاولة عرض إعلان الفتح في HomeScreen...');
      bool adShown = await _appOpenAdService.showAdIfFirstOpen();

      if (_isMounted) {
        setState(() {
          _isAdShown = adShown;
        });
      }

      print('📊 نتيجة عرض الإعلان: ${adShown ? 'تم العرض' : 'لم يتم العرض'}');

      // إذا لم يتم عرض الإعلان، حاول مرة أخرى بعد تأخير قصير
      if (!adShown && _isMounted) {
        await Future.delayed(Duration(seconds: 1));
        await _appOpenAdService.loadAd(); // تحميل الإعلان مرة أخرى

        if (_isMounted) {
          await Future.delayed(Duration(seconds: 1));
          bool secondAttempt = await _appOpenAdService.showAdIfFirstOpen();
          print(
              '📊 نتيجة المحاولة الثانية: ${secondAttempt ? 'تم العرض' : 'لم يتم العرض'}');
        }
      }
    } catch (e) {
      print('❌ خطأ في عرض إعلان الفتح: $e');
    }
  }

  // تنفيذ دالة didChangeAppLifecycleState لمراقبة حالة التطبيق
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isMounted) return; // التحقق من أن الـ widget لا يزال موجودًا

    if (state == AppLifecycleState.resumed) {
      // عند استئناف التطبيق، تحقق مما إذا كان يجب تحديث الآية
      context.read<VerceCubit>().checkForVerseUpdate();

      // لا نعرض الإعلان عند العودة من الخلفية، فقط نقوم بتحميله
      Future.delayed(Duration(seconds: 3), () {
        if (_isMounted) {
          _appOpenAdService.loadAd();
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

  // تعديل دالة _shareVerse لاستخدام نص ورابط من Remote Config
  Future<void> _shareVerse(String verse) async {
    if (!_isMounted) return; // التحقق من أن الـ widget لا يزال موجودًا

    try {
      // الحصول على رابط التطبيق ونص المشاركة من Remote Config
      final String appLink = _remoteConfigService.getShareAppLink();
      final String shareText = _remoteConfigService.getShareVerseText();

      // تنسيق النص بشكل أفضل مع إضافة مسافات وفواصل إضافية
      final String textToShare = "$verse\n\n\n$shareText\n$appLink";

      // استخدام خيارات إضافية للمشاركة
      await Share.share(
        textToShare,
        subject: 'آية من تطبيق كورال أم النور',
        // إضافة خيارات للمشاركة
        sharePositionOrigin: Rect.fromLTWH(
            0,
            0,
            MediaQuery.of(context).size.width,
            MediaQuery.of(context).size.height / 2),
      );

      print('✅ تم فتح نافذة المشاركة بنجاح');
    } catch (e) {
      print('❌ خطأ في المشاركة: $e');

      // في حالة حدوث خطأ، نسخ النص إلى الحافظة كحل بديل
      final String appLink = _remoteConfigService.getShareAppLink();
      final String shareText = _remoteConfigService.getShareVerseText();
      final String textToShare = "$verse\n\n\n$shareText\n$appLink";
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
            FutureBuilder<String?>(
              future: _userNameFuture,
              builder: (context, snapshot) {
                return Row(
                  children: [
                    // جعل الأيقونة قابلة للنقر أيضًا
                    InkWell(
                      onTap: _navigateToProfile,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.person, color: AppColors.appamber),
                      ),
                    ),
                    TextButton(
                      onPressed: _navigateToProfile,
                      child: Text(
                        snapshot.data ?? "My Profile",
                        style: TextStyle(color: AppColors.appamber),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        // استخدام SingleChildScrollView للسماح بالتمرير عند الحاجة
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 16 : 12,
                vertical: isLandscape ? 8 : 10),
            child: Column(
              children: [
                // مربع الآية - بدون ارتفاع ثابت
                _buildVerseContainer(),

                // مسافة بين الآية والأزرار
                SizedBox(height: isLandscape ? 16 : 20),

                // الأزرار
                BlocBuilder<VerceCubit, VerceState>(
                  builder: (context, state) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isAdmin) _buildAddVerseButton(),
                        if (isAdmin && state is VerceLoaded)
                          SizedBox(width: 12), // زيادة المسافة بين الزرين
                        if (state is VerceLoaded)
                          _buildShareVerseButton(state.verse),
                      ],
                    );
                  },
                ),

                // مسافة بين الأزرار والشبكة
                SizedBox(height: isLandscape ? 20 : 24),

                // الشبكة
                isLandscape
                    ? _buildLandscapeGrid(screenWidth, screenHeight)
                    : _buildPortraitGrid(screenWidth, screenHeight),
              ],
            ),
          ),
        ),
        bottomNavigationBar:
            AdBanner(key: UniqueKey(), cacheKey: 'home_screen'),
      ),
    );
  }

  // تعديل دالة _buildVerseContainer لتتكيف مع حجم المحتوى
  Widget _buildVerseContainer() {
    return BlocBuilder<VerceCubit, VerceState>(
      builder: (context, state) {
        // حساب حجم الخط المتغير بناءً على حجم الشاشة
        final screenWidth = MediaQuery.of(context).size.width;
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;

        // زيادة حجم الخط في الوضع الرأسي
        final fontSizeMultiplier = isLandscape ? 0.035 : 0.045;
        final fontSize = screenWidth * fontSizeMultiplier;

        // تحسين الهوامش والحشو
        final padding = isLandscape ? 12.0 : 16.0;

        if (state is VerceLoading) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.appamber.withOpacity(0.7),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.appamber.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.appamber),
                ),
              ),
            ),
          );
        } else if (state is VerceLoaded) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.appamber,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.appamber.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
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
          );
        } else {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.appamber.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.appamber.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
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
    return ElevatedButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddVerce()),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.appamber,
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        "Add Verse",
        style: TextStyle(
          color: AppColors.backgroundColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // تحسين مظهر زر مشاركة الآية
  Widget _buildShareVerseButton(String verse) {
    return ElevatedButton.icon(
      icon: Icon(
        Icons.share,
        color: AppColors.backgroundColor,
      ),
      label: Text(
        "مشاركة الآية",
        style: TextStyle(
          color: AppColors.backgroundColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.appamber,
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: () => _shareVerse(verse),
    );
  }

  // تعديل دالة _buildLandscapeGrid لتحسين توزيع العناصر في الوضع الأفقي
  Widget _buildLandscapeGrid(double screenWidth, double screenHeight) {
    // حساب عدد الأعمدة بناءً على عرض الشاشة
    int columnCount = screenWidth > 1200 ? 5 : (screenWidth > 900 ? 4 : 3);

    // حساب حجم الأيقونة بناءً على عرض الشاشة
    double iconSize = (screenWidth * 0.7) / (columnCount * 1.5);

    // تعديل نسبة العرض إلى ال��رتفاع لتناسب المساحة المتاحة
    double aspectRatio = 1.5;

    return GridView.count(
      physics: NeverScrollableScrollPhysics(), // منع التمرير الداخلي
      shrinkWrap: true, // السماح للشبكة بالتقلص حسب محتواها
      crossAxisCount: columnCount,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: aspectRatio,
      children: _gridItems(iconSize),
    );
  }

  // تعديل دالة _buildPortraitGrid لتحسين توزيع العناصر في الوضع الرأسي
  Widget _buildPortraitGrid(double screenWidth, double screenHeight) {
    // حساب عدد الأعمدة بناءً على عرض الشاشة
    int columnCount = screenWidth > 600 ? 3 : 2;

    // حساب حجم الأيقونة بناءً على عرض الشاشة
    double iconSize = (screenWidth * 0.85) / (columnCount * 1.5);

    // تعديل نسبة العرض إلى الارتفاع لتناسب المساحة المتاحة
    double aspectRatio = screenWidth > 600 ? 1.2 : 1.1;

    return GridView.count(
      physics: NeverScrollableScrollPhysics(), // منع التمرير الداخلي
      shrinkWrap: true, // السماح للشبكة بالتقلص حسب محتواها
      crossAxisCount: columnCount,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: aspectRatio,
      children: _gridItems(iconSize),
    );
  }

  // تعديل دالة _gridItems لتقبل حجم الأيقونة كمعلمة
  List<Widget> _gridItems(double iconSize) {
    // تحديد ما إذا كان الجهاز في الوضع الأفقي
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // تعديل حجم الخط بناءً على عرض الشاشة بدلاً من حجم الأيقونة
    final screenWidth = MediaQuery.of(context).size.width;
    // زيادة حجم الخط ليتناسب مع حجم خط الآية - استخدام معاملات أكبر
    final fontSize = isLandscape ? screenWidth * 0.035 : screenWidth * 0.045;

    List<Widget> items = [
      _buildGridItem("assets/images/ourDailyBreadCropped.png", "Daily Bread",
          const DailyBread(), iconSize, fontSize),
      _buildGridItem(
        "assets/images/hymnsCropped.png",
        "Hymns",
        HymnsPage(audioService: context.read<HymnsCubit>().audioService),
        iconSize,
        fontSize,
      ),
      _buildGridItem("assets/images/newsCropped.png", "News", const NewsPage(),
          iconSize, fontSize),
      _buildGridItem("assets/images/copticCalendarCropped.png",
          "Coptic Calendar", const CopticCalendar(), iconSize, fontSize),
      _buildGridItem("assets/images/aboutUsCropped.png", "About Us",
          const AboutUs(), iconSize, fontSize),
      InkWell(
        onTap: _toggleSocialIcons,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset("assets/images/ourSocialMediaCropped.png",
                width: iconSize, height: iconSize, fit: BoxFit.cover),
            SizedBox(height: isLandscape ? 5 : 8),
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
        _buildSocialMediaItem("assets/images/facebookCropped.png", "Facebook",
            "https://www.facebook.com/OmElnourChoir", iconSize, fontSize),
        _buildSocialMediaItem(
            "assets/images/youtubeCropped.png",
            "YouTube",
            "https://www.youtube.com/@-omelnourchoir-dokki4265",
            iconSize,
            fontSize),
        _buildSocialMediaItem(
            "assets/images/instagramCropped.png",
            "Instagram",
            "https://www.instagram.com/omelnourchoirofficial/#",
            iconSize,
            fontSize),
      ]);
    }

    return items;
  }

  // تحسين دالة _buildGridItem لتقبل حجم الأيقونة وحجم الخط كمعلمات
  Widget _buildGridItem(String imagePath, String title, Widget screen,
      double iconSize, double fontSize) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return InkWell(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (context) => screen)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            imagePath,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.cover,
          ),
          SizedBox(height: isLandscape ? 5 : 8),
          Text(
            title,
            style: TextStyle(
              fontSize: fontSize,
              color: AppColors.appamber,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // تحسين دالة _buildSocialMediaItem لتقبل حجم الأيقونة وحجم الخط كمعلمات
  Widget _buildSocialMediaItem(String imagePath, String title, String url,
      double iconSize, double fontSize) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

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
          Image.asset(
            imagePath,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.cover,
          ),
          SizedBox(height: isLandscape ? 5 : 8),
          Text(
            title,
            style: TextStyle(
              fontSize: fontSize,
              color: AppColors.appamber,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
