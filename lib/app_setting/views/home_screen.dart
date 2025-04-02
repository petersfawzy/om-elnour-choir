import 'package:flutter/material.dart';
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
import 'package:om_elnour_choir/user/views/profile_screen.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<String?> _userNameFuture;
  bool showSocialIcons = false;

  @override
  void initState() {
    super.initState();
    context.read<VerceCubit>().fetchVerse();
    _userNameFuture = _getUserName();
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

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isWideScreen = screenWidth > 800;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
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
        padding:
            EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: 10),
        child: Column(
          children: [
            _buildVerseContainer(),
            const SizedBox(height: 10),
            _buildAddVerseButton(),
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
      bottomNavigationBar: const AdBanner(),
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
