import 'dart:io';
import 'package:flutter/services.dart';

class MediaIntegrationHelper {
  static const MethodChannel _channel =
      MethodChannel('com.egypt.redcherry.omelnourchoir/media_control');

  bool _isInitialized = false;
  Function(String)? _remoteCommandHandler;

  // تهيئة خدمة التحكم في الوسائط
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ MediaIntegrationHelper مهيأ بالفعل');
      return;
    }

    try {
      print('🔄 تهيئة MediaIntegrationHelper...');

      if (Platform.isIOS) {
        await _channel.invokeMethod('initialize');

        // إعداد مستمع الأوامر
        _channel.setMethodCallHandler(_handleMethodCall);

        print('✅ تم تهيئة MediaIntegrationHelper لـ iOS بنجاح');
      } else {
        print('⚠️ MediaIntegrationHelper متاح فقط لـ iOS');
      }

      _isInitialized = true;
    } catch (e) {
      print('❌ خطأ في تهيئة MediaIntegrationHelper: $e');
      _isInitialized = false;
    }
  }

  // معالجة استدعاءات الطرق من iOS
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    print('📱 تم استلام استدعاء من iOS: ${call.method}');

    switch (call.method) {
      case 'remoteCommand':
        final command = call.arguments as String?;
        if (command != null && _remoteCommandHandler != null) {
          _remoteCommandHandler!(command);
        }
        break;
      case 'appLifecycleEvent':
        final event = call.arguments as String?;
        if (event != null && _remoteCommandHandler != null) {
          _remoteCommandHandler!(event);
        }
        break;
      default:
        print('⚠️ استدعاء غير معروف من iOS: ${call.method}');
    }
  }

  // تسجيل معالج أوامر التحكم عن بُعد
  void registerRemoteCommandHandler(Function(String) handler) {
    _remoteCommandHandler = handler;
    print('📱 تم تسجيل معالج أوامر التحكم عن بُعد');
  }

  // تحديث معلومات التشغيل الحالية
  Future<void> updateNowPlayingInfo({
    required String title,
    required String artist,
    required Duration duration,
    required Duration position,
    required bool isPlaying,
  }) async {
    if (!_isInitialized || !Platform.isIOS) {
      print('⚠️ MediaIntegrationHelper غير مهيأ أو ليس iOS');
      return;
    }

    try {
      await _channel.invokeMethod('updateNowPlayingInfo', {
        'title': title,
        'artist': artist,
        'duration': duration.inSeconds.toDouble(),
        'position': position.inSeconds.toDouble(),
        'isPlaying': isPlaying,
      });

      print('🍎 تم تحديث معلومات التشغيل في iOS: $title');
    } catch (e) {
      print('❌ خطأ في تحديث معلومات التشغيل: $e');
    }
  }

  // مسح معلومات التشغيل
  Future<void> clearNowPlayingInfo() async {
    if (!_isInitialized || !Platform.isIOS) {
      return;
    }

    try {
      await _channel.invokeMethod('clearNowPlayingInfo');
      print('🗑️ تم مسح معلومات التشغيل من iOS');
    } catch (e) {
      print('❌ خطأ في مسح معلومات التشغيل: $e');
    }
  }

  // إعادة تفعيل جلسة الوسائط
  Future<void> reactivateMediaSession() async {
    if (!_isInitialized || !Platform.isIOS) {
      return;
    }

    try {
      await _channel.invokeMethod('reactivateMediaSession');
      print('✅ تم إعادة تفعيل جلسة الوسائط');
    } catch (e) {
      print('❌ خطأ في إعادة تفعيل جلسة الوسائط: $e');
    }
  }

  // معالجة أحداث دورة حياة التطبيق
  Future<void> handleAppLifecycleEvent(String event) async {
    if (!_isInitialized || !Platform.isIOS) {
      return;
    }

    try {
      await _channel.invokeMethod('handleAppLifecycleEvent', event);
      print('📱 تم إرسال حدث دورة حياة التطبيق: $event');
    } catch (e) {
      print('❌ خطأ في معالجة حدث دورة حياة التطبيق: $e');
    }
  }

  // التحقق من حالة التهيئة
  bool get isInitialized => _isInitialized;

  // تنظيف الموارد
  void dispose() {
    print('🧹 تنظيف MediaIntegrationHelper');
    _remoteCommandHandler = null;
    _isInitialized = false;
  }
}
