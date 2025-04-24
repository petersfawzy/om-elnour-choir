import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationHistoryItem {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  bool isRead;

  NotificationHistoryItem({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'data': data,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
    };
  }

  factory NotificationHistoryItem.fromJson(Map<String, dynamic> json) {
    return NotificationHistoryItem(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      data: json['data'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      isRead: json['isRead'] ?? false,
    );
  }
}

class NotificationHistoryService {
  static const String _storageKey = 'notification_history';
  List<NotificationHistoryItem> _notifications = [];
  bool _isInitialized = false;

  // تهيئة الخدمة وتحميل الإشعارات المخزنة
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? notificationsJson = prefs.getString(_storageKey);

      if (notificationsJson != null) {
        final List<dynamic> decodedList = jsonDecode(notificationsJson);
        _notifications = decodedList
            .map((item) => NotificationHistoryItem.fromJson(item))
            .toList();

        // حذف الإشعارات القديمة (أكثر من أسبوع)
        _cleanupOldNotifications();
      }

      _isInitialized = true;
      print('✅ تم تهيئة خدمة تاريخ الإشعارات');
    } catch (e) {
      print('❌ خطأ في تهيئة خدمة تاريخ الإشعارات: $e');
    }
  }

  // إضافة إشعار جديد
  Future<void> addNotification({
    required String id,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    DateTime? timestamp,
  }) async {
    await initialize();

    // التحقق من عدم وجود إشعار بنفس المعرف
    final existingIndex = _notifications.indexWhere((n) => n.id == id);
    final actualTimestamp = timestamp ?? DateTime.now();

    if (existingIndex >= 0) {
      // تحديث الإشعار الموجود
      _notifications[existingIndex] = NotificationHistoryItem(
        id: id,
        title: title,
        body: body,
        data: data,
        timestamp: actualTimestamp,
        isRead: false,
      );
    } else {
      // إضافة إشعار جديد
      _notifications.add(NotificationHistoryItem(
        id: id,
        title: title,
        body: body,
        data: data,
        timestamp: actualTimestamp,
        isRead: false,
      ));
    }

    // حذف الإشعارات القديمة
    _cleanupOldNotifications();

    // حفظ التغييرات
    await _saveNotifications();
  }

  // وضع علامة على الإشعار كمقروء
  Future<void> markAsRead(String id) async {
    await initialize();

    final index = _notifications.indexWhere((n) => n.id == id);
    if (index >= 0) {
      _notifications[index].isRead = true;
      await _saveNotifications();
    }
  }

  // وضع علامة على جميع الإشعارات كمقروءة
  Future<void> markAllAsRead() async {
    await initialize();

    for (var notification in _notifications) {
      notification.isRead = true;
    }

    await _saveNotifications();
  }

  // الحصول على جميع الإشعارات
  Future<List<NotificationHistoryItem>> getNotifications() async {
    await initialize();
    return List.from(_notifications)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // الحصول على عدد الإشعارات غير المقروءة
  Future<int> getUnreadCount() async {
    await initialize();
    return _notifications.where((n) => !n.isRead).length;
  }

  // حذف إشعار
  Future<void> deleteNotification(String id) async {
    await initialize();

    _notifications.removeWhere((n) => n.id == id);
    await _saveNotifications();
  }

  // حذف جميع الإشعارات
  Future<void> clearAll() async {
    await initialize();

    _notifications.clear();
    await _saveNotifications();
  }

  // حذف الإشعارات القديمة (أكثر من أسبوع)
  void _cleanupOldNotifications() {
    final oneWeekAgo = DateTime.now().subtract(Duration(days: 7));
    _notifications.removeWhere((n) => n.timestamp.isBefore(oneWeekAgo));
  }

  // حفظ الإشعارات في التخزين المحلي
  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList =
          _notifications.map((n) => n.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      print('❌ خطأ في حفظ الإشعارات: $e');
    }
  }
}
