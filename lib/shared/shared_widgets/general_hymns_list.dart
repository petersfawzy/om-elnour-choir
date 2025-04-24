import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/shared/shared_widgets/hymn_list_item.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';

/// مكون منفصل للتعامل مع قائمة الترانيم العامة
class GeneralHymnsList extends StatefulWidget {
  final HymnsCubit hymnsCubit;
  final bool isAdmin;
  final bool showAllControls;
  final List<HymnsModel>? hymns;
  final String playlistType;
  final String? playlistId;

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
  // Track last tap time
  DateTime? _lastTapTime;
  // Track last played hymn ID to prevent playing the same hymn repeatedly
  String? _lastPlayedHymnId;

  @override
  void initState() {
    super.initState();

    // Register playlist context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_disposed) {
        widget.hymnsCubit.setCurrentPlaylistType(widget.playlistType);
        widget.hymnsCubit.setCurrentPlaylistId(widget.playlistId);
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  // Improved method to play hymn from list
  Future<void> _playHymnFromList(
      HymnsModel hymn, List<HymnsModel> hymns, int index) async {
    // Check time since last tap to prevent rapid taps
    final now = DateTime.now();
    if (_lastTapTime != null) {
      final difference = now.difference(_lastTapTime!);
      if (difference.inMilliseconds < 800) {
        print(
            '⚠️ Tap too soon after previous tap (${difference.inMilliseconds}ms), ignoring');
        return;
      }
    }

    // Update last tap time
    _lastTapTime = now;

    // If it's the same hymn that's already playing, don't restart it
    if (_lastPlayedHymnId == hymn.id &&
        widget.hymnsCubit.audioService.isPlayingNotifier.value) {
      print('⚠️ This hymn is already playing, ignoring tap');
      return;
    }

    // Allow playing a different hymn even if we're processing a previous tap
    if (_isProcessingTap && _lastPlayedHymnId != hymn.id) {
      print('🔄 Processing previous tap, but allowing new hymn selection');
      // Continue with playback
    } else if (_isProcessingTap) {
      print('⚠️ Still processing previous tap, ignoring');
      return;
    }

    setState(() {
      _isProcessingTap = true;
    });
    print('🔄 Starting to process tap on hymn: ${hymn.songName}');

    try {
      print('🎵 Playing hymn: ${hymn.songName} (${hymn.id})');

      // Stop current playback explicitly
      print('⏹️ Stopping current playback');
      await widget.hymnsCubit.audioService.stop();

      // Add a short delay to ensure playback has stopped completely
      await Future.delayed(Duration(milliseconds: 100));

      // Set playlist context
      widget.hymnsCubit.setCurrentPlaylistType(widget.playlistType);
      widget.hymnsCubit.setCurrentPlaylistId(widget.playlistId);

      // Set up playlist
      List<String> urls = hymns.map((h) => h.songUrl).toList();
      List<String> titles = hymns.map((h) => h.songName).toList();
      List<String?> artworkUrls = hymns.map((h) => h.albumImageUrl).toList();

      // Set the playlist
      await widget.hymnsCubit.audioService
          .setPlaylist(urls, titles, artworkUrls);

      // Find the correct index for the selected hymn in the playlist
      int correctIndex = hymns.indexWhere((h) => h.id == hymn.id);
      if (correctIndex == -1) {
        correctIndex = 0;
        print('⚠️ Hymn not found in list, using index 0');
      } else {
        print('✅ Found hymn at index: $correctIndex');
      }

      // Play the hymn directly
      print('▶️ Starting playback');
      await widget.hymnsCubit.audioService.play(correctIndex, hymn.songName);

      // Update last played hymn ID
      _lastPlayedHymnId = hymn.id;

      // Increment view count
      await widget.hymnsCubit.incrementHymnViews(hymn.id);

      print('✅ Hymn playback started successfully');
    } catch (e) {
      print('❌ Error playing hymn: $e');

      if (mounted && !_disposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('حدث خطأ أثناء تشغيل الترنيمة. يرجى المحاولة مرة أخرى.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Reset processing flag after a short delay
      Future.delayed(Duration(milliseconds: 300), () {
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

    // If custom hymns list is provided, use it
    if (widget.hymns != null) {
      return _buildHymnsList(widget.hymns!);
    }

    // Otherwise use hymns from HymnsCubit
    return BlocConsumer<HymnsCubit, List<HymnsModel>>(
      listener: (context, state) {},
      builder: (context, state) {
        return _buildHymnsList(state);
      },
    );
  }

  // Helper method to build hymns list
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
          key: PageStorageKey(
              'hymnsList_${widget.playlistType}_${widget.playlistId ?? "general"}'),
          padding: EdgeInsets.only(bottom: 20),
          itemCount: hymns.length,
          itemBuilder: (context, index) {
            var hymn = hymns[index];
            bool isPlaying = currentTitle == hymn.songName;

            // Add unique key for each item that includes view count to ensure updates
            return HymnListItem(
              key: ValueKey('hymn_${hymn.id}_${hymn.views}'),
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
