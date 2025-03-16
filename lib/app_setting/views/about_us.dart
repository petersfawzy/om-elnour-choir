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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text("about us", style: TextStyle(color: AppColors.appamber)),
        backgroundColor: AppColors.backgroundColor,
        leading: BackBtn(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'فريق أم النور - الدقي\nهو كورال مسيحي أورثوذوكسي ذو قالب شرقي جديد وطراز أوركسترالي، ويعرض الكورال في معظم كنائس مصر وبدار الأوبرا المصرية. تأسس الكورال منذ عام ١٩٧٦ بمجموعة صغيرة من الشباب المتحمس لخدمة التسبيح وما زال بعضهم في الكورال حتى وقتنا هذا، ويتكون الفريق الآن من حوالي ١٠٠ مرنماً ومرنمة بقيادة أ. د. سعد إبراهيم أستاذ التخدير بكلية الطب، ويتميز بوجود مختلف الأجيال فتجد من أعضائه الشاب والشابة الجامعية ومعهم في نفس الوقت الآباء والأمهات وتجمع الجميع روح الشركة والمحبة والخدمة فيعملون جميعاً بوحدانية حتى تخرج التسابيح والترانيم في أبهى صورة تمجد اسم الله وتكون سبب بركة لهم وللمستمعين. ينتمي فريق أم النور إلى كنيسة السيدة العذراء مريم بالدقي، وهي كنيسة يرجع تاريخها إلى أوائل الستينات وتقع في شارع الأنصار المتفرع من شارع التحرير، وتمتد خدماتها إلى مناطق الدقي، المهندسين، بولاق الدكرور، صفت وأبو قتاته. وسُمي الكورال باسم أم النور تيمناً بالسيدة العذراء والدة الإله والتي تسمى الكنيسة على اسمها.',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.backgroundColor,
            ),
          ),
        ),
      ),
      bottomNavigationBar:
          AdBanner(key: UniqueKey()), // ✅ إعلان ثابت حتى مع التمرير
    );
  }
}
