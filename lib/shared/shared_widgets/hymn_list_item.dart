import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:om_elnour_choir/app_setting/views/edit_hymns.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';

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
  bool _isProcessingAction = false;
  bool _isTogglingFavorite = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    // Set favorite state directly from the received property
    _isFavorite = widget.isInFavorites;

    // If not in favorites, check favorite status
    if (!widget.isInFavorites) {
      _checkIfFavorite();
    }
  }

  @override
  void didUpdateWidget(HymnListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update favorite state if the property changed
    if (widget.isInFavorites != oldWidget.isInFavorites) {
      setState(() {
        _isFavorite = widget.isInFavorites;
      });
    }

    // If hymn ID changed, check favorite status
    if (oldWidget.hymn.id != widget.hymn.id) {
      _checkIfFavorite();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Modified _checkIfFavorite to use HymnsCubit more efficiently
  Future<void> _checkIfFavorite() async {
    if (_isCheckingFavorite || widget.isInFavorites || _disposed) return;

    _isCheckingFavorite = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted && !_disposed) {
          setState(() {
            _isFavorite = false;
            _isCheckingFavorite = false;
          });
        }
        return;
      }

      // Use HymnsCubit to get favorite status (for performance)
      try {
        final hymnsCubit = context.read<HymnsCubit>();
        final isFavorite = await hymnsCubit.isHymnFavorite(widget.hymn.id);

        if (mounted && !_disposed) {
          setState(() {
            _isFavorite = isFavorite;
            _isCheckingFavorite = false;
          });
        }
        return;
      } catch (e) {
        print('⚠️ Could not use HymnsCubit, will query directly: $e');
      }

      // Direct Firestore query as fallback
      final snapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: user.uid)
          .where('hymnId', isEqualTo: widget.hymn.id)
          .limit(1)
          .get();

      if (mounted && !_disposed) {
        setState(() {
          _isFavorite = snapshot.docs.isNotEmpty;
          _isCheckingFavorite = false;
        });
      }
    } catch (e) {
      print('❌ Error checking favorite status: $e');
      if (mounted && !_disposed) {
        setState(() {
          _isCheckingFavorite = false;
        });
      }
    }
  }

  void _openYoutube(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('Cannot open: $url');
        if (mounted && !_disposed) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Cannot open link')));
        }
      }
    } catch (e) {
      print('❌ Error opening YouTube link: $e');
      if (mounted && !_disposed) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error opening link')));
      }
    }
  }

  // Simplified _toggleFavorite for more reliability
  Future<void> _toggleFavorite() async {
    if (_isProcessingAction || _isTogglingFavorite || _disposed) return;

    setState(() {
      _isTogglingFavorite = true;
    });

    try {
      if (widget.onToggleFavorite != null) {
        // Call the parent-provided function
        await widget.onToggleFavorite!(widget.hymn);

        // Update local favorite state directly
        if (mounted && !_disposed) {
          setState(() {
            _isFavorite = !_isFavorite;
          });
        }
      }
    } catch (e) {
      print('❌ Error toggling favorite: $e');
      if (mounted && !_disposed) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error updating favorites')));
      }
    } finally {
      // Short delay before resetting processing state
      await Future.delayed(Duration(milliseconds: 500));
      if (mounted && !_disposed) {
        setState(() {
          _isTogglingFavorite = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;

    // Calculate font sizes based on screen width
    final titleFontSize = screenWidth < 360
        ? 14.0
        : screenWidth < 600
            ? 16.0
            : 18.0;
    final viewsFontSize = screenWidth < 360
        ? 12.0
        : screenWidth < 600
            ? 13.0
            : 14.0;

    // Check screen orientation
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Calculate icon size based on screen width
    final iconSize = screenWidth * 0.05;

    // Check if YouTube URL exists
    final hasYoutubeUrl = widget.hymn.youtubeUrl?.isNotEmpty == true;

    return Container(
      margin: EdgeInsets.symmetric(
          vertical: screenWidth * 0.01, horizontal: screenWidth * 0.02),
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
      // Add Material for better tap effect
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            print('🎵 Hymn tapped: ${widget.hymn.songName}');
            // Call the function directly
            widget.onTap();
          },
          // Add long press function for admins
          onLongPress: widget.isAdmin
              ? () async {
                  if (_isProcessingAction || _disposed) return;

                  setState(() {
                    _isProcessingAction = true;
                  });

                  try {
                    final documentSnapshot = await FirebaseFirestore.instance
                        .collection('hymns')
                        .doc(widget.hymn.id)
                        .get();

                    if (!mounted || _disposed) return;

                    if (documentSnapshot.exists) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditHymns(
                            hymn: documentSnapshot,
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    print('❌ Error opening edit screen: $e');
                    if (mounted && !_disposed) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error trying to edit hymn")),
                      );
                    }
                  } finally {
                    if (mounted && !_disposed) {
                      setState(() {
                        _isProcessingAction = false;
                      });
                    }
                  }
                }
              : null,
          // Add ripple effect on tap
          splashColor: AppColors.appamber.withOpacity(0.1),
          highlightColor: AppColors.appamber.withOpacity(0.05),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.03,
              vertical: screenWidth * 0.01,
            ),
            trailing: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: screenWidth * 0.6, // Set maximum width for text
              ),
              child: Text(
                widget.hymn.songName,
                style: TextStyle(
                  color: AppColors.appamber,
                  fontSize: titleFontSize,
                  fontWeight:
                      widget.isPlaying ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                maxLines: isLandscape ? 1 : 2,
              ),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Add pulse effect for icon when playing
                widget.isPlaying
                    ? TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.8, end: 1.0),
                        duration: Duration(milliseconds: 800),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Icon(
                              Icons.music_note,
                              color: AppColors.appamber,
                              size: iconSize,
                            ),
                          );
                        },
                        // Repeat animation
                        onEnd: () {
                          if (mounted && !_disposed && widget.isPlaying) {
                            setState(() {});
                          }
                        },
                      )
                    : Icon(
                        Icons.music_note_outlined,
                        color: AppColors.appamber,
                        size: iconSize,
                      ),
                SizedBox(width: screenWidth * 0.01),
                Text(
                  "${widget.hymn.views}",
                  style: TextStyle(
                    color: AppColors.appamber,
                    fontSize: viewsFontSize,
                  ),
                ),

                SizedBox(width: screenWidth * 0.02),

                // Add YouTube icon if URL exists
                if (hasYoutubeUrl)
                  GestureDetector(
                    onTap: () {
                      if (widget.hymn.youtubeUrl != null) {
                        _openYoutube(widget.hymn.youtubeUrl!);
                      }
                    },
                    child: Icon(
                      Icons.videocam,
                      color: Colors.red,
                      size: iconSize,
                    ),
                  ),

                // Add delete button for admins
                if (widget.isAdmin && widget.onDelete != null)
                  Padding(
                    padding: EdgeInsets.only(left: screenWidth * 0.02),
                    child: GestureDetector(
                      onTap: () async {
                        if (_isProcessingAction || _disposed) return;

                        setState(() {
                          _isProcessingAction = true;
                        });

                        try {
                          // Show confirmation dialog before deletion
                          final shouldDelete = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Confirm Deletion'),
                                  content: Text(
                                      'Are you sure you want to delete this hymn?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: Text('Delete',
                                          style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;

                          if (shouldDelete) {
                            widget.onDelete!(widget.hymn);

                            // Show success message
                            if (mounted && !_disposed) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Hymn deleted successfully'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          print('❌ Error deleting hymn: $e');
                          if (mounted && !_disposed) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text("Error trying to delete hymn")),
                            );
                          }
                        } finally {
                          if (mounted && !_disposed) {
                            setState(() {
                              _isProcessingAction = false;
                            });
                          }
                        }
                      },
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.red.withOpacity(0.7),
                        size: iconSize,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
