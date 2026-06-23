import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';

import '../presentation/home_screen/bloc/home_bloc.dart';

class BackIcon extends StatelessWidget {
  const BackIcon({super.key});

  @override
  Widget build(BuildContext context) {
    var bloc = HomeBloc.get(context);
    return  Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        icon: Icon(LocalizedApp.of(context).delegate.currentLocale.languageCode != 'ar'?
        Icons.arrow_back:
        Icons.arrow_forward, color: appFontColor),
        onPressed: (){
          bloc.isNotOpen=false;
          Navigator.pop(context);
        },
      ),
    );
  }
}