import 'package:flutter/material.dart';
import 'package:om_elnour_choir/services/MyAudioService.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';

class FavoritesList extends StatelessWidget {
  final MyAudioService audioService;

  const FavoritesList({
    super.key,
    required this.audioService,
  });

  @override
  Widget build(BuildContext context) {
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
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final hymn = favorites[index];
        return Container(
          margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          decoration: BoxDecoration(
            color: (audioService.currentTitleNotifier.value == hymn.songName) ? AppColors.appamber.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: (audioService.currentTitleNotifier.value == hymn.songName) ? AppColors.appamber : AppColors.appamber.withOpacity(0.3),
              width: (audioService.currentTitleNotifier.value == hymn.songName) ? 2 : 1,
            ),
            boxShadow: (audioService.currentTitleNotifier.value == hymn.songName) ? [
              BoxShadow(
                color: AppColors.appamber.withOpacity(0.2),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ] : null,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15),
            title: Text(
              hymn.songName,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.appamber,
                fontSize: 18,
                fontWeight: (audioService.currentTitleNotifier.value == hymn.songName) ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: Icon(
              Icons.favorite,
              color: AppColors.appamber,
            ),
            onTap: () {
              hymnsCubit.playHymn(hymn);
            },
          ),
        );
      },
    );
  }
} 