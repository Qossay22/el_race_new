import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SizeConfig {
  static late bool isPortrait;
  static late bool isTablet;

  void init(BuildContext context) {
    ScreenUtil.init(context);

    double screenWidth = ScreenUtil().screenWidth;

    double tabletScreenWidthThreshold = 600.0;

    isTablet = screenWidth >= tabletScreenWidthThreshold;

    isPortrait = ScreenUtil().orientation == Orientation.portrait;
  }

  double getHeight(double size) {
    return !isTablet ? size.h : size.h * 0.8;
  }

  double getWidth(double size) {
    return !isTablet ? size.w : size.w * 0.8;
  }

  double getTextSize(double size) {
    return !isTablet ? size.sp : size.sp * 0.7;
  }
}
