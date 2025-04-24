import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';
import 'package:om_elnour_choir/app_setting/logic/news_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/news_states.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'dart:io';
import 'add_news.dart';
import 'edit_news.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> with WidgetsBindingObserver {
  bool isAdmin = false;
  Timer? _autoUpdateTimer;
  bool _isAutoUpdating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchUserRole();
    // Load news using the cubit
    context.read<NewsCubit>().fetchNews();
    // Start auto-update timer
    _startAutoUpdateTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground, check for updates
      _checkForUpdates();
    } else if (state == AppLifecycleState.paused) {
      // App went to background, cancel timer
      _autoUpdateTimer?.cancel();
    }
  }

  void _startAutoUpdateTimer() {
    // Check for updates every 2 minutes
    _autoUpdateTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    if (_isAutoUpdating) return; // Prevent multiple simultaneous checks

    _isAutoUpdating = true;
    try {
      final hasUpdates = await context.read<NewsCubit>().checkForUpdates();
      if (hasUpdates && mounted) {
        // If there are updates, refresh the news
        await context.read<NewsCubit>().refreshNews();

        // Show a snackbar to inform the user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم تحديث الأخبار'),
            backgroundColor: AppColors.appamber,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      _isAutoUpdating = false;
    }
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
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("مسح"),
              onTap: () async {
                Navigator.pop(context);
                context.read<NewsCubit>().deleteNews(docId);
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
              },
            ),
          // إزالة زر التحديث اليدوي
        ],
      ),
      body: Stack(
        children: [
          // المحتوى الرئيسي مع هامش سفلي لتجنب تداخله مع الإعلان
          Positioned.fill(
            bottom: 60, // ارتفاع الإعلان تقريباً
            child: BlocBuilder<NewsCubit, NewsStates>(
              builder: (context, state) {
                if (state is NewsLoadingState) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.appamber),
                  );
                } else if (state is NewsErrorState) {
                  return Center(child: Text("خطأ: ${state.error}"));
                } else if (state is NewsLoadedState) {
                  final newsList = state.news;

                  if (newsList.isEmpty) {
                    return const Center(child: Text("لا توجد أخبار متاحة"));
                  }

                  // استخدام ListView عادي بدلاً من RefreshIndicator
                  return ListView.builder(
                    itemCount: newsList.length,
                    itemBuilder: (context, index) {
                      var newsItem = newsList[index];
                      var content = newsItem['content'] ?? "";
                      var imageUrl = newsItem['imageUrl'] ?? "";
                      var docId = newsItem['id'] ?? "";

                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.05,
                          vertical: MediaQuery.of(context).size.height * 0.01,
                        ),
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
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.fitWidth,
                                    width: double.infinity,
                                    placeholder: (context, url) => Container(
                                      height: 200,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.backgroundColor,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) {
                                      print('❌ Error loading image: $error');
                                      return Container(
                                        height: 200,
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: Icon(Icons.error,
                                              color: Colors.red, size: 40),
                                        ),
                                      );
                                    },
                                  ),
                                ),
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
                  );
                }

                // Default state
                return Center(
                  child: Text(
                    "جاري تحميل الأخبار...",
                    style: TextStyle(color: AppColors.appamber),
                  ),
                );
              },
            ),
          ),

          // الإعلان في الأسفل
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AdBanner(
              key: ValueKey('news_ad_banner'),
              cacheKey: 'news_screen',
            ),
          ),
        ],
      ),
    );
  }
}
