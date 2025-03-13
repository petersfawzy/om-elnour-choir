import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_states.dart';
import 'package:om_elnour_choir/app_setting/views/Hymns.dart';
import 'package:om_elnour_choir/app_setting/views/about_us.dart';
import 'package:om_elnour_choir/app_setting/views/add_verce.dart';
import 'package:om_elnour_choir/app_setting/views/coptic_calendar.dart';
import 'package:om_elnour_choir/app_setting/views/daily_bread.dart';
import 'package:om_elnour_choir/app_setting/views/news.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/user/views/profile_screen.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? userName;

  @override
  void initState() {
    super.initState();
    context.read<VerceCubit>().fetchVerse();
    _getUserName();
  }

  Future<void> _getUserName() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String? name = user.displayName;
        if (name == null || name.isEmpty) {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('userData')
              .doc(user.uid)
              .get();
          if (userDoc.exists && userDoc.data() != null) {
            final userData = userDoc.data() as Map<String, dynamic>;
            name = userData['name'] ?? "My Profile";
          }
        }
        setState(() {
          userName = name;
        });
      }
    } catch (e) {
      print("Error fetching user name: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isWideScreen =
        screenWidth > 800; // لو الشاشة واسعة جدًا، نستخدم Wrap بدل GridView

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title:
            Text('Om Elnour Choir', style: TextStyle(color: Colors.amber[200])),
        actions: [
          Row(
            children: [
              Icon(Icons.person, color: Colors.amber[200]),
              TextButton(
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (context) => ProfileScreen()),
                  );
                },
                child: Text(
                  userName ?? "My Profile",
                  style: TextStyle(color: Colors.amber[200]),
                ),
              ),
            ],
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05, vertical: 10),
            child: Column(
              children: [
                _buildVerseContainer(),
                const SizedBox(height: 10),
                _buildAddVerseButton(),
                const SizedBox(height: 20),
                Expanded(
                  child: isWideScreen
                      ? _buildWrapItems() // للأجهزة العريضة نستخدم Wrap
                      : _buildGridItems(
                          constraints), // للأجهزة العادية نستخدم GridView
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const AdBanner(),
    );
  }

  Widget _buildVerseContainer() {
    return BlocBuilder<VerceCubit, VerceState>(
      builder: (context, state) {
        if (state is VerceLoading) {
          return Center(child: CircularProgressIndicator());
        } else if (state is VerceLoaded) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.amber[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              state.verse,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.backgroundColor),
              textAlign: TextAlign.center,
            ),
          );
        } else {
          return Center(child: Text("No verse available"));
        }
      },
    );
  }

  Widget _buildAddVerseButton() {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddVerce()),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber[200],
        foregroundColor: Colors.black,
      ),
      child: Text(
        "Add Verse",
        style: TextStyle(color: AppColors.backgroundColor),
      ),
    );
  }

  Widget _buildGridItems(BoxConstraints constraints) {
    int crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
    double childAspectRatio = constraints.maxWidth > 600 ? 1.6 : 1.2;

    return GridView.builder(
      itemCount: _gridItems.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        return _buildGridItem(
          _gridItems[index]['imagePath']!,
          _gridItems[index]['title']!,
          _gridItems[index]['screen']!,
        );
      },
    );
  }

  Widget _buildWrapItems() {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        alignment: WrapAlignment.center,
        children: _gridItems
            .map((item) => _buildGridItem(
                  item['imagePath']!,
                  item['title']!,
                  item['screen']!,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildGridItem(String imagePath, String title, Widget screen) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(imagePath, width: 100, height: 100, fit: BoxFit.cover),
          SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              color: Colors.amber[200],
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  final List<Map<String, dynamic>> _gridItems = [
    {
      "imagePath": "assets/images/ourDailyBreadCropped.png",
      "title": "Daily Bread",
      "screen": DailyBread()
    },
    {
      "imagePath": "assets/images/hymnsCropped.png",
      "title": "Hymns",
      "screen": HymnsPage()
    },
    {
      "imagePath": "assets/images/newsCropped.png",
      "title": "News",
      "screen": News()
    },
    {
      "imagePath": "assets/images/copticCalendarCropped.png",
      "title": "Coptic Calendar",
      "screen": CopticCalendar()
    },
    {
      "imagePath": "assets/images/ourSocialMediaCropped.png",
      "title": "Social Media",
      "screen": ProfileScreen()
    },
    {
      "imagePath": "assets/images/aboutUsCropped.png",
      "title": "About Us",
      "screen": AboutUs()
    },
  ];
}
