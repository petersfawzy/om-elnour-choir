import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;

class FirebaseService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final MethodChannel _channel =
      const MethodChannel('com.egypt.redcherry.omelnourchoir/messaging');

  String? _fcmToken;
  String? _apnsToken;
  bool _isInitialized = false;

  // تهيئة الخدمة
  Future<void> initialize() async {
    if (_isInitialized) {
      print('🔄 FirebaseService: تم تهيئة الخدمة بالفعل');
      return;
    }

    print('🚀 FirebaseService: بدء تهيئة الخدمة');

    try {
      // التحقق مما إذا كان Firebase مهيأ بالفعل
      bool isInitialized = false;
      try {
        final app = Firebase.app();
        isInitialized = app != null;
      } catch (e) {
        isInitialized = false;
      }

      // تهيئة Firebase إذا لم تكن مهيأة بالفعل
      if (!isInitialized) {
        print('🔥 FirebaseService: Firebase غير مهيأ، جاري التهيئة...');
        await Firebase.initializeApp();
        print('✅ FirebaseService: تم تهيئة Firebase بنجاح');
      } else {
        print('ℹ️ FirebaseService: Firebase مهيأة بالفعل، تخطي التهيئة');
      }

      // طلب أذونات الإشعارات
      try {
        await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        print('✅ FirebaseService: تم طلب أذونات الإشعارات بنجاح');
      } catch (e) {
        print('⚠️ FirebaseService: خطأ في طلب أذونات الإشعارات: $e');
      }

      // الحصول على رمز FCM
      try {
        _fcmToken = await _firebaseMessaging.getToken();
        print('📱 FirebaseService: رمز FCM الأولي: $_fcmToken');
      } catch (e) {
        print('❌ FirebaseService: خطأ في الحصول على رمز FCM: $e');
      }

      // محاولة الحصول على رمز APNS
      await getAPNSToken();

      // الاستماع لتحديثات رمز FCM
      _firebaseMessaging.onTokenRefresh.listen((token) {
        _fcmToken = token;
        print('🔄 FirebaseService: تم تحديث رمز FCM: $token');
      });

      _isInitialized = true;
      print('✅ FirebaseService: تم الانتهاء من تهيئة الخدمة');
    } catch (e) {
      print('❌ FirebaseService: خطأ في تهيئة الخدمة: $e');
    }
  }

  // دالة للتحقق من حالة تهيئة Firebase
  static bool isFirebaseInitialized() {
    try {
      final app = Firebase.app();
      return app != null;
    } catch (e) {
      return false;
    }
  }

  // دالة لتهيئة Firebase فقط
  static Future<void> initializeFirebaseOnly() async {
    try {
      print('🔥 FirebaseService: تهيئة Firebase...');

      // التحقق مما إذا كان Firebase مهيأ بالفعل
      try {
        final app = Firebase.app();
        if (app != null) {
          print(
              '✅ FirebaseService: Firebase مهيأ بالفعل، لا حاجة لإعادة التهيئة');
          return;
        }
      } catch (e) {
        // تجاهل الخطأ واستمر في التهيئة
        print('⚠️ FirebaseService: Firebase غير مهيأ، سيتم تهيئته الآن');
      }

      // محاولة تهيئة Firebase
      await Firebase.initializeApp();
      print('✅ FirebaseService: تمت تهيئة Firebase بنجاح');
    } catch (e) {
      print('❌ FirebaseService: فشلت تهيئة Firebase: $e');

      // محاولة ثانية بعد تأخير قصير
      try {
        await Future.delayed(Duration(milliseconds: 800));
        await Firebase.initializeApp();
        print('✅ FirebaseService: نجحت المحاولة الثانية لتهيئة Firebase');
      } catch (e2) {
        print('❌ FirebaseService: فشلت المحاولة الثانية لتهيئة Firebase: $e2');
      }
    }
  }

  Future<String?> getAPNSToken() async {
    try {
      print('🔍 FirebaseService: محاولة الحصول على رمز APNS...');

      // محاولة أولى: استخدام القناة المخصصة
      try {
        _apnsToken = await _channel.invokeMethod<String>('getAPNSToken');
        if (_apnsToken != null && _apnsToken!.isNotEmpty) {
          print(
              '✅ FirebaseService: تم الحصول على رمز APNS من القناة المخصصة: $_apnsToken');
          return _apnsToken;
        } else {
          print('⚠️ FirebaseService: رمز APNS من القناة المخصصة فارغ أو null');
        }
      } catch (e) {
        print(
            '⚠️ FirebaseService: خطأ في الحصول على رمز APNS من القناة المخصصة: $e');
      }

      // محاولة ثانية: استخدام الطريقة المباشرة من Firebase Messaging
      try {
        final token = await _firebaseMessaging.getAPNSToken();
        if (token != null) {
          _apnsToken = token;
          print(
              '✅ FirebaseService: تم الحصول على رمز APNS من Firebase مباشرة: $_apnsToken');
          return _apnsToken;
        } else {
          print('⚠️ FirebaseService: رمز APNS من Firebase مباشرة هو null');
        }
      } catch (e) {
        print(
            '❌ FirebaseService: خطأ في الحصول على رمز APNS من Firebase مباشرة: $e');
      }

      print('⚠️ FirebaseService: لم يتم الحصول على رمز APNS بعد المحاولات');
      return null;
    } catch (e) {
      print('❌ FirebaseService: خطأ عام في الحصول على رمز APNS: $e');
      return null;
    }
  }

  // تحديث رمز FCM
  Future<void> updateFCMToken(String token) async {
    _fcmToken = token;
    print('🔄 FirebaseService: تم تحديث رمز FCM: $token');
  }

  // الحصول على رمز FCM الحالي
  String? get fcmToken => _fcmToken;

  // الحصول على رمز APNS الحالي
  String? get apnsToken => _apnsToken;
}
