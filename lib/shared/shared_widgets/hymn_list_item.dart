import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/app_setting/views/edit_hymns.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class HymnListItem extends StatefulWidget {
  final HymnsModel hymn;
  final bool isPlaying;
  final bool isInFavorites;
  final bool isAdmin;
  final VoidCallback onTap;
  final Function(HymnsModel)? onDelete;
  final Function(HymnsModel)? onToggleFavorite;

  const HymnListItem({
    Key? key,
    required this.hymn,
    required this.isPlaying,
    this.isInFavorites = false,
    this.isAdmin = false,
    required this.onTap,
    this.onDelete,
    this.onToggleFavorite,
  }) : super(key: key);

  @override
  State<HymnListItem> createState() => _HymnListItemState();
}

class _HymnListItemState extends State<HymnListItem> {
  bool _isFavorite = false;
  bool _isCheckingFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  @override
  void didUpdateWidget(HymnListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hymn.id != widget.hymn.id) {
      _checkIfFavorite();
    }
  }

  Future<void> _checkIfFavorite() async {
    if (_isCheckingFavorite) return;

    _isCheckingFavorite = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isFavorite = false;
          _isCheckingFavorite = false;
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: user.uid)
          .where('hymnId', isEqualTo: widget.hymn.id)
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _isFavorite = snapshot.docs.isNotEmpty;
          _isCheckingFavorite = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في التحقق من حالة المفضلة: $e');
      if (mounted) {
        setState(() {
          _isCheckingFavorite = false;
        });
      }
    }
  }

  void _openYoutube(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }

  // تعديل دالة _buildPopupMenu لمنع فتح صفحة التعديل أكثر من مرة
  Widget _buildPopupMenu() {
    bool hasWatchOption = widget.hymn.youtubeUrl?.isNotEmpty == true;
    bool _isEditingInProgress = false;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert,
          color: hasWatchOption ? Colors.red : AppColors.appamber),
      onSelected: (value) async {
        if (value == "edit" && widget.isAdmin) {
          // منع فتح صفحة التعديل أكثر من مرة
          if (_isEditingInProgress) return;
          _isEditingInProgress = true;

          try {
            // الحصول على لقطة المستند أولاً ثم فتح شاشة التعديل
            final documentSnapshot = await FirebaseFirestore.instance
                .collection('hymns')
                .doc(widget.hymn.id)
                .get();

            if (!mounted) return;

            if (documentSnapshot.exists) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditHymns(
                    hymn: documentSnapshot,
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("لم يتم العثور على الترنيمة")),
              );
            }
          } catch (error) {
            print('❌ خطأ في الحصول على بيانات الترنيمة: $error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("حدث خطأ أثناء تحميل بيانات الترنيمة")),
              );
            }
          } finally {
            _isEditingInProgress = false;
          }
        } else if (value == "delete" && widget.onDelete != null) {
          widget.onDelete!(widget.hymn);
        } else if (value == "favorite" && widget.onToggleFavorite != null) {
          widget.onToggleFavorite!(widget.hymn);
          setState(() {
            _isFavorite = !_isFavorite;
          });
        } else if (value == "remove_favorite" &&
            widget.onToggleFavorite != null) {
          widget.onToggleFavorite!(widget.hymn);
          setState(() {
            _isFavorite = !_isFavorite;
          });
        } else if (value == "watch" &&
            widget.hymn.youtubeUrl?.isNotEmpty == true) {
          _openYoutube(widget.hymn.youtubeUrl!);
        }
      },
      itemBuilder: (context) {
        return [
          if (widget.isAdmin)
            PopupMenuItem(value: "edit", child: Text("تعديل")),
          if (widget.isAdmin)
            PopupMenuItem(value: "delete", child: Text("حذف")),
          if (!widget.isInFavorites)
            PopupMenuItem(
                value: "favorite",
                child: Row(
                  children: [
                    Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite ? Colors.red : null,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(_isFavorite
                        ? "تمت الإضافة للمفضلة"
                        : "إضافة إلى المفضلة"),
                  ],
                )),
          if (widget.isInFavorites)
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(
        color: widget.isPlaying
            ? AppColors.appamber.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isPlaying
              ? AppColors.appamber
              : AppColors.appamber.withOpacity(0.3),
          width: widget.isPlaying ? 2 : 1,
        ),
        boxShadow: widget.isPlaying
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
          widget.hymn.songName,
          style: TextStyle(
            color: AppColors.appamber,
            fontSize: 18,
            fontWeight: widget.isPlaying ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.right,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPopupMenu(),
            Icon(
                widget.isPlaying ? Icons.music_note : Icons.music_note_outlined,
                color: AppColors.appamber),
            SizedBox(width: 5),
            Text(
              "${widget.hymn.views}",
              style: TextStyle(color: AppColors.appamber),
            ),
          ],
        ),
        onTap: widget.onTap,
      ),
    );
  }
}
