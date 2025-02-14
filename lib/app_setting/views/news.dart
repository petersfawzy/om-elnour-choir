import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/news_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/news_model.dart';
import 'package:om_elnour_choir/app_setting/logic/news_states.dart';
import 'package:om_elnour_choir/app_setting/views/Add_News.dart';
import 'package:om_elnour_choir/app_setting/views/edit_news.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';

class News extends StatefulWidget {
  const News({super.key});

  @override
  State<News> createState() => _NewsState();
}

class _NewsState extends State<News> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        leading: BackBtn(),
        title: Text(
          'News',
          style: TextStyle(color: Colors.amber),
        ),
        centerTitle: true,
        actions: [
          IconButton(
              onPressed: () {
                Navigator.push(
                    context, CupertinoPageRoute(builder: (_) => AddNews()));
              },
              icon: Icon(
                Icons.add,
                color: Colors.amber[200],
              ))
        ],
      ),
      body: BlocBuilder<NewsCubit, NewsStates>(
        builder: (context, state) => ListView(
          children: [
            for (int i =
                    BlocProvider.of<NewsCubit>(context).newsList.length - 1;
                i >= 0;
                i--)
              InkWell(
                onLongPress: () {
                  BlocProvider.of<NewsCubit>(context).deletNews(i);
                },
                child: Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.amber[200]),
                  margin: EdgeInsets.all(10),
                  padding: EdgeInsets.all(10),
                  child: ListTile(
                    title: Text(
                      BlocProvider.of<NewsCubit>(context).newsList[i].NewsTitle,
                      style: TextStyle(
                          color: AppColors.backgroundColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.edit),
                      color: AppColors.backgroundColor,
                      iconSize: 20,
                      onPressed: () {
                        Navigator.push(
                            context,
                            CupertinoPageRoute(
                                builder: (BuildContext _) => EditNews(
                                      newsModel:
                                          BlocProvider.of<NewsCubit>(context)
                                              .newsList[i],
                                    )));
                      },
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
