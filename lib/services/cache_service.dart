import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE hymns (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE albums (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // حفظ البيانات في قاعدة البيانات المحلية
  Future<void> saveToDatabase(String table, String id, Map<String, dynamic> data) async {
    try {
      final db = await database;
      await db.insert(
        table,
        {
          'id': id,
          'data': jsonEncode(data),
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
} 