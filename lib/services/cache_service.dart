import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  static Database? _database;
  static SharedPreferences? _prefs;

  factory CacheService() {
    return _instance;
  }

  CacheService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'hymns_cache.db');
    return await openDatabase(
      path,
      version: 2, // زيادة رقم الإصدار لإضافة عمود timestamp
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE hymns (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE albums (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          // إضافة عمود timestamp للجداول الموجودة
          await db.execute(
              'ALTER TABLE hymns ADD COLUMN timestamp INTEGER DEFAULT ${DateTime.now().millisecondsSinceEpoch}');
          await db.execute(
              'ALTER TABLE albums ADD COLUMN timestamp INTEGER DEFAULT ${DateTime.now().millisecondsSinceEpoch}');
          await db.execute(
              'ALTER TABLE categories ADD COLUMN timestamp INTEGER DEFAULT ${DateTime.now().millisecondsSinceEpoch}');
        }
      },
    );
  }

  // حفظ البيانات في قاعدة البيانات المحلية مع إضافة طابع زمني
  Future<void> saveToDatabase(
      String table, String id, Map<String, dynamic> data) async {
    try {
      // إضافة طابع زمني للبيانات
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final db = await database;
      await db.insert(
        table,
        {
          'id': id,
          'data': jsonEncode(data),
          'timestamp':
              timestamp, // تخزين الطابع الزمني كعمود منفصل للبحث السريع
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('❌ خطأ في حفظ البيانات في التخزين المؤقت: $e');
    }
  }

  // استرجاع البيانات من قاعدة البيانات المحلية
  Future<Map<String, dynamic>?> getFromDatabase(String table, String id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        table,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        final data = maps.first['data'] as String;
        // تحديث الطابع الزمني عند الاستخدام
        await db.update(
          table,
          {'timestamp': DateTime.now().millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [id],
        );
        return jsonDecode(data) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ خطأ في جلب البيانات من التخزين المؤقت: $e');
      return null;
    }
  }

  // حفظ البيانات في SharedPreferences
  Future<void> saveToPrefs(String key, dynamic value) async {
    try {
      final prefs = await this.prefs;
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(key, value);
      } else if (value is Map<String, dynamic>) {
        await prefs.setString(key, jsonEncode(value));
      }
    } catch (e) {
      print('❌ خطأ في حفظ البيانات في SharedPreferences: $e');
    }
  }

  // استرجاع البيانات من SharedPreferences
  Future<dynamic> getFromPrefs(String key) async {
    try {
      final prefs = await this.prefs;
      final value = prefs.get(key);
      if (value is String) {
        try {
          return jsonDecode(value);
        } catch (e) {
          return value;
        }
      }
      return value;
    } catch (e) {
      print('❌ خطأ في جلب البيانات من SharedPreferences: $e');
      return null;
    }
  }

  // حذف البيانات من SharedPreferences
  Future<void> removeFromPrefs(String key) async {
    final prefs = await this.prefs;
    await prefs.remove(key);
  }

  // حذف جميع البيانات المخزنة مؤقتاً
  Future<void> clearCache() async {
    try {
      final db = await database;
      await db.delete('hymns');
      await db.delete('albums');
      await db.delete('categories');

      final prefs = await this.prefs;
      await prefs.clear();
    } catch (e) {
      print('❌ خطأ في مسح التخزين المؤقت: $e');
    }
  }

  // تنظيف الكاش القديم
  Future<void> cleanOldCache() async {
    try {
      print('🧹 جاري تنظيف الكاش القديم...');

      final db = await database;

      // الحصول على تاريخ قبل 30 يوم
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
      final timestamp = thirtyDaysAgo.millisecondsSinceEpoch;

      // حذف البيانات القديمة من جداول قاعدة البيانات
      final hymnsDeleted = await db
          .delete('hymns', where: 'timestamp < ?', whereArgs: [timestamp]);
      final albumsDeleted = await db
          .delete('albums', where: 'timestamp < ?', whereArgs: [timestamp]);
      final categoriesDeleted = await db
          .delete('categories', where: 'timestamp < ?', whereArgs: [timestamp]);

      print(
          '✅ تم تنظيف الكاش القديم بنجاح: حذف $hymnsDeleted ترنيمة، $albumsDeleted ألبوم، $categoriesDeleted تصنيف');
    } catch (e) {
      print('❌ خطأ في تنظيف الكاش القديم: $e');
    }
  }

  // الحصول على حجم الكاش
  Future<Map<String, dynamic>> getCacheSize() async {
    try {
      final db = await database;

      // الحصول على عدد العناصر في كل جدول
      final hymnsCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM hymns')) ??
          0;
      final albumsCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM albums')) ??
          0;
      final categoriesCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM categories')) ??
          0;

      // الحصول على حجم قاعدة البيانات
      final dbPath = await getDatabasesPath();
      final dbFile = File(join(dbPath, 'hymns_cache.db'));
      final dbSize = await dbFile.length();

      // الحصول على حجم الصور المخزنة مؤقتًا
      final prefs = await SharedPreferences.getInstance();
      final cachedImages = prefs.getStringList('cached_images') ?? [];

      return {
        'hymnsCount': hymnsCount,
        'albumsCount': albumsCount,
        'categoriesCount': categoriesCount,
        'databaseSize': dbSize,
        'databaseSizeMB': (dbSize / (1024 * 1024)).toStringAsFixed(2),
        'imagesCount': cachedImages.length,
        'totalItems': hymnsCount + albumsCount + categoriesCount,
      };
    } catch (e) {
      print('❌ خطأ في الحصول على حجم الكاش: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  // تعيين الحجم الأقصى للكاش
  Future<void> setMaxCacheSize(int maxSizeMB) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('max_cache_size_mb', maxSizeMB);
      print('⚙️ تم تعيين الحجم الأقصى للكاش: $maxSizeMB ميجابايت');

      // تنظيف الكاش إذا تجاوز الحجم الأقصى
      await enforceMaxCacheSize();
    } catch (e) {
      print('❌ خطأ في تعيين الحجم الأقصى للكاش: $e');
    }
  }

  // تطبيق الحجم الأقصى للكاش
  Future<void> enforceMaxCacheSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final maxSizeMB =
          prefs.getInt('max_cache_size_mb') ?? 200; // 200 ميجابايت افتراضيًا

      // الحصول على حجم الكاش الحالي
      final cacheInfo = await getCacheSize();
      final dbSize = cacheInfo['databaseSize'] as int;
      final dbSizeMB = dbSize / (1024 * 1024);

      if (dbSizeMB > maxSizeMB) {
        print(
            '🧹 حجم الكاش الحالي ($dbSizeMB MB) يتجاوز الحد الأقصى ($maxSizeMB MB)، جاري التنظيف...');

        // تنظيف الكاش القديم
        await cleanOldCache();
      }
    } catch (e) {
      print('❌ خطأ في تطبيق الحجم الأقصى للكاش: $e');
    }
  }

  Future<void> cacheImage(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedImages = prefs.getStringList('cached_images') ?? [];

      if (!cachedImages.contains(url)) {
        cachedImages.add(url);
        await prefs.setStringList('cached_images', cachedImages);
      }
    } catch (e) {
      print('❌ خطأ في تخزين الصورة: $e');
    }
  }

  Future<bool> isImageCached(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedImages = prefs.getStringList('cached_images') ?? [];
      return cachedImages.contains(url);
    } catch (e) {
      print('❌ خطأ في التحقق من تخزين الصورة: $e');
      return false;
    }
  }

  // حذف الصور القديمة من الكاش
  Future<void> cleanOldImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedImages = prefs.getStringList('cached_images') ?? [];

      if (cachedImages.length > 100) {
        // الاحتفاظ بآخر 50 صورة فقط
        final imagesToKeep = cachedImages.sublist(cachedImages.length - 50);
        await prefs.setStringList('cached_images', imagesToKeep);
        print(
            '🧹 تم تنظيف ${cachedImages.length - imagesToKeep.length} صورة من الكاش');
      }
    } catch (e) {
      print('❌ خطأ في تنظيف الصور القديمة: $e');
    }
  }
}
