import 'package:flutter/material.dart';
import 'package:om_elnour_choir/user/views/login_screen.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration(seconds: 4), () {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => Login()));
    });
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 150,
              width: 150,
              margin: const EdgeInsets.all(10.0),
              decoration: const BoxDecoration(
                image: DecorationImage(
                    image: AssetImage("assets/images/logo.png")),
              ),
            ),
            // Image(image: NetworkImage('https://scontent.fcai16-1.fna.fbcdn.net/v/t39.30808-6/317447083_104679542484214_1593274143128685249_n.jpg?_nc_cat=101&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=JS0Q59ySFYgQ7kNvgHTeDKd&_nc_zt=23&_nc_ht=scontent.fcai16-1.fna&_nc_gid=AQ9o2WB1f7oyN19TbLaWE4S&oh=00_AYB61wF66dfzEGxQ5AHkibdqhafkB149wWET1nyQglYeyg&oe=679C12EE'),fit: BoxFit.contain),
            Text('WELCOME TO',
                style: TextStyle(color: Colors.amberAccent, fontSize: 18)),
            Text('OM ELNOUR CHOIR',
                style: TextStyle(color: Colors.amberAccent, fontSize: 18)),
            Text(''),
            Text(
                'مُكَلِّمِينَ بَعْضُكُمْ بَعْضًا بِمَزَامِيرَ وَتَسَابِيحَ وَأَغَانِيَّ رُوحِيَّةٍ،',
                style: TextStyle(color: Colors.amberAccent, fontSize: 15)),
            Text(
                'مُتَرَنِّمِينَ وَمُرَتِّلِينَ فِي قُلُوبِكُمْ لِلرَّبِّ." (أف ٥: ١٩).',
                style: TextStyle(color: Colors.amberAccent, fontSize: 15)),
            // Ink.image(image: NetworkImage('https://scontent.fcai16-1.fna.fbcdn.net/v/t39.30808-6/317447083_104679542484214_1593274143128685249_n.jpg?_nc_cat=101&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=JS0Q59ySFYgQ7kNvgHTeDKd&_nc_zt=23&_nc_ht=scontent.fcai16-1.fna&_nc_gid=AQ9o2WB1f7oyN19TbLaWE4S&oh=00_AYB61wF66dfzEGxQ5AHkibdqhafkB149wWET1nyQglYeyg&oe=679C12EE'))
          ],
        ),
      ),
    );
  }
}
