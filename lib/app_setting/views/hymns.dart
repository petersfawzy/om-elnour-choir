import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_cubit.dart';
import 'package:om_elnour_choir/app_setting/logic/hymns_states.dart';
import 'package:om_elnour_choir/app_setting/views/add_hymns.dart';
import 'package:om_elnour_choir/app_setting/views/edit_hymns.dart';
import 'package:om_elnour_choir/shared/shared_theme/app_colors.dart';
import 'package:om_elnour_choir/shared/shared_widgets/bk_btm.dart';

class Hymns extends StatefulWidget {
  const Hymns({super.key});

  @override
  State<Hymns> createState() => _HymnsState();
}

class _HymnsState extends State<Hymns> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Hymns',
          style: TextStyle(color: Colors.amber),
        ),
        centerTitle: true,
        backgroundColor: AppColors.backgroundColor,
        leading: BackBtn(),
        actions: [
          IconButton(
              onPressed: () {
                Navigator.push(
                    context, CupertinoPageRoute(builder: (_) => AddHymns()));
              },
              icon: Icon(
                Icons.add,
                color: Colors.amber[200],
              ))
        ],
      ),
      body: BlocBuilder<HymnsCubit, HymnsStates>(
        builder: (context, state) => ListView(
          children: [
            for (int i =
                    BlocProvider.of<HymnsCubit>(context).hymnsList.length - 1;
                i >= 0;
                i--)
              InkWell(
                onLongPress: () {
                  BlocProvider.of<HymnsCubit>(context).deletHymn(i);
                },
                child: Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.amber[200]),
                  margin: EdgeInsets.all(10),
                  padding: EdgeInsets.all(10),
                  child: ListTile(
                    title: Text(
                      BlocProvider.of<HymnsCubit>(context).hymnsList[i].titel,
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
                                builder: (BuildContext _) => EditHymns(
                                    hymnsModel:
                                        BlocProvider.of<HymnsCubit>(context)
                                            .hymnsList[i])));
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
