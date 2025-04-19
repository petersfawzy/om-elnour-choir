import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/shared/shared_widgets/hymn_list_item.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';

/// مكون منفصل للتعامل مع قائمة الترانيم العامة
/// يوحد طريقة عرض الترانيم في تبويب الترانيم العامة
class GeneralHymnsList extends StatefulWidget {
  final HymnsCubit hymnsCubit;
  final bool isAdmin;
  final bool showAllControls;
  final List<HymnsModel>? hymns; // قائمة الترانيم المخصصة (اختياري)
  final String
      playlistType; // نوع قائمة التشغيل ('general', 'album', 'category', 'favorites')
  final String? playlistId; // معرف قائمة التشغيل (اختياري)

  const GeneralHymnsList({
    Key? key,
    required this.hymnsCubit,
    this.isAdmin = false,
    this.showAllControls = true,
    this.hymns,
    this.playlistType = 'general',
    this.playlistId,
  }) : super(key: key);

  @override
  _GeneralHymnsListState createState() => _GeneralHymnsListState();
}

class _GeneralHymnsListState extends State<GeneralHymnsList>
    with AutomaticKeepAliveClientMixin {
  bool _isProcessingTap = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    // تسجيل سياق قائمة التشغيل عند بدء الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_disposed) {
        // تعيين سياق قائمة التشغيل
        widget.hymnsCubit.setCurrentPlaylistType(widget.playlistType);
        widget.hymnsCubit.setCurrentPlaylistId(widget.playlistId);
        print(
            '📋 تم تسجيل سياق قائمة التشغيل ${widget.playlistType} عند بدء الصفحة');

        // حفظ سياق التشغيل في التخزين المؤقت
        widget.hymnsCubit.saveStateOnAppClose();
      }
    });
  }

  @override
  void didUpdateWidget(GeneralHymnsList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // تحديث سياق قائمة التشغيل إذا تغير
    if (oldWidget.playlistType != widget.playlistType ||
        oldWidget.playlistId != widget.playlistId) {
      widget.hymnsCubit.setCurrentPlaylistType(widget.playlistType);
      widget.hymnsCubit.setCurrentPlaylistId(widget.playlistId);
      print('📋 تم تحديث سياق قائمة التشغيل إلى ${widget.playlistType}');
    }
  }

  @override
  void dispose() {
    _disposed = true;

    // حفظ سياق التشغيل قبل الخروج من الصفحة
    if (!_disposed) {
      widget.hymnsCubit.saveStateOnAppClose();
      print('💾 تم حفظ سياق قائمة التشغيل عند الخروج من الصفحة');
    }

    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  /// دالة موحدة لتشغيل الترانيم في القائمة
  Future<void> _playHymnFromList(
      HymnsModel hymn, List<HymnsModel> hymns, int index) async {
    if (_isProcessingTap || _disposed) return;

    setState(() {
      _isProcessingTap = true;
    });

    try {
      print(
          '🎵 تشغيل ترنيمة من قائمة ${widget.playlistType}: ${hymn.songName} (${hymn.id})');
      print('🔍 رابط الترنيمة: ${hymn.songUrl}');
      print('📋 إجمالي الترانيم في القائمة: ${hymns.length}');
      print('📊 فهرس الترنيمة المحددة: $index');

      // تعيين سياق التشغيل - تأكد من عدم تغييره إذا كان نفس النوع والمعرف
      final currentType = widget.hymnsCubit.currentPlaylistType;
      final currentId = widget.hymnsCubit.currentPlaylistId;

      if (currentType != widget.playlistType ||
          currentId != widget.playlistId) {
        widget.hymnsCubit.setCurrentPlaylistType(widget.playlistType);
        widget.hymnsCubit.setCurrentPlaylistId(widget.playlistId);
        print(
            '🔄 تم تعيين سياق التشغيل إلى ${widget.playlistType}: ${widget.playlistId ?? "null"}');
      } else {
        print(
            'ℹ️ سياق التشغيل لم يتغير: ${widget.playlistType}: ${widget.playlistId ?? "null"}');
      }

      // إيقاف التشغيل الحالي تمامًا
      await widget.hymnsCubit.audioService.stop();
      await Future.delayed(Duration(milliseconds: 300));

      // تحضير قوائم URLs و Titles
      List<String> urls = [];
      List<String> titles = [];
      List<int> validIndices = []; // لتتبع الفهارس الصالحة
      int validIndex = 0; // لتتبع الفهرس الصالح للترنيمة المحددة

      // إضافة جميع الترانيم إلى قائمة التشغيل
      for (int i = 0; i < hymns.length; i++) {
        var h = hymns[i];
        if (h.songUrl.isNotEmpty && h.songName.isNotEmpty) {
          urls.add(h.songUrl);
          titles.add(h.songName);
          validIndices.add(i);

          // تحديد الفهرس الصالح للترنيمة المحددة
          if (i == index) {
            validIndex = urls.length - 1;
          }
        }
      }

      if (urls.isEmpty) {
        print('⚠️ لا توجد ترانيم صالحة للتشغيل');
        setState(() {
          _isProcessingTap = false;
        });
        return;
      }

      print('📋 تم تحضير قائمة التشغيل: ${urls.length} ترنيمة');
      print('🔍 فهرس الترنيمة المحددة الصالح: $validIndex');

      // تعيين قائمة التشغيل الكاملة
      await widget.hymnsCubit.audioService.setPlaylist(urls, titles);
      await Future.delayed(Duration(milliseconds: 300));

      // تشغيل الترنيمة باستخدام الفهرس الصالح
      if (validIndex >= 0 && validIndex < urls.length) {
        // استخدام play مع الفهرس الصالح
        await widget.hymnsCubit.audioService
            .play(validIndex, titles[validIndex]);
        print('▶️ تم بدء تشغيل الترنيمة باستخدام الفهرس الصالح: $validIndex');
      } else {
        // استخدام playHymn كحل بديل
        await widget.hymnsCubit.playHymn(hymn, incrementViews: false);
        print('▶️ تم بدء تشغيل الترنيمة باستخدام playHymn كحل بديل');
      }

      // حفظ سياق التشغيل
      widget.hymnsCubit.saveStateOnAppClose();

      print('✅ تم تشغيل الترنيمة بنجاح');
    } catch (e) {
      print('❌ خطأ في تشغيل الترنيمة: $e');

      // محاولة بديلة باستخدام playFromBeginning
      try {
        print('🔄 محاولة طريقة بديلة');

        // تأكد من أن سياق التشغيل لا يزال صحيحًا
        widget.hymnsCubit.setCurrentPlaylistType(widget.playlistType);
        widget.hymnsCubit.setCurrentPlaylistId(widget.playlistId);

        // إيقاف التشغيل الحالي تمامًا
        await widget.hymnsCubit.audioService.stop();
        await Future.delayed(Duration(milliseconds: 300));

        // تعيين قائمة التشغيل مع الترنيمة المحددة فقط
        await widget.hymnsCubit.audioService
            .setPlaylist([hymn.songUrl], [hymn.songName]);
        await Future.delayed(Duration(milliseconds: 300));

        // استخدام playFromBeginning
        await widget.hymnsCubit.audioService
            .playFromBeginning(0, hymn.songName);
        print('▶️ تم تشغيل الترنيمة باستخدام طريقة بديلة');

        // تأكيد على حفظ سياق التشغيل
        widget.hymnsCubit.saveStateOnAppClose();
      } catch (e2) {
        print('❌ فشلت جميع الطرق: $e2');

        // عرض رسالة خطأ للمستخدم
        if (mounted && !_disposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('حدث خطأ أثناء تشغيل الترنيمة. يرجى المحاولة مرة أخرى.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      // زيادة التأخير قبل إعادة تعيين علامة المعالجة
      Future.delayed(Duration(milliseconds: 1000), () {
        if (mounted && !_disposed) {
          setState(() {
            _isProcessingTap = false;
          });
        } else {
          _isProcessingTap = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // إذا تم توفير قائمة ترانيم مخصصة، استخدمها
    if (widget.hymns != null) {
      return _buildHymnsList(widget.hymns!);
    }

    // وإلا استخدم قائمة الترانيم من HymnsCubit
    return BlocConsumer<HymnsCubit, List<HymnsModel>>(
      listener: (context, state) {
        // Solo para actualizaciones
      },
      builder: (context, state) {
        return _buildHymnsList(state);
      },
    );
  }

  // دالة مساعدة لبناء قائمة الترانيم
  Widget _buildHymnsList(List<HymnsModel> hymns) {
    if (hymns.isEmpty) {
      return Center(
        child: Text(
          "لا توجد ترانيم في هذه القائمة",
          style: TextStyle(color: AppColors.appamber),
        ),
      );
    }

    return ValueListenableBuilder<String?>(
      valueListenable: widget.hymnsCubit.audioService.currentTitleNotifier,
      builder: (context, currentTitle, child) {
        return ListView.builder(
          key: PageStorageKey('hymnsList_${widget.playlistType}'),
          padding: EdgeInsets.only(bottom: 20),
          itemCount: hymns.length,
          itemBuilder: (context, index) {
            var hymn = hymns[index];
            bool isPlaying = currentTitle == hymn.songName;

            return HymnListItem(
              hymn: hymn,
              isPlaying: isPlaying,
              isAdmin: widget.isAdmin,
              onTap: () => _playHymnFromList(hymn, hymns, index),
              onDelete: widget.showAllControls && widget.isAdmin
                  ? (hymn) => widget.hymnsCubit.deleteHymn(hymn.id)
                  : null,
              onToggleFavorite: widget.showAllControls
                  ? (hymn) => widget.hymnsCubit.toggleFavorite(hymn)
                  : null,
            );
          },
        );
      },
    );
  }
}
