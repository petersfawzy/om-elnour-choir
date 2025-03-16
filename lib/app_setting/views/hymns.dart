import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // لإدارة المستخدمين
import 'package:om_elnour_choir/app_setting/views/CategoriesPage.dart';
import 'package:om_elnour_choir/app_setting/views/CategoryHymnsPage.dart';
import 'package:om_elnour_choir/services/AlbumDetails.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/ad_banner.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';
import 'package:om_elnour_choir/shared/shared_widgets/music_player_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'add_hymns.dart';
import 'edit_hymns.dart';

class HymnsPage extends StatefulWidget {
  const HymnsPage({super.key});

  @override
  _HymnsPageState createState() => _HymnsPageState();
}

class _HymnsPageState extends State<HymnsPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final Myaudioservice _audioService = Myaudioservice();
  late List<DocumentSnapshot> _hymns;
  late TabController _tabController;
  String _sortBy = 'dateAdded';
  bool _ascending = false;
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _hymnsSubscription;
  final FirebaseAuth _auth = FirebaseAuth.instance; // لإدارة المستخدمين

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);

    _searchController.addListener(() {
      setState(() {});
    });

    _audioService.init();

    Future.delayed(Duration(milliseconds: 300), () {
      if (_audioService.isPlayingNotifier.value) {
        _audioService.resume();
      }
    });

    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_audioService.currentIndexNotifier.value != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _hymnsSubscription?.cancel();
    _saveCurrentPosition();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _audioService.handleAppLifecycleState(state);
  }

  Future<void> _restoreLastPlayedState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    int? lastIndex = prefs.getInt('lastPlayedIndex');
    String? lastTitle = prefs.getString('lastPlayedTitle');
    int? lastPosition = prefs.getInt('lastPosition');
    bool isPlaying = prefs.getBool('isPlaying') ?? false;

    if (lastIndex != null && lastTitle != null) {
      _audioService.currentIndexNotifier.value = lastIndex;
      _audioService.currentTitleNotifier.value = lastTitle;

      if (_audioService.currentTitleNotifier.value == lastTitle) {
        if (lastPosition != null && lastPosition > 0) {
          await _audioService.play(lastIndex, lastTitle);
          _audioService.seek(Duration(seconds: lastPosition));
        } else {
          await _audioService.play(lastIndex, lastTitle);
        }
      } else {
        await _audioService.play(lastIndex, lastTitle);
      }

      if (!isPlaying) {
        _audioService.pause();
      }
    }
  }

  void _saveCurrentPosition() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int currentPosition = _audioService.positionNotifier.value.inSeconds;
    bool isPlaying = _audioService.isPlayingNotifier.value;

    await prefs.setInt('lastPosition', currentPosition);
    await prefs.setBool('isPlaying', isPlaying);
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) _searchController.clear();
    });
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Widget buildOption(String title, String value) {
              bool isSelected = _sortBy == value;
              bool isAscending = _ascending;
              IconData icon = isSelected
                  ? (isAscending ? Icons.arrow_upward : Icons.arrow_downward)
                  : Icons.swap_vert;

              return ListTile(
                title: Text(title, style: TextStyle(color: AppColors.appamber)),
                trailing: Icon(icon, color: AppColors.appamber),
                onTap: () {
                  setState(() {
                    if (_sortBy == value) {
                      _ascending = !_ascending;
                    } else {
                      _sortBy = value;
                      _ascending = true;
                    }
                  });
                  this.setState(() {});
                  Navigator.pop(context);
                },
              );
            }

            return Padding(
              padding: EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "ترتيب حسب:",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber),
                  ),
                  buildOption("التاريخ", "dateAdded"),
                  buildOption("عدد مرات الاستماع", "views"),
                  buildOption("الترتيب الأبجدي", "songName"),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser; // المستخدم الحالي

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: AppColors.appamber,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.appamber,
            tabs: [
              Tab(text: "Hymns"),
              Tab(text: "Albums"),
              Tab(text: "Categories"),
              Tab(text: "Favorites"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Column(
                  children: [
                    Expanded(child: _buildHymnsList(user)),
                    MusicPlayerWidget(audioService: _audioService),
                  ],
                ),
                _buildAlbumsGrid(),
                CategoriesWidget(
                  onCategorySelected: (String categoryName) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: AppColors.backgroundColor,
                      builder: (context) => SizedBox(
                        height: MediaQuery.of(context).size.height * 0.8,
                        child: CategoryHymnsWidget(
                          categoryName: categoryName,
                          audioService: _audioService,
                        ),
                      ),
                    );
                  },
                ),
                Column(
                  children: [
                    Expanded(child: _buildFavoritesList(user)),
                    MusicPlayerWidget(audioService: _audioService),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AdBanner(key: UniqueKey()),
    );
  }

  Widget _buildHymnsList(User? user) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('hymns')
          .orderBy(_sortBy, descending: !_ascending)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("❌ خطأ في تحميل الترانيم"));
        }

        _hymns = snapshot.data!.docs;

        List<DocumentSnapshot> filteredHymns = _hymns.where((hymn) {
          String title = hymn['songName'].toString();
          return title.contains(_searchController.text);
        }).toList();

        return ListView.builder(
          itemCount: filteredHymns.length,
          itemBuilder: (context, index) {
            var hymn = filteredHymns[index];
            String title = hymn['songName'];
            String? youtubeUrl = hymn['youtubeUrl'];
            int views = hymn['views'];
            bool isPlaying = _audioService.currentIndexNotifier.value == index;

            return ListTile(
              tileColor: isPlaying ? AppColors.appamber : null,
              title: Text(
                title,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: isPlaying
                      ? AppColors.backgroundColor
                      : AppColors.appamber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: (youtubeUrl != null && youtubeUrl.isNotEmpty)
                          ? Colors.red
                          : AppColors.appamber,
                    ),
                    color: AppColors.appamber,
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => EditHymns(hymn: hymn)),
                        );
                      } else if (value == 'delete') {
                        FirebaseFirestore.instance
                            .collection('hymns')
                            .doc(hymn.id)
                            .delete();
                      } else if (value == 'watch' && youtubeUrl != null) {
                        // فتح رابط اليوتيوب
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'favorite',
                        child: Text("مفضلة",
                            style: TextStyle(color: AppColors.backgroundColor)),
                        onTap: () async {
                          if (user != null) {
                            await _toggleFavorite(user.uid, hymn.id);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text("يجب تسجيل الدخول لإضافة إلى المفضلة"),
                              ),
                            );
                          }
                        },
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Text("تعديل",
                            style: TextStyle(color: AppColors.backgroundColor)),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text("حذف",
                            style: TextStyle(color: AppColors.backgroundColor)),
                        onTap: () async {
                          await FirebaseFirestore.instance
                              .collection('hymns')
                              .doc(hymn.id)
                              .delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("تم حذف الترنيمة بنجاح")),
                          );
                        },
                      ),
                      if (youtubeUrl != null && youtubeUrl.isNotEmpty)
                        PopupMenuItem(
                          value: 'watch',
                          child: Text("شاهد",
                              style:
                                  TextStyle(color: AppColors.backgroundColor)),
                        ),
                    ],
                  ),
                  SizedBox(width: 5),
                  Icon(Icons.music_note,
                      color:
                          isPlaying ? AppColors.backgroundColor : Colors.amber),
                  SizedBox(width: 5),
                  Text('$views',
                      style: TextStyle(
                          color: isPlaying
                              ? AppColors.backgroundColor
                              : Colors.amber)),
                ],
              ),
              onTap: () => _playHymn(index, hymn.id),
            );
          },
        );
      },
    );
  }

  Widget _buildFavoritesList(User? user) {
    if (user == null) {
      return Center(
        child: Text(
          "يجب تسجيل الدخول لعرض المفضلة",
          style: TextStyle(color: AppColors.appamber, fontSize: 18),
        ),
      );
    }

    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('userFavorites')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("❌ خطأ في تحميل الترانيم المفضلة"));
        }

        var favoriteHymns = snapshot.data!.docs;

        if (favoriteHymns.isEmpty) {
          return Center(
            child: Text(
              "لا توجد ترانيم مفضلة",
              style: TextStyle(color: AppColors.appamber, fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          itemCount: favoriteHymns.length,
          itemBuilder: (context, index) {
            var favorite = favoriteHymns[index];
            String hymnId = favorite['hymnId'];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('hymns')
                  .doc(hymnId)
                  .get(),
              builder: (context, hymnSnapshot) {
                if (hymnSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!hymnSnapshot.hasData || !hymnSnapshot.data!.exists) {
                  return ListTile(
                    title: Text("ترنيمة غير موجودة",
                        style: TextStyle(color: Colors.red)),
                  );
                }

                var hymn = hymnSnapshot.data!;
                String title = hymn['songName'];
                bool isPlaying =
                    _audioService.currentIndexNotifier.value == index;

                return ListTile(
                  tileColor: isPlaying ? Colors.amber : null,
                  title: Text(
                    title,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color:
                          isPlaying ? AppColors.backgroundColor : Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  leading: Icon(Icons.music_note,
                      color:
                          isPlaying ? AppColors.backgroundColor : Colors.amber),
                  onTap: () => _playHymn(index, hymn.id),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _toggleFavorite(String userId, String hymnId) async {
    final docRef = FirebaseFirestore.instance
        .collection('userFavorites')
        .doc('$userId-$hymnId');

    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تمت الإزالة من المفضلة")),
      );
    } else {
      await docRef.set({
        'userId': userId,
        'hymnId': hymnId,
        'isFavorite': true,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تمت الإضافة إلى المفضلة")),
      );
    }
  }

  void _playHymn(int index, String docId) {
    if (index < 0 || index >= _hymns.length) return;

    var hymn = _hymns[index];
    String title = hymn['songName'];
    String songUrl = hymn['songUrl'] ?? '';

    if (songUrl.isEmpty) {
      debugPrint("❌ Error: No song URL found for hymn: $title");
      return;
    }

    _audioService.seek(Duration.zero);

    _audioService.setPlaylist(
      _hymns.map((hymn) => hymn['songUrl'].toString()).toList(),
      _hymns.map((hymn) => hymn['songName'].toString()).toList(),
    );

    _audioService.play(index, title);

    FirebaseFirestore.instance
        .collection('hymns')
        .doc(docId)
        .update({'views': FieldValue.increment(1)});
  }

  _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.backgroundColor,
      title: _showSearch
          ? TextField(
              controller: _searchController,
              style: TextStyle(color: AppColors.appamber),
              decoration: InputDecoration(
                hintText: 'ابحث عن ترنيمة...',
                hintStyle: TextStyle(color: AppColors.appamber),
                border: InputBorder.none,
              ),
              autofocus: true,
              onChanged: (value) {
                setState(() {});
              },
            )
          : Text("Hymns", style: TextStyle(color: AppColors.appamber)),
      actions: _tabController.index == 0
          ? [
              if (_showSearch)
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.appamber),
                  onPressed: () {
                    setState(() {
                      _showSearch = false;
                      _searchController.clear();
                    });
                  },
                )
              else
                IconButton(
                  icon: Icon(Icons.search, color: AppColors.appamber),
                  onPressed: _toggleSearch,
                ),
              IconButton(
                icon: Icon(Icons.filter_list, color: AppColors.appamber),
                onPressed: _showFilterOptions,
              ),
              IconButton(
                icon: Icon(Icons.add, color: AppColors.appamber),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddHymns()),
                  );
                },
              ),
            ]
          : null,
      leading: BackBtn(),
    );
  }

  Widget _buildAlbumsGrid() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('albums').snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("❌ خطأ في تحميل الألبومات"));
        }

        var albums = snapshot.data!.docs;

        return GridView.builder(
          padding: EdgeInsets.all(10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.8,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            var album = albums[index];
            Map<String, dynamic> albumData =
                album.data() as Map<String, dynamic>? ?? {};
            String name = albumData['name'] ?? "ألبوم بدون اسم";
            String? imageUrl = albumData['image'];
            imageUrl = (imageUrl != null && imageUrl.isNotEmpty)
                ? imageUrl
                : 'assets/images/logo.png';

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AlbumDetails(
                      albumName: name,
                      audioService: _audioService,
                    ),
                  ),
                );
              },
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: imageUrl.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) => Icon(
                                Icons.broken_image,
                                color: Colors.red,
                                size: 50,
                              ),
                            )
                          : Image(
                              image: AssetImage(imageUrl),
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.appamber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
