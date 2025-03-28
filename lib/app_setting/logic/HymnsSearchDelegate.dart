import 'package:flutter/material.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';

class HymnsSearchDelegate extends SearchDelegate {
  final HymnsCubit hymnsCubit;

  HymnsSearchDelegate(this.hymnsCubit);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(icon: Icon(Icons.clear), onPressed: () => query = ""),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    var results = hymnsCubit.state
        .where((hymn) => hymn.songName.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (results.isEmpty) {
      return Center(
        child: Text(
          "لا توجد ترانيم تطابق البحث",
          style: TextStyle(color: AppColors.appamber),
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        var hymn = results[index];
        bool isPlaying = hymnsCubit.currentHymn?.id == hymn.id;

        return Container(
          margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isPlaying ? AppColors.appamber : AppColors.appamber.withOpacity(0.3),
              width: isPlaying ? 2 : 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15),
            trailing: Text(
              hymn.songName,
              style: TextStyle(color: AppColors.appamber, fontSize: 18),
              textAlign: TextAlign.right,
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.music_note, color: AppColors.appamber),
                SizedBox(width: 5),
                Text(
                  "${hymn.views}",
                  style: TextStyle(color: AppColors.appamber),
                ),
              ],
            ),
            onTap: () {
              hymnsCubit.audioService.setPlaylist(
                results.map((e) => e.songUrl).toList(),
                results.map((e) => e.songName).toList(),
              );
              hymnsCubit.playHymn(hymn);
              close(context, null);
            },
          ),
        );
      },
    );
  }
}
