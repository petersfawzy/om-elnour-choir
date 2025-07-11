import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/app_setting/views/CategoryHymnsPage.dart';
import 'package:om_elnour_choir/app_setting/views/add_hymns.dart';
import 'package:om_elnour_choir/services/AlbumDetails.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:om_elnour_choir/shared/shared_widgets/general_hymns_list.dart';
import 'package:om_elnour_choir/shared/shared_widgets/music_player_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class HymnsPage extends StatefulWidget {
  final MyAudioService audioService;

  const HymnsPage({super.key, required this.audioService});

  @override
  _HymnsPageState createState() => _HymnsPageState();
}

class _HymnsPageState extends State<HymnsPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isAdmin = false;
  bool _isSearching = false;
  late HymnsCubit _hymnsCubit;
  bool _disposed = false;

  final ValueNotifier<int> _currentTabIndexNotifier = ValueNotifier<int>(0);

  // إضافة مفتاح للتحكم في إعادة بناء قائمة المفضلة
  final GlobalKey<_FavoritesListState> _favoritesKey =
      GlobalKey<_FavoritesListState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        widget.audioService.resumePlaybackAfterNavigation();
      }
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _hymnsCubit = context.read<HymnsCubit>();
    widget.audioService.setPreventStopDuringNavigation(true);

    // تسجيل الـ callback لزيادة عدد المشاهدات
    widget.audioService.registerHymnChangedCallback(_onHymnChangedCallback);

    // تحميل الترانيم الشائعة مسبقاً في الخلفية
    Future.microtask(() {
      if (!_disposed) {
        // استعادة آخر ترنيمة تم تشغيلها
        _hymnsCubit.restoreLastHymn();
        _hymnsCubit.loadFavorites();
      }
    });

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_disposed) {
        _currentTabIndexNotifier.value = _tabController.index;

        // إعادة تحميل المفضلة عند الانتقال إلى تبويب المفضلة
        if (_tabController.index == 3) {
          _refreshFavorites();
        }
      }
    });

    _checkAdminStatus();
  }

  // دالة لإعادة تحميل المفضلة
  void _refreshFavorites() {
    if (_favoritesKey.currentState != null) {
      _favoritesKey.currentState!.refreshFavorites();
    }
    _hymnsCubit.loadFavorites();
  }

  // أضف دالة الـ callback:
  void _onHymnChangedCallback(int index, String title) {
    if (_disposed) return;

    print('📊 تم استدعاء callback في HymnsPage للترنيمة: $title');

    // البحث عن الترنيمة في قائمة الترانيم
    final hymns = _hymnsCubit.state;
    int hymnIndex = -1;
    for (int i = 0; i < hymns.length; i++) {
      if (hymns[i].songName == title) {
        hymnIndex = i;
        break;
      }
    }

    if (hymnIndex != -1) {
      try {
        // زيادة عدد المشاهدات باستخدام HymnsCubit
        final hymnId = hymns[hymnIndex].id;
        print(
            '📊 زيادة عدد المشاهدات للترنيمة: $title (ID: $hymnId) من HymnsPage');
        _hymnsCubit.incrementHymnViews(hymnId);

        // إعادة تحميل المفضلة إذا كانت الترنيمة الحالية في المفضلة
        _refreshFavorites();
      } catch (e) {
        print('❌ خطأ أثناء زيادة عدد المشاهدات: $e');
      }
    } else {
      print('⚠️ لم يتم العثور على الترنيمة: $title في قائمة الترانيم');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;

    print('🔄 تغيرت حالة دورة حياة التطبيق في HymnsPage: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        print('📱 التطبيق عاد للمقدمة، استئناف التشغيل...');
        widget.audioService.resumePlaybackAfterNavigation();
        // إعادة تحميل المفضلة عند العودة للتطبيق
        _refreshFavorites();
        break;
      case AppLifecycleState.paused:
        print('📱 التطبيق مخفي جزئياً، حفظ حالة التشغيل...');
        widget.audioService.savePlaybackState();
        break;
      case AppLifecycleState.inactive:
        print('📱 التطبيق غير نشط، حفظ حالة التشغيل...');
        widget.audioService.savePlaybackState();
        break;
      case AppLifecycleState.detached:
        print('📱 التطبيق منفصل، حفظ حالة التشغيل...');
        widget.audioService.saveStateOnAppClose();
        break;
      case AppLifecycleState.hidden:
        print('📱 التطبيق مخفي تمامًا، حفظ حالة التشغيل...');
        widget.audioService.saveStateOnAppClose();
        break;
    }
  }

  Future<void> _checkAdminStatus() async {
    if (_disposed) return;

    final user = _auth.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(user.uid)
          .get();
      if (doc.exists && !_disposed) {
        setState(() {
          isAdmin = doc['role'] == 'admin';
        });
      }
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted && !_disposed) {
      setState(fn);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);

    // إلغاء تسجيل الـ callback
    widget.audioService.registerHymnChangedCallback(null);

    Future.microtask(() {
      try {
        _hymnsCubit.saveStateOnAppClose();
      } catch (e) {
        print('خطأ في حفظ حالة التشغيل عند الخروج: $e');
      }
    });

    _tabController.dispose();
    _searchController.dispose();
    _currentTabIndexNotifier.dispose();
    super.dispose();
  }

  void _showFilterDialog() async {
    if (_disposed) return;

    final hymnsCubit = context.read<HymnsCubit>();
    String sortBy = hymnsCubit.sortBy;
    bool descending = hymnsCubit.descending;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundColor,
        title: Text(
          'ترتيب الترانيم',
          textAlign: TextAlign.center,
          style:
              TextStyle(color: AppColors.appamber, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ترتيب حسب:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.appamber)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: sortBy,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.appamber),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: AppColors.appamber.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.appamber),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.1),
                ),
                dropdownColor: AppColors.backgroundColor,
                style: TextStyle(color: AppColors.appamber),
                isExpanded: true,
                items: [
                  DropdownMenuItem<String>(
                    value: 'dateAdded',
                    child: Text('تاريخ الإضافة'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'songName',
                    child: Text('اسم الترنيمة (أبجدي)'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'views',
                    child: Text('عدد مرات الاستماع'),
                  ),
                ],
                onChanged: (value) {
                  sortBy = value!;
                },
              ),
              const SizedBox(height: 16),
              StatefulBuilder(builder: (context, setState) {
                return Row(
                  children: [
                    Theme(
                      data: Theme.of(context).copyWith(
                        unselectedWidgetColor:
                            AppColors.appamber.withOpacity(0.5),
                        checkboxTheme: CheckboxThemeData(
                          fillColor: MaterialStateProperty.resolveWith<Color>(
                            (Set<MaterialState> states) {
                              if (states.contains(MaterialState.selected))
                                return AppColors.appamber;
                              return AppColors.appamber.withOpacity(0.5);
                            },
                          ),
                          checkColor: MaterialStateProperty.all(Colors.black),
                        ),
                      ),
                      child: Checkbox(
                        value: descending,
                        onChanged: (value) {
                          setState(() {
                            descending = value!;
                          });
                        },
                      ),
                    ),
                    Text(
                      'ترتيب تنازلي',
                      style: TextStyle(color: AppColors.appamber),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'إلغاء',
              style: TextStyle(color: AppColors.appamber.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              hymnsCubit.changeSort(sortBy, descending);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.appamber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hymnsCubit = context.read<HymnsCubit>();
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return WillPopScope(
      onWillPop: () async {
        widget.audioService.savePlaybackState();
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor,
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "بحث عن ترنيمة...",
                    hintStyle:
                        TextStyle(color: AppColors.appamber.withOpacity(0.7)),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(color: AppColors.appamber),
                  onChanged: (query) {
                    hymnsCubit.searchHymns(query);
                  },
                )
              : Text("الترانيم", style: TextStyle(color: AppColors.appamber)),
          actions: [
            ValueListenableBuilder<int>(
              valueListenable: _currentTabIndexNotifier,
              builder: (context, currentTabIndex, child) {
                if (currentTabIndex == 0) {
                  return Row(
                    children: [
                      if (_isSearching)
                        IconButton(
                          icon: Icon(Icons.close, color: AppColors.appamber),
                          onPressed: () {
                            _safeSetState(() {
                              _isSearching = false;
                              _searchController.clear();
                              hymnsCubit.searchHymns('');
                            });
                          },
                        )
                      else ...[
                        IconButton(
                          icon: Icon(Icons.search, color: AppColors.appamber),
                          onPressed: () {
                            _safeSetState(() {
                              _isSearching = true;
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.filter_list,
                              color: AppColors.appamber),
                          onPressed: _showFilterDialog,
                        ),
                        if (isAdmin)
                          IconButton(
                            icon: Icon(Icons.add, color: AppColors.appamber),
                            onPressed: () {
                              widget.audioService.savePlaybackState();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => AddHymns()),
                              ).then((_) {
                                widget.audioService
                                    .resumePlaybackAfterNavigation();
                              });
                            },
                          ),
                      ],
                    ],
                  );
                }
                return SizedBox.shrink();
              },
            ),
          ],
          leading: BackBtn(),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // شريط التبويب
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.appamber,
                      labelColor: AppColors.appamber,
                      unselectedLabelColor: AppColors.appamber.withOpacity(0.7),
                      labelStyle:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      unselectedLabelStyle: TextStyle(fontSize: 14),
                      indicatorWeight: 3,
                      tabs: [
                        Tab(text: "الترانيم"),
                        Tab(text: "الألبومات"),
                        Tab(text: "التصنيفات"),
                        Tab(text: "المفضلة"),
                      ],
                    ),
                  ),

                  // استخدام Expanded لضمان أن TabBarView يأخذ المساحة المتاحة
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _HymnsList(hymnsCubit: hymnsCubit, isAdmin: isAdmin),
                        AlbumsGrid(audioService: widget.audioService),
                        CategoriesList(audioService: widget.audioService),
                        FavoritesList(
                          key: _favoritesKey,
                          hymnsCubit: hymnsCubit,
                          isAdmin: isAdmin,
                          onFavoriteChanged: _refreshFavorites,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // مشغل الترانيم والإعلان في أسفل الشاشة
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLandscape)
                      // في الوضع الأفقي: عرض المشغل والإعلان جنبًا إلى جنب
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Music player - 75% of width
                          Expanded(
                            flex: 75,
                            child: ValueListenableBuilder<String?>(
                              valueListenable:
                                  hymnsCubit.audioService.currentTitleNotifier,
                              builder: (context, currentTitle, _) {
                                return MusicPlayerWidget(
                                  key: ValueKey('hymns_music_player_landscape'),
                                  audioService: hymnsCubit.audioService,
                                  onFavoriteChanged: _refreshFavorites,
                                );
                              },
                            ),
                          ),
                          // إضافة مسافة بين المشغل والإعلان
                          SizedBox(width: 8),
                          // Ad - 25% of width
                          Expanded(
                            flex: 25,
                            child: AdBanner(
                              key: ValueKey('hymns_ad_banner_landscape'),
                              cacheKey: 'hymns_screen_landscape',
                              audioService: widget.audioService,
                            ),
                          ),
                        ],
                      )
                    else
                      // في الوضع الرأسي: عرض المشغل والإعلان فوق بعضهما
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<String?>(
                            valueListenable:
                                hymnsCubit.audioService.currentTitleNotifier,
                            builder: (context, currentTitle, _) {
                              return MusicPlayerWidget(
                                key: ValueKey('hymns_music_player_portrait'),
                                audioService: hymnsCubit.audioService,
                                onFavoriteChanged: _refreshFavorites,
                              );
                            },
                          ),
                          SizedBox(height: 8),
                          AdBanner(
                            key: ValueKey('hymns_ad_banner_portrait'),
                            cacheKey: 'hymns_screen_portrait',
                            audioService: widget.audioService,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _HymnsList extends StatefulWidget {
  final HymnsCubit hymnsCubit;
  final bool isAdmin;

  const _HymnsList({Key? key, required this.hymnsCubit, required this.isAdmin})
      : super(key: key);

  @override
  _HymnsListState createState() => _HymnsListState();
}

class _HymnsListState extends State<_HymnsList>
    with AutomaticKeepAliveClientMixin {
  @override
  void initState() {
    super.initState();

    // تسجيل سياق قائمة التشغيل عند بدء الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // تعيين سياق قائمة التشغيل إلى 'general' فقط إذا كان مختلفًا
        final currentType = widget.hymnsCubit.currentPlaylistType;
        if (currentType != 'general') {
          widget.hymnsCubit.setCurrentPlaylistType('general');
          widget.hymnsCubit.setCurrentPlaylistId(null);
          print('📋 تم تسجيل سياق قائمة التشغيل العامة عند بدء الصفحة');
        }
      }
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // التأكد من أن سياق قائمة التشغيل هو 'general' قبل عرض القائمة
    if (widget.hymnsCubit.currentPlaylistType != 'general') {
      widget.hymnsCubit.setCurrentPlaylistType('general');
      widget.hymnsCubit.setCurrentPlaylistId(null);
    }

    // إضافة padding في الأسفل لإفساح المجال لمشغل الترانيم والإعلان
    return Padding(
      padding: EdgeInsets.only(
          bottom: 120), // قيمة تقريبية لإفساح المجال للمشغل والإعلان
      child: GeneralHymnsList(
        hymnsCubit: widget.hymnsCubit,
        isAdmin: widget.isAdmin,
        playlistType: 'general',
        showAllControls: true,
      ),
    );
  }
}

class AlbumsGrid extends StatefulWidget {
  final MyAudioService audioService;

  const AlbumsGrid({super.key, required this.audioService});

  @override
  _AlbumsGridState createState() => _AlbumsGridState();
}

class _AlbumsGridState extends State<AlbumsGrid>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // تحديد ما إذا كان الجهاز في الوضع الأفقي
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final screenWidth = MediaQuery.of(context).size.width;

    return StreamBuilder<QuerySnapshot>(
      stream: context.read<HymnsCubit>().fetchAlbumsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text("❌ خطأ في تحميل الألبومات: ${snapshot.error}"),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text("📭 لا توجد ألبومات متاحة",
                style: TextStyle(color: AppColors.appamber)),
          );
        }

        var docs = snapshot.data!.docs;

        // حساب عدد الأعمدة بناءً على عرض الشاشة
        int crossAxisCount;
        if (screenWidth < 600) {
          crossAxisCount = isLandscape ? 3 : 2;
        } else if (screenWidth < 900) {
          crossAxisCount = isLandscape ? 4 : 3;
        } else {
          crossAxisCount = isLandscape ? 5 : 4;
        }

        // إضافة padding في الأسفل لإفساح المجال لمشغل الترانيم والإعلان
        return Padding(
          padding: EdgeInsets.only(
              bottom: 120), // قيمة تقريبية لإفساح المجال للمشغل والإعلان
          child: GridView.builder(
            key: PageStorageKey('albumsGrid'),
            padding: EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map<String, dynamic>;

              String albumName = (data['name'] ?? 'بدون اسم').toString();
              String? albumImage = (data['image'] ?? '').toString();

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AlbumDetails(
                        albumName: albumName,
                        albumImage: albumImage,
                        audioService: context.read<HymnsCubit>().audioService,
                      ),
                    ),
                  );
                },
                child: Card(
                  color: AppColors.backgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 3,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          child: albumImage!.isNotEmpty
                              ? Image.network(
                                  albumImage,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      'assets/images/logo.png',
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    );
                                  },
                                )
                              : Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Text(
                            albumName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.appamber,
                              fontWeight: FontWeight.bold,
                              fontSize: isLandscape ? 11 : 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class CategoriesList extends StatefulWidget {
  final MyAudioService audioService;

  const CategoriesList({super.key, required this.audioService});

  @override
  _CategoriesListState createState() => _CategoriesListState();
}

class _CategoriesListState extends State<CategoriesList>
    with AutomaticKeepAliveClientMixin {
  bool _isProcessingTap = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<QuerySnapshot>(
      stream: context.read<HymnsCubit>().fetchCategoriesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('حدث خطأ في تحميل التصنيفات'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('لا توجد تصنيفات'));
        }

        final categories = snapshot.data!.docs;

        // إضافة padding في الأسفل لإفساح المجال لمشغل الترانيم والإعلان
        return Padding(
          padding: EdgeInsets.only(
              bottom: 120), // قيمة تقريبية لإفساح المجال للمشغل والإعلان
          child: ListView.builder(
            key: PageStorageKey('categoriesList'),
            padding: EdgeInsets.only(bottom: 20),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final doc = categories[index];
              final data = doc.data() as Map<String, dynamic>;
              final categoryName = data['name'] as String? ?? 'بدون اسم';
              final categoryImage = data['image'] as String? ?? '';

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                color: AppColors.backgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: AppColors.appamber.withOpacity(0.3)),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.all(10),
                  title: Text(
                    categoryName,
                    style: TextStyle(
                      color: AppColors.appamber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing:
                      Icon(Icons.arrow_forward_ios, color: AppColors.appamber),
                  onTap: () {
                    if (_isProcessingTap) return;
                    _isProcessingTap = true;

                    widget.audioService.savePlaybackState();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryHymns(
                          categoryName: categoryName,
                          audioService: widget.audioService,
                        ),
                      ),
                    ).then((_) {
                      widget.audioService.resumePlaybackAfterNavigation();
                      _isProcessingTap = false;
                    });
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class FavoritesList extends StatefulWidget {
  final HymnsCubit hymnsCubit;
  final bool isAdmin;
  final VoidCallback? onFavoriteChanged;

  const FavoritesList({
    Key? key,
    required this.hymnsCubit,
    required this.isAdmin,
    this.onFavoriteChanged,
  }) : super(key: key);

  @override
  _FavoritesListState createState() => _FavoritesListState();
}

class _FavoritesListState extends State<FavoritesList>
    with AutomaticKeepAliveClientMixin {
  // إضافة مفتاح للتحكم في إعادة البناء
  final ValueNotifier<int> _refreshNotifier = ValueNotifier<int>(0);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // تحميل المفضلة عند بدء الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // تعيين سياق قائمة التشغيل إلى 'favorites'
        widget.hymnsCubit.setCurrentPlaylistType('favorites');
        widget.hymnsCubit.setCurrentPlaylistId(null);
        print('📋 تم تسجيل سياق قائمة المفضلة عند بدء الصفحة');

        // تحميل المفضلة
        widget.hymnsCubit.loadFavorites();
      }
    });
  }

  // دالة لإعادة تحميل المفضلة
  void refreshFavorites() {
    if (mounted) {
      print('🔄 إعادة تحميل المفضلة...');
      widget.hymnsCubit.loadFavorites().then((_) {
        if (mounted) {
          _refreshNotifier.value++;
          setState(() {});
          print('✅ تم تحديث قائمة المفضلة');
        }
      });
    }
  }

  @override
  void dispose() {
    _refreshNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ValueListenableBuilder<int>(
      valueListenable: _refreshNotifier,
      builder: (context, refreshCount, child) {
        return BlocBuilder<HymnsCubit, List<HymnsModel>>(
          builder: (context, state) {
            final favorites = widget.hymnsCubit.getFavorites();

            print('📋 عرض المفضلة: ${favorites.length} ترنيمة}');

            if (favorites.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border,
                        color: AppColors.appamber, size: 60),
                    SizedBox(height: 16),
                    Text(
                      'لا توجد ترانيم في المفضلة',
                      style: TextStyle(color: AppColors.appamber, fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'أضف ترانيمك المفضلة من قائمة الترانيم',
                      style:
                          TextStyle(color: AppColors.appamber.withOpacity(0.7)),
                    ),
                  ],
                ),
              );
            }

            // تحديث بيانات المفضلة من قاعدة البيانات لضمان الحصول على أحدث البيانات
            return FutureBuilder<List<HymnsModel>>(
              future: _getUpdatedFavorites(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final updatedFavorites = snapshot.data ?? favorites;

                // إضافة padding في الأسفل لإفساح المجال لمشغل الترانيم والإعلان
                return Padding(
                  padding: EdgeInsets.only(
                      bottom:
                          120), // قيمة تقريبية لإفساح المجال للمشغل والإعلان
                  child: GeneralHymnsList(
                    key: ValueKey('favorites_list_$refreshCount'),
                    hymnsCubit: widget.hymnsCubit,
                    isAdmin: widget.isAdmin,
                    hymns: updatedFavorites,
                    playlistType: 'favorites',
                    showAllControls: true, // التأكد من عرض جميع الأزرار
                    onFavoriteChanged: () {
                      print('🔄 تم تغيير المفضلة، إعادة تحميل...');
                      refreshFavorites();
                      if (widget.onFavoriteChanged != null) {
                        widget.onFavoriteChanged!();
                      }
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // إضافة دالة لجلب البيانات المحدثة للمفضلة
  Future<List<HymnsModel>> _getUpdatedFavorites() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      // جلب قائمة المفضلة
      final favoritesSnapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: user.uid)
          .get();

      if (favoritesSnapshot.docs.isEmpty) return [];

      List<HymnsModel> updatedFavorites = [];

      // جلب تفاصيل كل ترنيمة مفضلة
      for (var favoriteDoc in favoritesSnapshot.docs) {
        final hymnId = favoriteDoc.data()['hymnId'] as String;

        try {
          final hymnDoc = await FirebaseFirestore.instance
              .collection('hymns')
              .doc(hymnId)
              .get();

          if (hymnDoc.exists) {
            final hymnData = hymnDoc.data()!;

            final hymn = HymnsModel(
              id: hymnDoc.id,
              songName: hymnData['songName'] ?? '',
              songUrl: hymnData['songUrl'] ?? '',
              songAlbum: hymnData['songAlbum'] ?? '',
              songCategory: hymnData['songCategory'] ?? '',
              views: hymnData['views'] ?? 0,
              albumImageUrl: hymnData['albumImageUrl'],
              youtubeUrl: hymnData['youtubeUrl'],
              dateAdded: hymnData['dateAdded'] != null
                  ? (hymnData['dateAdded'] as Timestamp).toDate()
                  : DateTime.now(),
            );

            updatedFavorites.add(hymn);
          }
        } catch (e) {
          print('❌ خطأ في جلب بيانات الترنيمة $hymnId: $e');
        }
      }

      print('✅ تم جلب ${updatedFavorites.length} ترنيمة مفضلة محدثة');
      return updatedFavorites;
    } catch (e) {
      print('❌ خطأ في جلب المفضلة المحدثة: $e');
      return widget.hymnsCubit.getFavorites();
    }
  }
}
