import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';
import 'dart:io';
import 'add_news.dart';
import 'edit_news.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  bool isAdmin = false;
  List<Map<String, String>> newsList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserRole();
    loadNews();
  }

  Future<void> fetchUserRole() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var userDoc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          isAdmin = userDoc.data()?['role'] == "admin";
        });
      }
    }
  }

  Future<void> loadNews() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? lastUpdate = prefs.getInt('newsLastUpdate');
    int currentTime = DateTime.now().millisecondsSinceEpoch;

    if (lastUpdate != null && currentTime - lastUpdate < 10 * 60 * 1000) {
      await loadCachedNews();
    } else {
      await fetchNewsFromFirestore();
    }
  }

  Future<void> loadCachedNews() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString('newsList');
    if (cachedData != null) {
      try {
        List<dynamic> decodedData = json.decode(cachedData);
        setState(() {
          newsList = List<Map<String, String>>.from(decodedData);
          isLoading = false;
        });
      } catch (e) {
        print("❌ خطأ في تحميل الأخبار من SharedPreferences: $e");
        prefs.remove('newsList'); // حذف البيانات التالفة
        await fetchNewsFromFirestore(); // تحميل الأخبار مجددًا
      }
    }
  }

  Future<void> fetchNewsFromFirestore() async {
    try {
      var snapshot = await FirebaseFirestore.instance.collection('news').get();
      var newsData = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                'content': (doc['content'] ?? "").toString(),
                'imageUrl': (doc['imageUrl'] ?? "").toString(),
              })
          .toList();

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('newsList', json.encode(newsData));
      await prefs.setInt(
          'newsLastUpdate', DateTime.now().millisecondsSinceEpoch);

      setState(() {
        newsList = List<Map<String, String>>.from(newsData);
        isLoading = false;
      });
    } catch (e) {
      print("❌ Error fetching news: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> deleteNews(String docId) async {
    await FirebaseFirestore.instance.collection('news').doc(docId).delete();
    await fetchNewsFromFirestore();
  }

  void showOptionsDialog(
      BuildContext context, String docId, String content, String? imageUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text("تعديل"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditNews(
                        docId: docId,
                        initialContent: content,
                        imageUrl: imageUrl),
                  ),
                ).then((_) => fetchNewsFromFirestore());
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("مسح"),
              onTap: () async {
                Navigator.pop(context);
                await deleteNews(docId);
              },
            ),
          ],
        );
      },
    );
  }

  bool isValidUrl(String text) {
    final Uri? uri = Uri.tryParse(text);
    return uri != null && (uri.scheme == "http" || uri.scheme == "https");
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: Platform.isIOS
              ? LaunchMode.platformDefault
              : LaunchMode.externalApplication,
        );
      } else {
        throw 'تعذر فتح الرابط';
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text("News", style: TextStyle(color: AppColors.appamber)),
        centerTitle: true,
        backgroundColor: AppColors.backgroundColor,
        leading: const BackBtn(),
        actions: [
          if (isAdmin)
            IconButton(
              icon: Icon(Icons.add, color: AppColors.appamber, size: 30),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddNews()),
                );
                fetchNewsFromFirestore();
              },
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : newsList.isEmpty
              ? const Center(child: Text("لا توجد أخبار متاحة"))
              : ListView.builder(
                  itemCount: newsList.length,
                  itemBuilder: (context, index) {
                    var newsItem = newsList[index];
                    var content = newsItem['content'] ?? "";
                    var imageUrl = newsItem['imageUrl'] ?? "";
                    var docId = newsItem['id'] ?? "";

                    return Card(
                      margin: const EdgeInsets.all(10),
                      color: AppColors.appamber,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (imageUrl.isNotEmpty)
                            GestureDetector(
                              onLongPress: isAdmin
                                  ? () => showOptionsDialog(
                                      context, docId, content, imageUrl)
                                  : null,
                              child: Image.network(imageUrl, fit: BoxFit.cover),
                            ),
                          if (content.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: GestureDetector(
                                onTap: isValidUrl(content)
                                    ? () => _launchUrl(content)
                                    : null,
                                onLongPress: isAdmin
                                    ? () => showOptionsDialog(
                                        context, docId, content, imageUrl)
                                    : null,
                                child: Text(
                                  content,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: isValidUrl(content)
                                        ? Colors.blue
                                        : AppColors.backgroundColor,
                                    decoration: isValidUrl(content)
                                        ? TextDecoration.underline
                                        : TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
      bottomNavigationBar: AdBanner(key: UniqueKey()),
    );
  }
}
