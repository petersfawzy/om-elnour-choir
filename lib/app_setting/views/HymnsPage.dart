import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/app_setting/logic/HymnsSearchDelegate.dart';
import 'package:om_elnour_choir/app_setting/views/add_hymns.dart';
import 'package:om_elnour_choir/services/AlbumDetails.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:om_elnour_choir/shared/shared_widgets/music_player_widget.dart';

class HymnsPage extends StatefulWidget {
  final MyAudioService audioService;

  const HymnsPage({super.key, required this.audioService});

  @override
  _HymnsPageState createState() => _HymnsPageState();
}

class _HymnsPageState extends State<HymnsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isAdmin = false;
  bool _isSearching = false;

  // ✅ استخدام ValueNotifier لتحديث الأزرار في AppBar
  final ValueNotifier<int> _currentTabIndexNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HymnsCubit>().restoreLastHymn();
    });
    _tabController = TabController(length: 4, vsync: this);

    // ✅ تحديث _currentTabIndexNotifier عند تغيير التبويب
    _tabController.addListener(() {
      _currentTabIndexNotifier.value = _tabController.index;
    });

    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          isAdmin = doc['role'] == 'admin';
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _currentTabIndexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hymnsCubit = context.read<HymnsCubit>();

    return Scaffold(
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
                  // تحديث نتائج البحث مباشرةً داخل تبويب الترانيم
                  hymnsCubit.searchHymns(query);
                },
              )
            : Text("الترانيم", style: TextStyle(color: AppColors.appamber)),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: _currentTabIndexNotifier,
            builder: (context, currentTabIndex, child) {
              if (currentTabIndex == 0) {
                // ✅ عرض الأزرار فقط في تبويب الترانيم
                return Row(
                  children: [
                    if (_isSearching)
                      IconButton(
                        icon: Icon(Icons.close, color: AppColors.appamber),
                        onPressed: () {
                          setState(() {
                            _isSearching = false;
                            _searchController.clear();
                            hymnsCubit.searchHymns(''); // إعادة القائمة الأصلية
                          });
                        },
                      )
                    else ...[
                      IconButton(
                        icon: Icon(Icons.search, color: AppColors.appamber),
                        onPressed: () {
                          setState(() {
                            _isSearching = true;
                          });
                        },
                      ),
                      IconButton(
                        icon:
                            Icon(Icons.filter_list, color: AppColors.appamber),
                        onPressed: _showFilterDialog,
                      ),
                      if (isAdmin)
                        IconButton(
                          icon: Icon(Icons.add, color: AppColors.appamber),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => AddHymns()),
                            );
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
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                  child: Text("Hymns",
                      style: TextStyle(color: AppColors.appamber))),
              Tab(
                  child: Text("Albums",
                      style: TextStyle(color: AppColors.appamber))),
              Tab(
                  child: Text("Categories",
                      style: TextStyle(color: AppColors.appamber))),
              Tab(
                  child: Text("Favorites",
                      style: TextStyle(color: AppColors.appamber))),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _HymnsList(hymnsCubit: hymnsCubit, isAdmin: isAdmin),
                AlbumsGrid(audioService: widget.audioService),
                CategoriesList(audioService: widget.audioService),
                FavoritesList(),
              ],
            ),
          ),
          MusicPlayerWidget(audioService: hymnsCubit.audioService),
          AdBanner(),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    // TODO: Implement filter dialog
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
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<HymnsCubit, List<HymnsModel>>(
      builder: (context, filteredHymns) {
        return ListView.builder(
          key: PageStorageKey('hymnsList'),
          itemCount: filteredHymns.length,
          itemBuilder: (context, index) {
            var hymn = filteredHymns[index];
            bool isPlaying = widget.hymnsCubit.currentHymn?.id == hymn.id;

            return Container(
              margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              decoration: BoxDecoration(
                color: isPlaying
                    ? AppColors.appamber.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isPlaying
                      ? AppColors.appamber
                      : AppColors.appamber.withOpacity(0.3),
                  width: isPlaying ? 2 : 1,
                ),
                boxShadow: isPlaying
                    ? [
                        BoxShadow(
                          color: AppColors.appamber.withOpacity(0.2),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                trailing: Text(
                  hymn.songName,
                  style: TextStyle(
                    color: AppColors.appamber,
                    fontSize: 18,
                    fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.right,
                ),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPopupMenu(hymn),
                    Icon(Icons.music_note, color: AppColors.appamber),
                    SizedBox(width: 5),
                    Text(
                      "${hymn.views}",
                      style: TextStyle(color: AppColors.appamber),
                    ),
                  ],
                ),
                onTap: () {
                  widget.hymnsCubit.audioService.setPlaylist(
                    filteredHymns.map((e) => e.songUrl).toList(),
                    filteredHymns.map((e) => e.songName).toList(),
                  );
                  widget.hymnsCubit.playHymn(hymn);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPopupMenu(HymnsModel hymn) {
    bool hasWatchOption = hymn.youtubeUrl?.isNotEmpty == true;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert,
          color: hasWatchOption ? Colors.red : AppColors.appamber),
      onSelected: (value) {
        if (value == "edit") {
          // تعديل
        } else if (value == "delete") {
          widget.hymnsCubit.deleteHymn(hymn.id);
        } else if (value == "favorite") {
          // إضافة إلى المفضلة
        } else if (value == "watch" && hymn.youtubeUrl?.isNotEmpty == true) {
          _openYoutube(hymn.youtubeUrl!);
        }
      },
      itemBuilder: (context) {
        return [
          if (widget.isAdmin)
            PopupMenuItem(value: "edit", child: Text("تعديل")),
          if (widget.isAdmin)
            PopupMenuItem(value: "delete", child: Text("حذف")),
          PopupMenuItem(value: "favorite", child: Text("إضافة إلى المفضلة")),
          if (hasWatchOption)
            PopupMenuItem(
              value: "watch",
              child: Text("مشاهدة", style: TextStyle(color: Colors.red)),
            ),
        ];
      },
    );
  }

  void _openYoutube(String url) {
    // TODO: Implement YouTube opening
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

        return ListView.builder(
          key: PageStorageKey('categoriesList'),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Container(
              margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.appamber.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ListTile(
                title: Text(
                  data['name'] ?? '',
                  style: TextStyle(
                    color: AppColors.appamber,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(
                  data['englishName'] ?? '',
                  style: TextStyle(
                    color: AppColors.appamber.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) => CategoryHymnsBottomSheet(
                      categoryName: data['name'],
                      audioService: widget.audioService,
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class CategoryHymnsBottomSheet extends StatelessWidget {
  final String? categoryName;
  final MyAudioService audioService;

  const CategoryHymnsBottomSheet({
    Key? key,
    required this.categoryName,
    required this.audioService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                categoryName ?? '',
                style: TextStyle(
                  color: AppColors.appamber,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('hymns')
                    .where('songCategory', isEqualTo: categoryName)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("❌ خطأ في تحميل الترانيم"));
                  }

                  final hymns = snapshot.data!.docs;
                  if (hymns.isEmpty) {
                    return Center(child: Text("لا توجد ترانيم في هذا التصنيف"));
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: hymns.length,
                    itemBuilder: (context, index) {
                      var hymn = hymns[index];
                      String title = hymn['songName'];
                      int views = hymn['views'];

                      return Container(
                        margin:
                            EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.appamber.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 15),
                          title: Text(
                            title,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: AppColors.appamber,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.music_note, color: AppColors.appamber),
                              const SizedBox(width: 5),
                              Text(
                                '$views',
                                style: TextStyle(color: AppColors.appamber),
                              ),
                            ],
                          ),
                          onTap: () {
                            List<String> urls = hymns
                                .map((h) => h['songUrl'] as String)
                                .toList();
                            List<String> titles = hymns
                                .map((h) => h['songName'] as String)
                                .toList();

                            audioService.setPlaylist(urls, titles);
                            audioService.play(index, titles[index]);

                            FirebaseFirestore.instance
                                .collection('hymns')
                                .doc(hymn.id)
                                .update({'views': FieldValue.increment(1)});

                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FavoritesList extends StatefulWidget {
  @override
  _FavoritesListState createState() => _FavoritesListState();
}

class _FavoritesListState extends State<FavoritesList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // جلب الترانيم المفضلة من Firestore
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text("❌ خطأ في تحميل قائمة المفضلة: ${snapshot.error}"),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              "📭 لا توجد ترانيم مفضلة",
              style: TextStyle(color: AppColors.appamber),
            ),
          );
        }

        var docs = snapshot.data!.docs;

        return ListView.builder(
          key: PageStorageKey('favoritesList'),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;

            String hymnId = doc.id;
            String songName = data['songName'] ?? 'بدون اسم';
            String songUrl = data['songUrl'] ?? '';
            int views = data['views'] ?? 0;

            return Container(
              margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.appamber.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                title: Text(
                  songName,
                  style: TextStyle(
                    color: AppColors.appamber,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.music_note, color: AppColors.appamber),
                    const SizedBox(width: 5),
                    Text(
                      '$views',
                      style: TextStyle(color: AppColors.appamber),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    // حذف الترنيمة من قائمة المفضلة
                    FirebaseFirestore.instance
                        .collection('favorites')
                        .doc(hymnId)
                        .delete();
                  },
                ),
                onTap: () {
                  // تشغيل الترنيمة
                  context.read<HymnsCubit>().audioService.setPlaylist(
                    [songUrl],
                    [songName],
                  );
                  context.read<HymnsCubit>().audioService.play(0, songName);

                  // زيادة عدد المشاهدات
                  FirebaseFirestore.instance
                      .collection('hymns')
                      .doc(hymnId)
                      .update({'views': FieldValue.increment(1)});
                },
              ),
            );
          },
        );
      },
    );
  }
}
