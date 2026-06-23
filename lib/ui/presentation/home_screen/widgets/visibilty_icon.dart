import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ArraowVisibalityBottomNav extends StatelessWidget {
  final double bottomMargin;
  const ArraowVisibalityBottomNav({super.key, this.bottomMargin = 125});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: BlocBuilder<HomeBloc, HomeState>(builder: (ctx, state) {
        var bloc = HomeBloc.get(ctx);
        return GestureDetector(
          onTap: () => bloc.add(const ChangeVisiablityIcon()),
          child: Container(
            alignment: Alignment.bottomRight,
            height: 55.w,
            width: 50.w,
            margin: EdgeInsets.only(bottom: bottomMargin.w - 20.w, right: 20.w,left: 20.w),
            child: !bloc.enableBottomNav
                ? Image.asset(
                    "assets/newapp/arrow_appear.png",
                    width: 45.w,
                  )
                : Image.asset(
                  "assets/newapp/arrow.png",
                  width: 45.w,
                ),
          ),
        );
      }),
    );
  }
}
