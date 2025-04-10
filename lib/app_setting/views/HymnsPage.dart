import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/app_setting/views/add_hymns.dart';
import 'package:om_elnour_choir/services/AlbumDetails.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:om_elnour_choir/shared/shared_widgets/music_player_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:om_elnour_choir/shared/shared_widgets/hymn_list_item.dart';

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

    Future.microtask(() {
      if (!_disposed) {
        _hymnsCubit.restoreLastHymn();
        _hymnsCubit.loadFavorites();
      }
    });

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_disposed) {
        _currentTabIndexNotifier.value = _tabController.index;
      }
    });

    _checkAdminStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;

    print('🔄 تغيرت حالة دورة حياة التطبيق في HymnsPage: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        print('📱 التطبيق عاد للمقدمة، استئناف التشغيل...');
        widget.audioService.resumePlaybackAfterNavigation();
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
          child: Column(
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
                    FavoritesList(hymnsCubit: hymnsCubit, isAdmin: isAdmin),
                  ],
                ),
              ),

              // مشغل الموسيقى - إضافة معالجة الأخطاء
              Builder(
                builder: (context) {
                  try {
                    return MusicPlayerWidget(
                        audioService: hymnsCubit.audioService);
                  } catch (e) {
                    print('❌ خطأ في بناء مشغل الموسيقى: $e');
                    return Container(
                      height: 80,
                      color: AppColors.backgroundColor,
                      child: Center(
                        child: Text(
                          'حدث خطأ في تحميل المشغل',
                          style: TextStyle(color: AppColors.appamber),
                        ),
                      ),
                    );
                  }
                },
              ),

              // الإعلان
              Container(
                height: 50, // ارتفاع ثابت للإعلان
                child: AdBanner(
                  key: UniqueKey(),
                  cacheKey: 'hymns_screen',
                  audioService: widget.audioService,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
  bool _isProcessingTap = false;
  late HymnsCubit _hymnsCubit;

  @override
  void initState() {
    super.initState();
    _hymnsCubit = widget.hymnsCubit;
  }

  @override
  bool get wantKeepAlive => true;

  void _openYoutube(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }

  Widget _buildPopupMenu(HymnsModel hymn, bool isInFavorites) {
    bool hasWatchOption = hymn.youtubeUrl?.isNotEmpty == true;

    return FutureBuilder<bool>(
        future: _hymnsCubit.isHymnFavorite(hymn.id),
        builder: (context, snapshot) {
          bool isFavorite = snapshot.data ?? false;

          return PopupMenuButton<String>(
            icon: Icon(Icons.more_vert,
                color: hasWatchOption ? Colors.red : AppColors.appamber),
            onSelected: (value) {
              if (value == "edit") {
                // تعديل
              } else if (value == "delete") {
                _hymnsCubit.deleteHymn(hymn.id);
              } else if (value == "favorite") {
                _hymnsCubit.toggleFavorite(hymn);
              } else if (value == "remove_favorite") {
                _hymnsCubit.toggleFavorite(hymn);
              } else if (value == "watch" &&
                  hymn.youtubeUrl?.isNotEmpty == true) {
                _openYoutube(hymn.youtubeUrl!);
              }
            },
            itemBuilder: (context) {
              return [
                if (widget.isAdmin)
                  PopupMenuItem(value: "edit", child: Text("تعديل")),
                if (widget.isAdmin)
                  PopupMenuItem(value: "delete", child: Text("حذف")),
                if (!isInFavorites)
                  PopupMenuItem(
                      value: "favorite",
                      child: Row(
                        children: [
                          Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : null,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(isFavorite
                              ? "تمت الإضافة للمفضلة"
                              : "إضافة إلى المفضلة"),
                        ],
                      )),
                if (isInFavorites)
                  PopupMenuItem(
                      value: "remove_favorite",
                      child: Row(
                        children: [
                          Icon(Icons.favorite_border, size: 18),
                          SizedBox(width: 8),
                          Text("إزالة من المفضلة"),
                        ],
                      )),
                if (hasWatchOption)
                  PopupMenuItem(
                    value: "watch",
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_outline,
                            color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text("مشاهدة", style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ];
            },
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<HymnsCubit, List<HymnsModel>>(
      builder: (context, filteredHymns) {
        return ValueListenableBuilder<String?>(
            valueListenable: _hymnsCubit.audioService.currentTitleNotifier,
            builder: (context, currentTitle, child) {
              return ListView.builder(
                key: PageStorageKey('hymnsList'),
                padding: EdgeInsets.only(bottom: 20),
                itemCount: filteredHymns.length,
                itemBuilder: (context, index) {
                  var hymn = filteredHymns[index];
                  bool isPlaying = currentTitle == hymn.songName;

                  return HymnListItem(
                    hymn: hymn,
                    isPlaying: isPlaying,
                    isAdmin: widget.isAdmin,
                    onTap: () {
                      if (_isProcessingTap) return;
                      _isProcessingTap = true;

                      _hymnsCubit.audioService.setPlaylist(
                        filteredHymns.map((e) => e.songUrl).toList(),
                        filteredHymns.map((e) => e.songName).toList(),
                      );
                      _hymnsCubit.playHymn(hymn);

                      Future.delayed(Duration(milliseconds: 500), () {
                        if (mounted) {
                          setState(() {
                            _isProcessingTap = false;
                          });
                        } else {
                          _isProcessingTap = false;
                        }
                      });
                    },
                    onDelete: (hymn) => _hymnsCubit.deleteHymn(hymn.id),
                    onToggleFavorite: (hymn) =>
                        _hymnsCubit.toggleFavorite(hymn),
                  );
                },
              );
            });
      },
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
  Widget build(BuildContext context) {
    super.build(context);
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

        return GridView.builder(
          key: PageStorageKey('albumsGrid'),
          padding: EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.75,
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
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 5,
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(10)),
                        child: albumImage.isNotEmpty
                            ? Image.network(albumImage, fit: BoxFit.cover)
                            : Image.asset('assets/images/logo.png',
                                fit: BoxFit.cover),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        albumName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.appamber,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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

        return ListView.builder(
          key: PageStorageKey('categoriesList'),
          padding: EdgeInsets.only(bottom: 20),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final doc = categories[index];
            final data = doc.data() as Map<String, dynamic>;
            final categoryName = data['name'] as String? ?? 'بدون اسم';

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
                  textAlign: TextAlign.center,
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
        );
      },
    );
  }
}

class FavoritesList extends StatefulWidget {
  final HymnsCubit hymnsCubit;
  final bool isAdmin;

  const FavoritesList(
      {Key? key, required this.hymnsCubit, required this.isAdmin})
      : super(key: key);

  @override
  _FavoritesListState createState() => _FavoritesListState();
}

class _FavoritesListState extends State<FavoritesList>
    with AutomaticKeepAliveClientMixin {
  bool _isProcessingTap = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.hymnsCubit.loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FutureBuilder<void>(
      future: widget.hymnsCubit.loadFavorites(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final favorites = widget.hymnsCubit.getFavorites();

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
                  style: TextStyle(color: AppColors.appamber.withOpacity(0.7)),
                ),
              ],
            ),
          );
        }

        return ValueListenableBuilder<String?>(
          valueListenable: widget.hymnsCubit.audioService.currentTitleNotifier,
          builder: (context, currentTitle, child) {
            return ListView.builder(
              key: PageStorageKey('favoritesList'),
              padding: EdgeInsets.only(bottom: 20),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                var hymn = favorites[index];
                bool isPlaying = currentTitle == hymn.songName;

                return HymnListItem(
                  hymn: hymn,
                  isPlaying: isPlaying,
                  isInFavorites: true,
                  isAdmin: widget.isAdmin,
                  onTap: () {
                    if (_isProcessingTap) return;
                    _isProcessingTap = true;

                    widget.hymnsCubit.audioService.setPlaylist(
                      favorites.map((e) => e.songUrl).toList(),
                      favorites.map((e) => e.songName).toList(),
                    );
                    widget.hymnsCubit.playHymn(hymn);

                    Future.delayed(Duration(milliseconds: 500), () {
                      if (mounted) {
                        setState(() {
                          _isProcessingTap = false;
                        });
                      } else {
                        _isProcessingTap = false;
                      }
                    });
                  },
                  onDelete: widget.isAdmin
                      ? (hymn) => widget.hymnsCubit.deleteHymn(hymn.id)
                      : null,
                  onToggleFavorite: (hymn) {
                    widget.hymnsCubit.toggleFavorite(hymn);
                    setState(() {}); // تحديث القائمة
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class CategoryHymns extends StatefulWidget {
  final String categoryName;
  final MyAudioService audioService;

  const CategoryHymns({
    Key? key,
    required this.categoryName,
    required this.audioService,
  }) : super(key: key);

  @override
  _CategoryHymnsState createState() => _CategoryHymnsState();
}

class _CategoryHymnsState extends State<CategoryHymns> {
  bool _isProcessingTap = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text(
          widget.categoryName,
          style: TextStyle(color: AppColors.appamber),
        ),
        leading: BackBtn(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // استخدام Expanded لملء المساحة المتاحة
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('hymns')
                    .where('songCategory', isEqualTo: widget.categoryName)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('خطأ في تحميل الترانيم'),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text('لا توجد ترانيم في هذا التصنيف'),
                    );
                  }

                  final hymns = snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return HymnsModel(
                      id: doc.id,
                      songName: data['songName'] ?? '',
                      songUrl: data['songUrl'] ?? '',
                      songCategory: data['songCategory'] ?? '',
                      songAlbum: data['songAlbum'] ?? '',
                      views: data['views'] ?? 0,
                      dateAdded: (data['dateAdded'] as Timestamp).toDate(),
                      youtubeUrl: data['youtubeUrl'],
                    );
                  }).toList();

                  return ValueListenableBuilder<String?>(
                    valueListenable: widget.audioService.currentTitleNotifier,
                    builder: (context, currentTitle, child) {
                      return ListView.builder(
                        padding: EdgeInsets.only(bottom: 20),
                        itemCount: hymns.length,
                        itemBuilder: (context, index) {
                          var hymn = hymns[index];
                          bool isPlaying = currentTitle == hymn.songName;

                          return HymnListItem(
                            hymn: hymn,
                            isPlaying: isPlaying,
                            onTap: () {
                              if (_isProcessingTap) return;
                              _isProcessingTap = true;

                              context
                                  .read<HymnsCubit>()
                                  .audioService
                                  .setPlaylist(
                                    hymns.map((e) => e.songUrl).toList(),
                                    hymns.map((e) => e.songName).toList(),
                                  );

                              context.read<HymnsCubit>().playHymn(hymn);

                              Future.delayed(Duration(milliseconds: 500), () {
                                if (mounted) {
                                  setState(() {
                                    _isProcessingTap = false;
                                  });
                                } else {
                                  _isProcessingTap = false;
                                }
                              });
                            },
                            onToggleFavorite: (hymn) =>
                                context.read<HymnsCubit>().toggleFavorite(hymn),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // مشغل الموسيقى
            MusicPlayerWidget(audioService: widget.audioService),

            // الإعلان
            Container(
              height: 50, // ارتفاع ثابت للإعلان
              child: AdBanner(
                key: UniqueKey(),
                cacheKey: 'category_hymns',
                audioService: widget.audioService,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
