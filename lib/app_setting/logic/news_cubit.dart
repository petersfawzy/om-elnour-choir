import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/news_model.dart';
import 'package:om_elnour_choir/app_setting/logic/news_states.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NewsCubit extends Cubit<NewsStates> {
  NewsCubit() : super(InitNewsStates());

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> newsList = [];

  // Cache constants
  static const String _cacheKey = 'newsList';
  static const String _lastUpdateKey = 'newsLastUpdate';
  static const String _newsCountKey = 'newsCount';
  static const int _cacheExpiryMinutes = 10; // Cache expires after 10 minutes
  static const int _autoCheckIntervalMinutes =
      2; // Check for updates every 2 minutes

  // Fetch news with caching
  Future<void> fetchNews() async {
    emit(NewsLoadingState());

    try {
      // Check if we have valid cached data
      if (await _loadFromCache()) {
        emit(NewsLoadedState(newsList));
      } else {
        // If no valid cache, fetch from Firestore
        await _fetchFromFirestore();
        emit(NewsLoadedState(newsList));
      }
    } catch (e) {
      print('❌ Error fetching news: $e');
      emit(NewsErrorState(error: e.toString()));
    }
  }

  // Load news from cache if available and not expired
  Future<bool> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_lastUpdateKey);
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      // Check if cache exists and is not expired
      if (lastUpdate != null &&
          currentTime - lastUpdate < _cacheExpiryMinutes * 60 * 1000) {
        final cachedData = prefs.getString(_cacheKey);
        if (cachedData != null) {
          final decodedData = json.decode(cachedData);
          newsList = List<Map<String, dynamic>>.from(decodedData);
          print('✅ Loaded news from cache: ${newsList.length} items');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('❌ Error loading news from cache: $e');
      return false;
    }
  }

  // Fetch news from Firestore and update cache
  Future<void> _fetchFromFirestore() async {
    try {
      final snapshot = await _firestore.collection('news').get();

      newsList = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                'content': doc['content'] ?? '',
                'imageUrl': doc['imageUrl'] ?? '',
              })
          .toList();

      // Update cache
      await _updateCache();
      print('✅ Fetched news from Firestore: ${newsList.length} items');
    } catch (e) {
      print('❌ Error fetching news from Firestore: $e');
      throw e;
    }
  }

  // Update the cache with current news data
  Future<void> _updateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(newsList));
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt(_newsCountKey, newsList.length);
      print('✅ Updated news cache');
    } catch (e) {
      print('❌ Error updating news cache: $e');
    }
  }

  // Force refresh from Firestore
  Future<void> refreshNews() async {
    emit(NewsLoadingState());
    try {
      await _fetchFromFirestore();
      emit(NewsLoadedState(newsList));
    } catch (e) {
      emit(NewsErrorState(error: e.toString()));
    }
  }

  // Check if there are new updates without changing the current state
  Future<bool> checkForUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_lastUpdateKey);
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      // Only check for updates if the last check was more than _autoCheckIntervalMinutes ago
      if (lastUpdate != null &&
          currentTime - lastUpdate < _autoCheckIntervalMinutes * 60 * 1000) {
        print('⏱️ Too soon to check for updates');
        return false;
      }

      print('🔍 Checking for news updates...');

      // Get the current count of news items
      final cachedCount = prefs.getInt(_newsCountKey) ?? 0;

      // Check the count in Firestore
      final snapshot = await _firestore.collection('news').get();
      final currentCount = snapshot.docs.length;

      print('📊 News count - Cached: $cachedCount, Current: $currentCount');

      // If the counts are different, there are updates
      if (currentCount != cachedCount) {
        print('🔄 New updates available!');
        return true;
      }

      // Update the last check time even if no updates
      await prefs.setInt(_lastUpdateKey, currentTime);
      print('✅ No new updates');
      return false;
    } catch (e) {
      print('❌ Error checking for updates: $e');
      return false;
    }
  }

  void createNews({required String content, String? imageUrl}) async {
    try {
      await _firestore.collection('news').add({
        'content': content,
        'imageUrl': imageUrl ?? "",
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Refresh news after creating
      await refreshNews();
      emit(CreatNewsSuccessStates());
    } catch (e) {
      emit(CreatNewsFailedStates(error: e.toString()));
    }
  }

  void editNews(
      {required String docId,
      required String content,
      String? imageUrl}) async {
    try {
      await _firestore.collection('news').doc(docId).update({
        'content': content,
        'imageUrl': imageUrl ?? "",
      });

      // Refresh news after editing
      await refreshNews();
      emit(EditNewsStates());
    } catch (e) {
      emit(EditNewsFailedStates(error: e.toString()));
    }
  }

  void deleteNews(String docId) async {
    try {
      await _firestore.collection('news').doc(docId).delete();

      // Refresh news after deleting
      await refreshNews();
      emit(DeleteNewsStates());
    } catch (e) {
      emit(DeleteNewsFailedStates(error: e.toString()));
    }
  }
}
