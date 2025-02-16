import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/verce_states.dart';
import 'package:om_elnour_choir/app_setting/views/about_us.dart';
import 'package:om_elnour_choir/app_setting/views/add_verce.dart';
import 'package:om_elnour_choir/app_setting/views/coptic_calendar.dart';
import 'package:om_elnour_choir/app_setting/views/daily_bread.dart';
import 'package:om_elnour_choir/app_setting/views/hymns.dart';
import 'package:om_elnour_choir/app_setting/views/news.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/user/views/profile_screen.dart';

const double icoSize = 80, spacing = 0.25;
bool showSocialMedia = false;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title:
            Text('Om Elnour Choir', style: TextStyle(color: Colors.amber[200])),
        centerTitle: false,
        actions: [
          Row(
            children: [
              Icon(
                Icons.person,
                color: Colors.amber[200],
              ),
              TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProfileScreen()),
                    );
                  },
                  child: Text(
                    'My profile  ',
                    style: TextStyle(color: Colors.amber[200]),
                  )),
            ],
          )
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.amber[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: BlocBuilder<VerceCubit, VerceStates>(
                builder: (context, state) {
                  String displayedVerse =
                      "لا توجد آية جديده حالياً"; // الافتراضي لو مفيش آية

                  if (state is VerceLoaded) {
                    displayedVerse = state.verse;
                  }

                  return Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      displayedVerse,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.backgroundColor,
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 5),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => AddVerce()));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  )),
              child: Text('Add Verse'),
            ),
            SizedBox(height: 20),
            Expanded(
                child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 1,
              mainAxisSpacing: 1,
              children: [
                _buildGrideitem(
                    "assets/images/ourDailyBreadCropped.png",
                    "Daily Bread",
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (context) => DailyBread()))),
                _buildGrideitem(
                    "assets/images/hymnsCropped.png",
                    "hymns",
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (context) => Hymns()))),
                _buildGrideitem(
                    "assets/images/newsCropped.png",
                    "News",
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (context) => News()))),
                _buildGrideitem(
                    "assets/images/copticCalendarCropped.png",
                    "Coptic Calendar",
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => CopticCalendar()))),
                _buildGrideitem(
                    "assets/images/ourSocialMediaCropped.png",
                    "Social Media",
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ProfileScreen()))),
                _buildGrideitem(
                    "assets/images/aboutUsCropped.png",
                    "About Us",
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (context) => AboutUs()))),
              ],
            ))
          ],
        ),
      ),
    );
  }

  Widget _buildGrideitem(String imagePath, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, width: 130, height: 130),
            SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.amber[200],
                  fontWeight: FontWeight.bold),
            )
          ],
        ),
      ),
    );
  }
}
