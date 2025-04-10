import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:om_elnour_choir/services/notification_service.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class TestNotificationScreen extends StatefulWidget {
  const TestNotificationScreen({Key? key}) : super(key: key);

  @override
  _TestNotificationScreenState createState() => _TestNotificationScreenState();
}

class _TestNotificationScreenState extends State<TestNotificationScreen> {
  final TextEditingController _tokenController = TextEditingController();
  String? _deviceToken;
  bool _isLoading = false;
  final NotificationService _notificationService =
      NotificationService(navigatorKey: GlobalKey<NavigatorState>());

  @override
  void initState() {
    super.initState();
    _getDeviceToken();
  }

  Future<void> _getDeviceToken() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await FirebaseMessaging.instance.getToken();
      setState(() {
        _deviceToken = token;
        _tokenController.text = token ?? '';
        _isLoading = false;
      });
    } catch (e) {
      print('خطأ في الحصول على رمز الجهاز: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard() {
    if (_deviceToken != null) {
      Clipboard.setData(ClipboardData(text: _deviceToken!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم نسخ رمز الجهاز إلى الحافظة')),
      );
    }
  }

  // إضافة زر لاختبار الإشعار الافتراضي (الشاشة الرئيسية)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text('اختبار الإشعارات',
            style: TextStyle(color: AppColors.appamber)),
        leading: BackBtn(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'رمز الجهاز (FCM Token):',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.appamber,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _tokenController,
              readOnly: true,
              maxLines: 3,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                suffixIcon: IconButton(
                  icon: Icon(Icons.copy, color: AppColors.appamber),
                  onPressed: _copyToClipboard,
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'اختبار الإشعارات المحلية:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.appamber,
              ),
            ),
            SizedBox(height: 16),
            _buildTestButton(
              'فتح الشاشة الرئيسية (افتراضي)',
              () => _showTestNotification(
                title: 'الشاشة الرئيسية',
                body: 'انقر لفتح الشاشة الرئيسية',
                data: {}, // بدون تحديد نوع الشاشة، سيفتح الشاشة الرئيسية
              ),
            ),
            SizedBox(height: 8),
            _buildTestButton(
              'فتح صفحة الترانيم',
              () => _showTestNotification(
                title: 'صفحة الترانيم',
                body: 'انقر لفتح صفحة الترانيم',
                data: {'screen_type': 'hymns_page'},
              ),
            ),
            SizedBox(height: 8),
            _buildTestButton(
              'فتح تفاصيل ترنيمة',
              () => _showTestNotification(
                title: 'تفاصيل ترنيمة',
                body: 'انقر لفتح تفاصيل ترنيمة',
                data: {'screen_type': 'hymn_details', 'screen_id': 'hymn_123'},
              ),
            ),
            SizedBox(height: 8),
            // إضافة زر لاختبار إشعار ترنيمة جديدة
            _buildTestButton(
              'ترنيمة جديدة (تشغيل في تبويب الترانيم)',
              () => _showTestNotification(
                title: 'ترنيمة جديدة',
                body: 'تم إضافة ترنيمة جديدة، انقر للاستماع إليها',
                data: {'screen_type': 'new_hymn', 'screen_id': 'hymn_123'},
              ),
            ),
            SizedBox(height: 8),
            _buildTestButton(
              'فتح صفحة الأخبار',
              () => _showTestNotification(
                title: 'الأخبار',
                body: 'انقر لفتح صفحة الأخبار',
                data: {'screen_type': 'news'},
              ),
            ),
            SizedBox(height: 8),
            _buildTestButton(
              'فتح صفحة الخبز اليومي',
              () => _showTestNotification(
                title: 'الخبز اليومي',
                body: 'انقر لفتح صفحة الخبز اليومي',
                data: {'screen_type': 'daily_bread'},
              ),
            ),
            SizedBox(height: 8),
            _buildTestButton(
              'فتح صفحة التقويم القبطي',
              () => _showTestNotification(
                title: 'التقويم القبطي',
                body: 'انقر لفتح صفحة التقويم القبطي',
                data: {'screen_type': 'coptic_calendar'},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.appamber,
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(text),
    );
  }

  void _showTestNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    _notificationService.showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      payload: jsonEncode(data),
    );
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }
}
