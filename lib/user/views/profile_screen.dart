import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:om_elnour_choir/shared/shared_widgets/field.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_fonts.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends State<ProfileScreen> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController userNameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();

  bool isSecure = true;
  bool isEditable = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        leading: BackBtn(),
        elevation: 0.0,
        backgroundColor: AppColors.backgroundColor,
        title: Text('My Profile', style: TextStyle(color: Colors.amber[200])),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListView(
          children: [
            Column(
              children: [
                InkWell(
                  onTap: () {},
                  child: Container(
                    height: 150,
                    width: 150,
                    margin: const EdgeInsets.all(10.0),
                    decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(
                              'https://scontent.fcai16-1.fna.fbcdn.net/v/t1.6435-9/39535827_10160779253140693_6268871545834176512_n.jpg?_nc_cat=108&ccb=1-7&_nc_sid=a5f93a&_nc_ohc=omf8-ghhgKkQ7kNvgEsF4nr&_nc_zt=23&_nc_ht=scontent.fcai16-1.fna&_nc_gid=ATpjAiq2HGbRYiQRV3ORyP1&oh=00_AYCpZadgXPzs0VVYUyeu_8l63s70Dgd3xHGt-JQdqIOTTA&oe=67A1D0EB'),
                          fit: BoxFit.contain,
                        ),
                        shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50.0),
            field(
                label: 'Email Address',
                icon: Icons.email,
                controller: emailController,
                textInputType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                isEnabled: isEditable),
            const SizedBox(height: 30.0),
            field(
                label: 'User Name',
                icon: Icons.person,
                controller: userNameController,
                textInputType: TextInputType.text,
                textInputAction: TextInputAction.done,
                isEnabled: isEditable),
            const SizedBox(height: 30.0),
            field(
                label: 'Phone Number',
                icon: Icons.phone,
                controller: phoneController,
                textInputType: TextInputType.number,
                textInputAction: TextInputAction.done,
                isEnabled: isEditable,
                formaters: [FilteringTextInputFormatter.digitsOnly]),
            const SizedBox(height: 30.0),
            field(
                label: 'Password',
                icon: Icons.lock,
                controller: passwordController,
                textInputType: TextInputType.text,
                textInputAction: TextInputAction.done,
                isEnabled: isEditable,
                isSecure: isSecure,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.remove_red_eye),
                  color: AppColors.greyColor,
                  iconSize: 15,
                  onPressed: () {
                    isSecure = !isSecure;
                    setState(() {});
                  },
                )),
            const SizedBox(height: 30.0),
            Column(
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                      backgroundColor:
                          isEditable ? AppColors.jeansColor : Colors.amber[200],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      fixedSize: const Size(200, 50)),
                  onPressed: () {
                    isEditable = !isEditable;
                    setState(() {});
                  },
                  child: Text(isEditable ? 'Save' : 'Edit',
                      style: AppFonts.miniBackStyle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
