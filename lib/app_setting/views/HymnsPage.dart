import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/app_setting/logic/HymnsSearchDelegate.dart';
import 'package:om_elnour_choir/app_setting/views/add_hymns.dart';
import 'package:om_elnour_choir/app_setting/views/edit_hymns.dart';
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
      // استعادة آخر ترنيمة بدون تشغيل تلقائي
      context.read<HymnsCubit>().restoreLastHymn();
      // تحميل قائمة المفضلة
      context.read<HymnsCubit>().loadFavorites();
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
                FavoritesList(hymnsCubit: hymnsCubit, isAdmin: isAdmin),
              ],
            ),
          ),
          MusicPlayerWidget(audioService: hymnsCubit.audioService),
          AdBanner(),
        ],
      ),
    );
  }

  // تعديل دالة _showFilterDialog لعرض خيارات الفلترة مع الحفاظ على الاختيارات السابقة
  void _showFilterDialog() {
    final hymnsCubit = context.read<HymnsCubit>();

    // استخدام القيم الحالية من HymnsCubit
    String sortBy = hymnsCubit.sortBy;
    bool descending = hymnsCubit.descending;
    String? selectedCategory = hymnsCubit.filterCategory;
    String? selectedAlbum = hymnsCubit.filterAlbum;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.backgroundColor,
              title: Text(
                "فلترة الترانيم",
                style: TextStyle(color: AppColors.appamber),
                textAlign: TextAlign.center,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // الترتيب حسب
                    Text(
                      "الترتيب حسب:",
                      style: TextStyle(
                          color: AppColors.appamber,
                          fontWeight: FontWeight.bold),
                    ),
                    RadioListTile<String>(
                      title: Text("تاريخ الإضافة",
                          style: TextStyle(color: AppColors.appamber)),
                      value: 'dateAdded',
                      groupValue: sortBy,
                      activeColor: AppColors.appamber,
                      onChanged: (value) {
                        setState(() {
                          sortBy = value!;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text("عدد المشاهدات",
                          style: TextStyle(color: AppColors.appamber)),
                      value: 'views',
                      groupValue: sortBy,
                      activeColor: AppColors.appamber,
                      onChanged: (value) {
                        setState(() {
                          sortBy = value!;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text("الاسم",
                          style: TextStyle(color: AppColors.appamber)),
                      value: 'songName',
                      groupValue: sortBy,
                      activeColor: AppColors.appamber,
                      onChanged: (value) {
                        setState(() {
                          sortBy = value!;
                        });
                      },
                    ),

                    // اتجاه الترتيب
                    Divider(color: AppColors.appamber.withOpacity(0.3)),
                    Text(
                      "اتجاه الترتيب:",
                      style: TextStyle(
                          color: AppColors.appamber,
                          fontWeight: FontWeight.bold),
                    ),
                    RadioListTile<bool>(
                      title: Text("تنازلي",
                          style: TextStyle(color: AppColors.appamber)),
                      value: true,
                      groupValue: descending,
                      activeColor: AppColors.appamber,
                      onChanged: (value) {
                        setState(() {
                          descending = value!;
                        });
                      },
                    ),
                    RadioListTile<bool>(
                      title: Text("تصاعدي",
                          style: TextStyle(color: AppColors.appamber)),
                      value: false,
                      groupValue: descending,
                      activeColor: AppColors.appamber,
                      onChanged: (value) {
                        setState(() {
                          descending = value!;
                        });
                      },
                    ),

                    // فلتر التصنيف
                    Divider(color: AppColors.appamber.withOpacity(0.3)),
                    Text(
                      "تصفية حسب التصنيف:",
                      style: TextStyle(
                          color: AppColors.appamber,
                          fontWeight: FontWeight.bold),
                    ),
                    FutureBuilder<List<String>>(
                      future: hymnsCubit.getAllCategories(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Text(
                            "لا توجد تصنيفات",
                            style: TextStyle(color: AppColors.appamber),
                          );
                        }

                        final categories = ['الكل', ...snapshot.data!];

                        return DropdownButton<String>(
                          value: selectedCategory != null &&
                                  categories.contains(selectedCategory)
                              ? selectedCategory
                              : 'الكل',
                          dropdownColor: AppColors.backgroundColor,
                          style: TextStyle(color: AppColors.appamber),
                          isExpanded: true,
                          onChanged: (value) {
                            setState(() {
                              selectedCategory = value == 'الكل' ? null : value;
                            });
                          },
                          items: categories.map((category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    // فلتر الألبوم
                    SizedBox(height: 10),
                    Text(
                      "تصفية حسب الألبوم:",
                      style: TextStyle(
                          color: AppColors.appamber,
                          fontWeight: FontWeight.bold),
                    ),
                    FutureBuilder<List<String>>(
                      future: hymnsCubit.getAllAlbums(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Text(
                            "لا توجد ألبومات",
                            style: TextStyle(color: AppColors.appamber),
                          );
                        }

                        final albums = ['الكل', ...snapshot.data!];

                        return DropdownButton<String>(
                          value: selectedAlbum != null &&
                                  albums.contains(selectedAlbum)
                              ? selectedAlbum
                              : 'الكل',
                          dropdownColor: AppColors.backgroundColor,
                          style: TextStyle(color: AppColors.appamber),
                          isExpanded: true,
                          onChanged: (value) {
                            setState(() {
                              selectedAlbum = value == 'الكل' ? null : value;
                            });
                          },
                          items: albums.map((album) {
                            return DropdownMenuItem<String>(
                              value: album,
                              child: Text(album),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text("إلغاء", style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text("تطبيق",
                      style: TextStyle(color: AppColors.appamber)),
                  onPressed: () {
                    // تطبيق الفلتر
                    hymnsCubit.changeSort(
                      sortBy,
                      descending,
                      filterCategory: selectedCategory,
                      filterAlbum: selectedAlbum,
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
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
  // إضافة متغير لمنع النقرات المتعددة السريعة
  bool _isProcessingTap = false;
  // تخزين مرجع للـ HymnsCubit
  late HymnsCubit _hymnsCubit;

  @override
  void initState() {
    super.initState();
    _hymnsCubit = widget.hymnsCubit;
  }

  @override
  bool get wantKeepAlive => true;

  // تعديل في دالة build لاستخدام _hymnsCubit بدلاً من widget.hymnsCubit
  @override
  Widget build(BuildContext context) {
    super.build(context);

    // استخدام BlocBuilder لإعادة بناء القائمة عند تغيير الحالة
    return BlocBuilder<HymnsCubit, List<HymnsModel>>(
      builder: (context, filteredHymns) {
        // استخدام ValueListenableBuilder لمراقبة تغييرات عنوان الترنيمة الحالية
        return ValueListenableBuilder<String?>(
            valueListenable: _hymnsCubit.audioService.currentTitleNotifier,
            builder: (context, currentTitle, child) {
              return ListView.builder(
                key: PageStorageKey('hymnsList'),
                itemCount: filteredHymns.length,
                itemBuilder: (context, index) {
                  var hymn = filteredHymns[index];

                  // تحديد ما إذا كانت هذه الترنيمة هي المشغلة حاليًا
                  // نقارن بين عنوان الترنيمة والعنوان الحالي في مشغل الصوت
                  bool isPlaying = currentTitle == hymn.songName ||
                      _hymnsCubit.currentHymn?.id == hymn.id;

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
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 15),
                      trailing: Text(
                        hymn.songName,
                        style: TextStyle(
                          color: AppColors.appamber,
                          fontSize: 18,
                          fontWeight:
                              isPlaying ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPopupMenu(
                              hymn, false), // false = not in favorites tab
                          Icon(
                              isPlaying
                                  ? Icons.music_note
                                  : Icons.music_note_outlined,
                              color: AppColors.appamber),
                          SizedBox(width: 5),
                          Text(
                            "${hymn.views}",
                            style: TextStyle(color: AppColors.appamber),
                          ),
                        ],
                      ),
                      onTap: () {
                        // تعيين علامة لمنع النقرات المتعددة السريعة
                        if (_isProcessingTap) return;
                        _isProcessingTap = true;

                        _hymnsCubit.audioService.setPlaylist(
                          filteredHymns.map((e) => e.songUrl).toList(),
                          filteredHymns.map((e) => e.songName).toList(),
                        );
                        _hymnsCubit.playHymn(hymn);

                        // إعادة تعيين العلامة بعد تأخير قصير
                        Future.delayed(Duration(milliseconds: 500), () {
                          if (mounted) {
                            // تحقق مما إذا كان Widget لا يزال مثبتًا
                            setState(() {
                              _isProcessingTap = false;
                            });
                          } else {
                            _isProcessingTap = false;
                          }
                        });
                      },
                    ),
                  );
                },
              );
            });
      },
    );
  }

  // تعديل دالة _buildPopupMenu في _HymnsListState لفتح صفحة التعديل
  Widget _buildPopupMenu(HymnsModel hymn, bool isInFavorites) {
    bool hasWatchOption = hymn.youtubeUrl?.isNotEmpty == true;

    return FutureBuilder<bool>(
        future: _hymnsCubit.isHymnFavorite(hymn.id),
        builder: (context, snapshot) {
          bool isFavorite = snapshot.data ?? false;

          return PopupMenuButton<String>(
            icon: Icon(Icons.more_vert,
                color: hasWatchOption ? Colors.red : AppColors.appamber),
            onSelected: (value) async {
              if (value == "edit") {
                // تنفيذ عملية التعديل
                try {
                  // الحصول على وثيقة الترنيمة من Firestore
                  DocumentSnapshot hymnDoc = await FirebaseFirestore.instance
                      .collection('hymns')
                      .doc(hymn.id)
                      .get();

                  if (hymnDoc.exists) {
                    // فتح صفحة التعديل مع تمرير وثيقة الترنيمة
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditHymns(hymn: hymnDoc),
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("لم يتم العثور على الترنيمة")),
                      );
                    }
                  }
                } catch (e) {
                  print('❌ خطأ في فتح صفحة التعديل: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text("حدث خطأ أثناء محاولة تعديل الترنيمة")),
                    );
                  }
                }
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
  // إضافة متغير لمنع النقرات المتعددة السريعة
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
                  // تعيين علامة لمنع النقرات المتعددة السريعة
                  if (_isProcessingTap) return;
                  _isProcessingTap = true;

                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) => CategoryHymnsBottomSheet(
                      categoryName: data['name'],
                      audioService: widget.audioService,
                    ),
                  );

                  // إعادة تعيين العلامة بعد تأخير قصير
                  Future.delayed(Duration(milliseconds: 500), () {
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

class CategoryHymnsBottomSheet extends StatelessWidget {
  final String? categoryName;
  final MyAudioService audioService;

  // إضافة متغير لمنع النقرات المتعددة السريعة
  final bool _isProcessingTap = false;

  CategoryHymnsBottomSheet({
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

                      // التحقق مما إذا كانت هذه الترنيمة هي المشغلة حاليًا
                      bool isPlaying =
                          audioService.currentTitleNotifier.value == title;

                      return Container(
                        margin:
                            EdgeInsets.symmetric(vertical: 5, horizontal: 10),
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
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 15),
                          title: Text(
                            title,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: AppColors.appamber,
                              fontSize: 18,
                              fontWeight: isPlaying
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  isPlaying
                                      ? Icons.music_note
                                      : Icons.music_note_outlined,
                                  color: AppColors.appamber),
                              const SizedBox(width: 5),
                              Text(
                                '$views',
                                style: TextStyle(color: AppColors.appamber),
                              ),
                            ],
                          ),
                          onTap: () {
                            // منع النقرات المتعددة السريعة
                            if (_isProcessingTap) return;

                            List<String> urls = hymns
                                .map((h) => h['songUrl'] as String)
                                .toList();
                            List<String> titles = hymns
                                .map((h) => h['songName'] as String)
                                .toList();

                            audioService.setPlaylist(urls, titles);
                            audioService.play(index, titles[index]);

                            // استخدام معاملة Firestore لتحديث عدد المشاهدات
                            FirebaseFirestore.instance
                                .runTransaction((transaction) async {
                              DocumentReference hymnRef = FirebaseFirestore
                                  .instance
                                  .collection('hymns')
                                  .doc(hymn.id);

                              DocumentSnapshot hymnSnapshot =
                                  await transaction.get(hymnRef);

                              if (!hymnSnapshot.exists) {
                                throw Exception("Hymn does not exist!");
                              }

                              int currentViews = (hymnSnapshot.data()
                                      as Map<String, dynamic>)['views'] ??
                                  0;

                              transaction
                                  .update(hymnRef, {'views': currentViews + 1});
                            });

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
  // إضافة متغير لمنع النقرات المتعددة السريعة
  bool _isProcessingTap = false;
  // تخزين مرجع للـ HymnsCubit
  late HymnsCubit _hymnsCubit;

  @override
  void initState() {
    super.initState();
    _hymnsCubit = widget.hymnsCubit;
  }

  @override
  bool get wantKeepAlive => true;

  // تعديل دالة _buildPopupMenu لتستخدم _hymnsCubit بدلاً من widget.hymnsCubit
  Widget _buildPopupMenu(HymnsModel hymn, bool isInFavorites) {
    bool hasWatchOption = hymn.youtubeUrl?.isNotEmpty == true;

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
          if (!isInFavorites)
            PopupMenuItem(
                value: "favorite",
                child: Row(
                  children: [
                    Icon(Icons.favorite_border, size: 18),
                    SizedBox(width: 8),
                    Text("إضافة إلى المفضلة"),
                  ],
                )),
          if (isInFavorites)
            PopupMenuItem(
                value: "remove_favorite",
                child: Row(
                  children: [
                    Icon(Icons.favorite, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text("إزالة من المفضلة"),
                  ],
                )),
          if (hasWatchOption)
            PopupMenuItem(
              value: "watch",
              child: Row(
                children: [
                  Icon(Icons.play_circle_outline, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text("مشاهدة", style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
        ];
      },
    );
  }

  // تعديل في دالة build لاستخدام _hymnsCubit بدلاً من widget.hymnsCubit
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
        final audioService = _hymnsCubit.audioService;

        return ListView.builder(
          key: PageStorageKey('favoritesList'),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;

            String hymnId = data['hymnId'] ?? '';
            String songName = data['songName'] ?? 'بدون اسم';
            String songUrl = data['songUrl'] ?? '';
            int views = data['views'] ?? 0;

            // إنشاء نموذج الترنيمة
            HymnsModel hymn = HymnsModel(
              id: hymnId,
              songName: songName,
              songUrl: songUrl,
              songCategory: data['songCategory'] ?? '',
              songAlbum: data['songAlbum'] ?? '',
              views: views,
              dateAdded:
                  (data['dateAdded'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );

            // التحقق مما إذا كانت هذه الترنيمة هي المشغلة حاليًا
            bool isPlaying =
                audioService.currentTitleNotifier.value == songName;

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
                title: Text(
                  songName,
                  style: TextStyle(
                    color: AppColors.appamber,
                    fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                    fontSize: 18,
                  ),
                ),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // استخدام نفس القائمة المنبثقة مع تمرير true لتوضيح أننا في تبويب المفضلة
                    _buildPopupMenu(hymn, true),
                    Icon(
                        isPlaying
                            ? Icons.music_note
                            : Icons.music_note_outlined,
                        color: AppColors.appamber),
                    const SizedBox(width: 5),
                    Text(
                      '$views',
                      style: TextStyle(color: AppColors.appamber),
                    ),
                  ],
                ),
                onTap: () {
                  // تعيين علامة لمنع النقرات المتعددة السريعة
                  if (_isProcessingTap) return;
                  _isProcessingTap = true;

                  // تشغيل الترنيمة
                  _hymnsCubit.audioService.setPlaylist(
                    [songUrl],
                    [songName],
                  );
                  _hymnsCubit.audioService.play(0, songName);

                  // زيادة عدد المشاهدات باستخدام معاملة Firestore
                  FirebaseFirestore.instance
                      .runTransaction((transaction) async {
                    DocumentReference hymnRef = FirebaseFirestore.instance
                        .collection('hymns')
                        .doc(hymnId);

                    DocumentSnapshot hymnSnapshot =
                        await transaction.get(hymnRef);

                    if (!hymnSnapshot.exists) {
                      throw Exception("Hymn does not exist!");
                    }

                    int currentViews = (hymnSnapshot.data()
                            as Map<String, dynamic>)['views'] ??
                        0;

                    transaction.update(hymnRef, {'views': currentViews + 1});
                  });

                  // إعادة تعيين العلامة بعد تأخير قصير
                  Future.delayed(Duration(milliseconds: 500), () {
                    if (mounted) {
                      // تحقق مما إذا كان Widget لا يزال مثبتًا
                      setState(() {
                        _isProcessingTap = false;
                      });
                    } else {
                      _isProcessingTap = false;
                    }
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  void _openYoutube(String url) {
    // TODO: Implement YouTube opening
  }
}
