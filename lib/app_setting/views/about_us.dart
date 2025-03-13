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
        backgroundColor: AppColors.backgroundColor,
        leading: BackBtn(),
      ),
      body: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.amber[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'فريق أم النور - الدقي\nهو كورال مسيحي أورثوذوكسي ذو قالب شرقي جديد و طراز أوركسترالي ، ويعرض الكورال في معظم كنائس مصر وبدار الأوبرا المصرية. تأسس الكورال منذ عام ١٩٧٦ بمجموعة صغيرة من الشباب المتحمس لخدمة التسبيح وما زال بعضهم فى الكورال حتى وقتنا هذا، ويتكون الفريق الان من حوالي ١٠٠ مرنماً ومرنمة بقيادة أ . د . سعد إبراهيم أستاذ التخدير بكلية الطب، ويتميز بوجود مختلف الأجيال فتجد من أعضاءه الشاب والشابة الجامعية ومعهم فى نفس الوقت الآباء والأمهات وتجمع الجميع روح الشركة والمحبة والخدمة فيعملون جميعاً بوحدانية حتى تخرج التسابيح والترانيم فى أبهى صورة تمجد اسم الله وتكون سبب بركة لهم وللمستمعين. ينتمى فريق أم النور إلى كنيسة السيدة العذراء مريم بالدقى، وهى كنيسة يرجع تاريخها إلى أوائل الستينات وتقع فى شارع الأنصار المتفرع من شارع التحرير.وتمتد خدماتها إلى مناطق الدقى، المهندسين، بولاق الدكرور، صفت وأبو قتاته. وسمى الكورال باسم أم النور تيمناً بالسيدة العذراء والدة الإله والتى تسمى الكنيسة على إسمها',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.backgroundColor),
              ),
            ),
            const AdBanner(),
          ],
        ),
      ),
    );
  }
}
