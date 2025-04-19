import 'package:flutter/material.dart';

/// مدير الإعلانات المركزي
/// يتعامل مع دورة حياة الإعلانات ويمنع إعادة إنشاء view أثناء التنقل
class AdBannerManager {
  // Singleton pattern
  static final AdBannerManager _instance = AdBannerManager._internal();

  factory AdBannerManager() {
    return _instance;
  }

  AdBannerManager._internal();

  // تخزين إشارات إلى عناصر الإعلانات النشطة
  final Map<String, GlobalKey> _adKeys = {};

  // تتبع آخر وقت تم فيه استخدام كل مفتاح
  final Map<String, DateTime> _lastUsedTime = {};

  // دالة للحصول على مفتاح لإعلان محدد
  // استخدم نفس المفتاح للإعلان نفسه لمنع إعادة إنشاءه
  GlobalKey getAdKey(String cacheKey) {
    if (!_adKeys.containsKey(cacheKey)) {
      _adKeys[cacheKey] = GlobalKey();
      _lastUsedTime[cacheKey] = DateTime.now();
      print('🏷️ إنشاء مفتاح جديد للإعلان: $cacheKey');
    } else {
      _lastUsedTime[cacheKey] = DateTime.now();
      print('♻️ استخدام مفتاح موجود للإعلان: $cacheKey');
    }
    return _adKeys[cacheKey]!;
  }

  // دالة لتحديث مفتاح إعلان عند الحاجة (مثلاً: تغير الاتجاه)
  void updateAdKey(String cacheKey) {
    _adKeys[cacheKey] = GlobalKey();
    _lastUsedTime[cacheKey] = DateTime.now();
    print('🔄 تم تحديث مفتاح الإعلان: $cacheKey');
  }

  // دالة لإزالة مفتاح إعلان
  void removeAdKey(String cacheKey) {
    _adKeys.remove(cacheKey);
    _lastUsedTime.remove(cacheKey);
    print('🗑️ تم إزالة مفتاح الإعلان: $cacheKey');
  }

  // تنظيف المفاتيح غير المستخدمة
  void cleanUnusedKeys() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    // البحث عن المفاتيح التي لم تستخدم لأكثر من ساعة
    _lastUsedTime.forEach((key, lastUsed) {
      if (now.difference(lastUsed).inHours > 1) {
        keysToRemove.add(key);
      }
    });

    // إزالة المفاتيح غير المستخدمة
    for (final key in keysToRemove) {
      _adKeys.remove(key);
      _lastUsedTime.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      print(
          '🧹 تم تنظيف ${keysToRemove.length} من مفاتيح الإعلانات غير المستخدمة');
    }
  }

  // الحصول على عدد المفاتيح النشطة
  int get activeKeysCount => _adKeys.length;
}
