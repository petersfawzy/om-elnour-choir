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
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/scaffold_with_background.dart';
import 'package:om_elnour_choir/user/views/profile_screen.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:om_elnour_choir/services/remote_config_service.dart';
import 'dart:io';

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

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    context.read<VerceCubit>().fetchVerse();
    _userNameFuture = _getUserName();

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
      // عند استئناف التطبيق، تحقق مما إذا كان يجب تحديث الآية
      context.read<VerceCubit>().checkForVerseUpdate();
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
    setState(() {
      showSocialIcons = !showSocialIcons;
    });
  }

  // دالة للتعامل مع ضغطة زر الرجوع
  Future<bool> _onWillPop() async {
    try {
      // استخدام قناة المنصة لتصغير التطبيق
      if (Platform.isAndroid) {
        // على Android، استخدم قناة المنصة لاستدعاء moveTaskToBack
        const platform = MethodChannel('com.egypt.redcherry.omelnourchoir/app');
        await platform.invokeMethod('moveTaskToBack');

        // إظهار رسالة للمستخدم
        if (mounted) {
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
        if (mounted) {
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
    try {
      await _remoteConfigService.refresh();
      AppColors.updateFromRemoteConfig();
      // إعادة بناء الواجهة لتطبيق الألوان الجديدة
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الألوان بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحديث الألوان: $e')),
      );
    }
  }

  // دالة للتحقق من الألوان الحالية (للتصحيح)
  void _debugColors() {
    AppColors.debugColors();

    // عرض رسالة للمستخدم
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم طباعة معلومات الألوان في سجل التصحيح'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // أضف هذه الدالة في فئة _HomeScreenState
  void _showAllConfigValues() {
    final configValues = _remoteConfigService.getAllConfigValues();

    // طباعة جميع القيم في سجل التصحيح
    print('📊 جميع قيم التكوين:');
    configValues.forEach((key, value) {
      print('$key: $value');
    });

    // عرض رسالة للمستخدم
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم طباعة جميع قيم التكوين في سجل التصحيح'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // أضف هذه الدالة في فئة _HomeScreenState
  Future<void> _resetAndRefreshConfig() async {
    try {
      // عرض مؤشر التقدم
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // إعادة تهيئة Remote Config
      await _remoteConfigService.initialize();

      // تحديث الألوان
      AppColors.updateFromRemoteConfig();

      // إغلاق مؤشر التقدم
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // إعادة بناء الواجهة
      setState(() {});

      // عرض رسالة للمستخدم
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إعادة تهيئة التكوين وتحديث الألوان'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // إغلاق مؤشر التقدم في حالة الخطأ
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // عرض رسالة الخطأ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إعادة تهيئة التكوين: $e'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
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
                    Icon(Icons.person, color: AppColors.appamber),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) => const ProfileScreen()),
                      ),
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
        body: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05, vertical: 10),
          child: Column(
            children: [
              _buildVerseContainer(),
              const SizedBox(height: 10),
              if (isAdmin) _buildAddVerseButton(),
              const SizedBox(height: 20),
              Expanded(
                child: isWideScreen
                    ? Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        alignment: WrapAlignment.center,
                        children: _gridItems(),
                      )
                    : GridView.count(
                        crossAxisCount: screenWidth > 600 ? 3 : 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: screenWidth > 600 ? 1.6 : 1.2,
                        children: _gridItems(),
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar:
            AdBanner(key: UniqueKey(), cacheKey: 'home_screen'),
      ),
    );
  }

  Widget _buildVerseContainer() {
    return BlocBuilder<VerceCubit, VerceState>(
      builder: (context, state) {
        if (state is VerceLoading) {
          return Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.appamber.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.backgroundColor)),
          );
        } else if (state is VerceLoaded) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.appamber,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              state.verse,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.backgroundColor,
              ),
              textAlign: TextAlign.center,
            ),
          );
        } else {
          return Center(child: Text("❌ لا توجد آية متاحة"));
        }
      },
    );
  }

  Widget _buildAddVerseButton() {
    return ElevatedButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddVerce()),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.appamber,
        foregroundColor: Colors.black,
      ),
      child: Text(
        "Add Verse",
        style: TextStyle(color: AppColors.backgroundColor),
      ),
    );
  }

  List<Widget> _gridItems() {
    List<Widget> items = [
      _buildGridItem("assets/images/ourDailyBreadCropped.png", "Daily Bread",
          const DailyBread()),
      _buildGridItem(
        "assets/images/hymnsCropped.png",
        "Hymns",
        HymnsPage(audioService: context.read<HymnsCubit>().audioService),
      ),
      _buildGridItem("assets/images/newsCropped.png", "News", const NewsPage()),
      _buildGridItem("assets/images/copticCalendarCropped.png",
          "Coptic Calendar", const CopticCalendar()),
      _buildGridItem(
          "assets/images/aboutUsCropped.png", "About Us", const AboutUs()),
      InkWell(
        onTap: _toggleSocialIcons,
        child: Column(
          children: [
            Image.asset("assets/images/ourSocialMediaCropped.png",
                width: 100, height: 100, fit: BoxFit.cover),
            const SizedBox(height: 5),
            Text("Social Media",
                style: TextStyle(fontSize: 15, color: AppColors.appamber)),
          ],
        ),
      ),
    ];

    if (showSocialIcons) {
      items.addAll([
        _buildSocialMediaItem("assets/images/facebookCropped.png", "Facebook",
            "https://www.facebook.com/OmElnourChoir"),
        _buildSocialMediaItem("assets/images/youtubeCropped.png", "YouTube",
            "https://www.youtube.com/@-omelnourchoir-dokki4265"),
        _buildSocialMediaItem("assets/images/instagramCropped.png", "Instagram",
            "https://www.instagram.com/omelnourchoirofficial/#"),
      ]);
    }

    return items;
  }

  Widget _buildGridItem(String imagePath, String title, Widget screen) {
    return InkWell(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (context) => screen)),
      child: Column(
        children: [
          Image.asset(imagePath, width: 100, height: 100, fit: BoxFit.cover),
          const SizedBox(height: 5),
          Text(title,
              style: TextStyle(fontSize: 15, color: AppColors.appamber)),
        ],
      ),
    );
  }

  Widget _buildSocialMediaItem(String imagePath, String title, String url) {
    return InkWell(
      onTap: () async {
        final Uri uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("❌ لا يمكن فتح الرابط")));
        }
      },
      child: Column(
        children: [
          Image.asset(imagePath, width: 100, height: 100, fit: BoxFit.cover),
          const SizedBox(height: 5),
          Text(title,
              style: TextStyle(fontSize: 15, color: AppColors.appamber)),
        ],
      ),
    );
  }
}
