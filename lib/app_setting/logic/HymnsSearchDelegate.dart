import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';

class HymnsSearchDelegate extends SearchDelegate {
  @override
  String get searchFieldLabel => "ابحث عن ترنيمة...";

  @override
  TextStyle get searchFieldStyle =>
      TextStyle(color: Colors.amber, fontSize: 16);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      textTheme: TextTheme(titleLarge: TextStyle(color: Colors.amber)),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundColor,
        iconTheme: IconThemeData(color: Colors.amber),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear, color: Colors.amber),
        onPressed: () {
          query = "";
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: Colors.amber),
      onPressed: () {
        close(context, null);
      },
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
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('hymns')
          .where('songName', isGreaterThanOrEqualTo: query)
          .where('songName', isLessThan: '$query\uf8ff')
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        var results = snapshot.data!.docs;

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            var hymn = results[index];
            return ListTile(
              title: Text(
                hymn['songName'],
                style: TextStyle(color: Colors.amber, fontSize: 18),
              ),
              onTap: () {
                close(context, hymn);
              },
            );
          },
        );
      },
    );
  }
}
