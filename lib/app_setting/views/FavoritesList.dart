import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/app_setting/views/edit_hymns.dart'; // إضافة استيراد ملف التعديل
import 'package:url_launcher/url_launcher.dart';

class FavoritesList extends StatefulWidget {
  final MyAudioService audioService;
  final bool isAdmin;

  const FavoritesList({
    super.key,
    required this.audioService,
    required this.isAdmin,
  });

  @override
  State<FavoritesList> createState() => _FavoritesListState();
}

class _FavoritesListState extends State<FavoritesList>
    with AutomaticKeepAliveClientMixin {
  // إضافة متغير لمنع النقرات المتعددة السريعة
  bool _isProcessingTap = false;

  @override
  bool get wantKeepAlive => true;

  // تعديل دالة build لتنسيق عرض الترنيمة بنفس طريقة تبويب الترانيم
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hymnsCubit = context.watch<HymnsCubit>();
    final favorites = hymnsCubit.getFavorites();

    if (favorites.isEmpty) {
      return Center(
        child: Text(
          "لا توجد ترانيم في المفضلة",
          style: TextStyle(color: AppColors.appamber),
        ),
      );
    }

    return ListView.builder(
      key: PageStorageKey('favoritesList'),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final hymn = favorites[index];
        bool isPlaying =
            widget.audioService.currentTitleNotifier.value == hymn.songName;

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
            // تغيير موضع العنوان ليكون في الجانب الأيمن (trailing) مثل تبويب الترانيم
            trailing: Text(
              hymn.songName,
              style: TextStyle(
                color: AppColors.appamber,
                fontSize: 18,
                fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.right,
            ),
            // تغيير موضع الأيقونات لتكون في الجانب الأيسر (title) مثل تبويب الترانيم
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPopupMenu(context, hymn, hymnsCubit),
                SizedBox(width: 10),
                Icon(isPlaying ? Icons.music_note : Icons.music_note_outlined,
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

              hymnsCubit.playHymn(hymn);

              // إعادة تعيين العلامة بعد تأخير قصير
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
          ),
        );
      },
    );
  }

  // إضافة دالة لبناء القائمة المنبثقة
  Widget _buildPopupMenu(
      BuildContext context, HymnsModel hymn, HymnsCubit hymnsCubit) {
    bool hasWatchOption = hymn.youtubeUrl?.isNotEmpty == true;

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
                SnackBar(content: Text("حدث خطأ أثناء محاولة تعديل الترنيمة")),
              );
            }
          }
        } else if (value == "delete") {
          hymnsCubit.deleteHymn(hymn.id);
        } else if (value == "remove_favorite") {
          hymnsCubit.toggleFavorite(hymn);
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

  void _openYoutube(String url) async {
    final Uri _url = Uri.parse(url);
    if (!await launchUrl(_url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $_url');
    }
  }
}
