import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/app_setting/views/HymnsPage.dart';
import 'package:om_elnour_choir/app_setting/views/daily_bread.dart';
import 'package:om_elnour_choir/app_setting/views/news.dart';
import 'package:om_elnour_choir/app_setting/views/coptic_calendar.dart';
import 'package:om_elnour_choir/services/AlbumDetails.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:om_elnour_choir/services/notification_history_service.dart';

// تعديل تعريف الكلاس NotificationService
class NotificationService {
  static NotificationService? _instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // إضافة خدمة تاريخ الإشعارات
  final NotificationHistoryService _historyService =
      NotificationHistoryService();

  // مفتاح عام للـ Navigator للوصول إلى BuildContext
  final GlobalKey<NavigatorState> navigatorKey;

  // تخزين آخر إشعار تم استلامه عندما كان التطبيق مغلقًا
  RemoteMessage? _initialMessage;

  // تعديل factory constructor لإنشاء مثيل جديد إذا لم يكن موجودًا أو إذا تم تمرير مفتاح جديد
  factory NotificationService(
      {required GlobalKey<NavigatorState> navigatorKey}) {
    _instance ??= NotificationService._internal(navigatorKey);
    return _instance!;
  }

  // تعديل المُنشئ الداخلي ليأخذ navigatorKey كمعامل
  NotificationService._internal(this.navigatorKey) {
    // تهيئة خدمة تاريخ الإشعارات
    _historyService.initialize();
  }

  Future<void> initialize() async {
    // طلب أذونات الإشعارات
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // إعداد الإشعارات المحلية - تعديل لاستخدام أيقونة التطبيق
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/logo');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response.payload);
      },
    );

    // إنشاء قناة الإشعارات لنظام Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // منع عرض الإشعارات التلقائية من FCM عندما يكون التطبيق في المقدمة
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    // التعامل مع الإشعارات عندما يكون التطبيق في المقدمة
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // التعامل مع الإشعارات عندما يتم فتح التطبيق من خلال الضغط على الإشعار (التطبيق في الخلفية)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // التحقق من وجود إشعار فتح التطبيق (التطبيق كان مغلقًا)
    _initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (_initialMessage != null) {
      // تأخير التنقل حتى يتم بناء التطبيق بالكامل
      Future.delayed(Duration(milliseconds: 500), () {
        _handleMessageOpenedApp(_initialMessage!);
      });
    }

    // الحصول على رمز الجهاز (مفيد لإرسال إشعارات لأجهزة محددة)
    String? token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');
  }

  // تحديث استدعاء الدالة في _handleForegroundMessage
  // معالجة الإشعارات عندما يكون التطبيق في المقدمة
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('تم استلام إشعار في المقدمة: ${message.notification?.title}');
    print('بيانات الإشعار: ${message.data}');

    // إضافة الإشعار إلى تاريخ الإشعارات
    if (message.notification != null) {
      await _historyService.addNotification(
        id: message.messageId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: message.notification!.title ?? 'إشعار جديد',
        body: message.notification!.body ?? '',
        data: message.data,
      );
    }

    // عرض إشعار محلي
    if (message.notification != null) {
      await showLocalNotification(
        id: message.messageId?.hashCode ?? message.hashCode,
        title: message.notification!.title ?? 'إشعار جديد',
        body: message.notification!.body ?? '',
        payload: jsonEncode(message.data),
      );
    }
  }

  // معالجة الإشعارات عندما يتم فتح التطبيق من خلال الضغط على الإشعار
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('تم فتح التطبيق من الإشعار: ${message.notification?.title}');
    print('بيانات الإشعار: ${message.data}');

    // إضافة الإشعار إلى تاريخ الإشعارات
    if (message.notification != null) {
      _historyService.addNotification(
        id: message.messageId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: message.notification!.title ?? 'إشعار جديد',
        body: message.notification!.body ?? '',
        data: message.data,
      );

      // وضع علامة على الإشعار كمقروء
      _historyService.markAsRead(message.messageId ??
          DateTime.now().millisecondsSinceEpoch.toString());
    }

    // استخراج البيانات من الإشعار
    final data = message.data;

    // التنقل إلى الشاشة المطلوبة
    _navigateToScreen(data);
  }

  // تغيير اسم الدالة من _showLocalNotification إلى showLocalNotification (إزالة علامة _)
  // عرض إشعار محلي
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/logo', // استخدام شعار التطبيق الموجود
      largeIcon: DrawableResourceAndroidBitmap(
          '@mipmap/logo'), // استخدام نفس الشعار كأيقونة كبيرة
      color: Color(0xFFFFD700), // لون الإشعار (ذهبي)
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // معالجة النقر على الإشعار المحلي
  void _handleNotificationTap(String? payload) {
    if (payload != null) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        _navigateToScreen(data);
      } catch (e) {
        print('خطأ في تحليل بيانات الإشعار: $e');
      }
    }
  }

  // إضافة دالة عامة للتعامل مع النقر على الإشعار من شاشة الإشعارات
  void handleNotificationTap(Map<String, dynamic> data) {
    _navigateToScreen(data);
  }

  // التنقل إلى الشاشة المطلوبة بناء�� على بيانات الإشعار
  void _navigateToScreen(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      print('لا يمكن الوصول إلى BuildContext');
      return;
    }

    // استخراج نوع الشاشة من بيانات الإشعار
    final screenType = data['screen_type'];
    final screenId = data['screen_id'];

    print('التنقل إلى: $screenType, معرف: $screenId');

    // الحصول على مرجع لـ HymnsCubit
    final hymnsCubit = BlocProvider.of<HymnsCubit>(context, listen: false);
    final audioService = hymnsCubit.audioService;

    // إذا لم يتم تحديد نوع الشاشة، افتح الشاشة الرئيسية بشكل افتراضي
    if (screenType == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      return;
    }

    switch (screenType) {
      case 'hymns_page':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HymnsPage(audioService: audioService),
          ),
        );
        break;

      case 'hymn_details':
        if (screenId != null) {
          // تعديل: جلب بيانات الترنيمة وتشغيلها ثم الانتقال إلى تبويب الترانيم
          FirebaseFirestore.instance
              .collection('hymns')
              .doc(screenId)
              .get()
              .then((doc) {
            if (doc.exists) {
              final data = doc.data()!;
              final hymn = HymnsModel(
                id: doc.id,
                songName: data['songName'] ?? '',
                songUrl: data['songUrl'] ?? '',
                songCategory: data['songCategory'] ?? '',
                songAlbum: data['songAlbum'] ?? '',
                views: data['views'] ?? 0,
                dateAdded: (data['dateAdded'] as Timestamp).toDate(),
                youtubeUrl: data['youtubeUrl'],
              );

              // تشغيل الترنيمة
              hymnsCubit.playHymn(hymn);

              // الانتقال إلى تبويب الترانيم بدلاً من صفحة التفاصيل
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HymnsPage(audioService: audioService),
                ),
              );
            } else {
              // إذا لم يتم العثور على الترنيمة، انتقل إلى صفحة الترانيم
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HymnsPage(audioService: audioService),
                ),
              );
            }
          }).catchError((e) {
            print('خطأ في جلب بيانات الترنيمة: $e');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HymnsPage(audioService: audioService),
              ),
            );
          });
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HymnsPage(audioService: audioService),
            ),
          );
        }
        break;

      case 'new_hymn':
        // إضافة حالة خاصة للترانيم الجديدة
        if (screenId != null) {
          FirebaseFirestore.instance
              .collection('hymns')
              .doc(screenId)
              .get()
              .then((doc) {
            if (doc.exists) {
              final data = doc.data()!;
              final hymn = HymnsModel(
                id: doc.id,
                songName: data['songName'] ?? '',
                songUrl: data['songUrl'] ?? '',
                songCategory: data['songCategory'] ?? '',
                songAlbum: data['songAlbum'] ?? '',
                views: data['views'] ?? 0,
                dateAdded: (data['dateAdded'] as Timestamp).toDate(),
                youtubeUrl: data['youtubeUrl'],
              );

              // تشغيل الترنيمة
              hymnsCubit.playHymn(hymn);

              // الانتقال إلى تبويب الترانيم
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HymnsPage(audioService: audioService),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HymnsPage(audioService: audioService),
                ),
              );
            }
          }).catchError((e) {
            print('خطأ في جلب بيانات الترنيمة الجديدة: $e');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HymnsPage(audioService: audioService),
              ),
            );
          });
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HymnsPage(audioService: audioService),
            ),
          );
        }
        break;

      case 'album_details':
        if (screenId != null) {
          // استخراج اسم الألبوم وصورته من البيانات
          final albumName = data['album_name'] ?? screenId;
          final albumImage = data['album_image'] ?? '';

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AlbumDetails(
                albumName: albumName,
                albumImage: albumImage,
                audioService: audioService,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HymnsPage(audioService: audioService),
            ),
          );
        }
        break;

      case 'news':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => NewsPage()),
        );
        break;

      case 'daily_bread':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DailyBread()),
        );
        break;

      case 'coptic_calendar':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CopticCalendar()),
        );
        break;

      default:
        // إذا كان نوع الشاشة غير معروف، افتح الشاشة الرئيسية
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  // إضافة دوال للوصول إلى خدمة تاريخ الإشعارات

  // الحصول على جميع الإشعارات
  Future<List<NotificationHistoryItem>> getNotifications() async {
    return await _historyService.getNotifications();
  }

  // الحصول على عدد الإشعارات غير المقروءة
  Future<int> getUnreadCount() async {
    return await _historyService.getUnreadCount();
  }

  // وضع علامة على الإشعار كمقروء
  Future<void> markAsRead(String id) async {
    await _historyService.markAsRead(id);
  }

  // وضع علامة على جميع الإشعارات كمقروءة
  Future<void> markAllAsRead() async {
    await _historyService.markAllAsRead();
  }

  // حذف إشعار
  Future<void> deleteNotification(String id) async {
    await _historyService.deleteNotification(id);
  }

  // حذف جميع الإشعارات
  Future<void> clearAllNotifications() async {
    await _historyService.clearAll();
  }

  // إضافة دالة لاستيراد الإشعارات من الخلفية
  Future<void> importBackgroundNotification({
    required String id,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required DateTime timestamp,
    required bool isRead,
  }) async {
    try {
      // إضافة الإشعار مباشرة إلى خدمة تاريخ الإشعارات
      await _historyService.addNotification(
        id: id,
        title: title,
        body: body,
        data: data,
        timestamp: timestamp,
      );

      // إذا كان الإشعار مقروءًا، ضع علامة عليه
      if (isRead) {
        await _historyService.markAsRead(id);
      }

      print("✅ تم استيراد إشعار: $title");
    } catch (e) {
      print("❌ خطأ في استيراد إشعار: $e");
      throw e; // إعادة رمي الخطأ للتعامل معه في الدالة المستدعية
    }
  }
}
