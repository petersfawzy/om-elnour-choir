import 'package:flutter/material.dart';
import 'package:om_elnour_choir/services/notification_service.dart';
import 'package:om_elnour_choir/services/notification_history_service.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  final NotificationService notificationService;

  const NotificationsScreen({
    Key? key,
    required this.notificationService,
  }) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationHistoryItem> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notifications = await widget.notificationService.getNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });

      // وضع علامة على جميع الإشعارات كمقروءة
      await widget.notificationService.markAllAsRead();
    } catch (e) {
      print('خطأ في تحميل الإشعارات: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await widget.notificationService.deleteNotification(id);
      setState(() {
        _notifications.removeWhere((notification) => notification.id == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف الإشعار')),
      );
    } catch (e) {
      print('خطأ في حذف الإشعار: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حذف الإشعار')),
      );
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      await widget.notificationService.clearAllNotifications();
      setState(() {
        _notifications = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف جميع الإشعارات')),
      );
    } catch (e) {
      print('خطأ في حذف جميع الإشعارات: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حذف جميع الإشعارات')),
      );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else {
      return DateFormat('yyyy/MM/dd').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text('الإشعارات', style: TextStyle(color: AppColors.appamber)),
        leading: BackBtn(),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep, color: AppColors.appamber),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppColors.backgroundColor,
                    title: Text('حذف جميع الإشعارات',
                        style: TextStyle(color: AppColors.appamber)),
                    content: Text('هل أنت متأكد من حذف جميع الإشعارات؟',
                        style: TextStyle(color: Colors.white)),
                    actions: [
                      TextButton(
                        child: Text('إلغاء',
                            style: TextStyle(color: Colors.white)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      TextButton(
                        child: Text('حذف', style: TextStyle(color: Colors.red)),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _clearAllNotifications();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.appamber),
              ),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 64,
                        color: AppColors.appamber.withOpacity(0.5),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'لا توجد إشعارات',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return Dismissible(
                      key: Key(notification.id),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        _deleteNotification(notification.id);
                      },
                      child: Card(
                        color: AppColors.backgroundColor.withOpacity(0.8),
                        margin:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text(
                            notification.title,
                            style: TextStyle(
                              color: AppColors.appamber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.body,
                                style: TextStyle(color: Colors.white),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _formatTimestamp(notification.timestamp),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            // استدعاء الدالة العامة للتعامل مع النقر على الإشعار
                            widget.notificationService
                                .handleNotificationTap(notification.data);
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
