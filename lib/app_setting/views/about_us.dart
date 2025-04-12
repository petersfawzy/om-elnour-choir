import 'package:flutter/material.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';

class AboutUs extends StatefulWidget {
  const AboutUs({super.key});

  @override
  State<AboutUs> createState() => _AboutUsState();
}

class _AboutUsState extends State<AboutUs> {
  // دالة لحساب حجم الخط المتغير بناءً على حجم الشاشة
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

  @override
  Widget build(BuildContext context) {
    // حساب حجم الخط المتغير
    final contentFontSize = _calculateFontSize(context, 18.0, 0.05);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text("about us", style: TextStyle(color: AppColors.appamber)),
        backgroundColor: AppColors.backgroundColor,
        leading: BackBtn(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
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
                color: AppColors.appamber.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            'فريق أم النور - الدقي\nهو كورال مسيحي أورثوذوكسي ذو قالب شرقي جديد وطراز أوركسترالي، ويعرض الكورال في معظم كنائس مصر وبدار الأوبرا المصرية. تأسس الكورال منذ عام ١٩٧٦ بمجموعة صغيرة من الشباب المتحمس لخدمة التسبيح وما زال بعضهم في الكورال حتى وقتنا هذا، ويتكون الفريق الآن من حوالي ١٠٠ مرنماً ومرنمة بقيادة أ. د. سعد إبراهيم أستاذ التخدير بكلية الطب، ويتميز بوجود مختلف الأجيال فتجد من أعضائه الشاب والشابة الجامعية ومعهم في نفس الوقت الآباء والأمهات وتجمع الجميع روح الشركة والمحبة والخدمة فيعملون جميعاً بوحدانية حتى تخرج التسابيح والترانيم في أبهى صورة تمجد اسم الله وتكون سبب بركة لهم وللمستمعين. ينتمي فريق أم النور إلى كنيسة السيدة العذراء مريم بالدقي، وهي كنيسة يرجع تاريخها إلى أوائل الستينات وتقع في شارع الأنصار المتفرع من شارع التحرير، وتمتد خدماتها إلى مناطق الدقي، المهندسين، بولاق الدكرور، صفت وأبو قتاته. وسُمي الكورال باسم أم النور تيمناً بالسيدة العذراء والدة الإله والتي تسمى الكنيسة على اسمها.',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: contentFontSize,
              fontWeight: FontWeight.bold,
              color: AppColors.appamber,
              height: 1.3, // إضافة تباعد بين الأسطر
              letterSpacing: 0.5, // زيادة المسافة بين الحروف قليلاً
            ),
          ),
        ),
      ),
      bottomNavigationBar:
          AdBanner(key: UniqueKey(), cacheKey: 'about_us_screen'),
    );
  }
}
