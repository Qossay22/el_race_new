import 'package:flutter/material.dart';

class AppColors {

  static const Color buttonColor = Color(0xffdcdcdc);
  static const Color appBarColor = Colors.transparent;
  static const Color accentColor = Color(0xff2d2c34);
  static const Color primaryBlack = Color(0xffffffff);
  static const Color primaryBlackLight = Color(0xffdcdcdc);
  static const Color textColor = Color(0xff000000);
  static const Color primaryWhite = Color(0xff000000);
  static const Color overlayContainerClr = Color(0xff2E2E2E);
  static const Color loaderColors = Color(0xff55bd94);


  static const Color primaryColor = Color(0xFF161B54);
  static const Color secondaryColor = Color(0xff333333);
  static const Color backgroundColor = Color(0xffFBFBFD);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF232323);
  static const Color blue = Color(0xFF161B54);
  static const Color lightBlue = Color(0xFFEEF2FA);
  static const Color chipColor = Color(0xFFEBECFB);
  static const Color dialogBg = Color(0xFFD9D9D9);


  static const Color transparent = Colors.transparent;
  static const Color grey = Color(0xFF848484);
  static const Color grayBottom = Color(0xFF393939);

  static const Color white10 = Color(0xffF2F2F2);
  static Color textPrimaryColor = fromHex('#999999');

  static Color textfldFillColor = fromHex('#F8F8F8');
  static Color textfldBorderColor = fromHex('#999999');
  static Color buttonDisableColor = fromHex('#C8C8C8');
  static const Color notificationCircleBg = Color(0xFFF6F2E9);
  static const Color notificationBg = Color(0xFFF0E7D5);
  static const Color languageBg = Color(0xFFFDF4EE);

  static const Color accepted = Color(0xFF7AA79E);
  static const Color acceptedBg = Color(0xFFEFF8F5);
  static const Color chatReceiverColor = Color(0xFFf1f1f1);
  static const Color chatSenderColor1 = Color(0xFFEBECFB);
  static const Color chatSenderColor2 = Color(0xFFDBEEF4);

  static const Color red = Color(0xFFD1002C);
  static const Color lightRed = Color(0xFFC13C38);
  static const Color error = Color(0xFFFF5A4E);
  static const Color green = Color(0xFF20B051);

  static const Color statusPending = Color(0xFFEF9400);
  static const Color statusCancelled = Color(0xFFFF5A4E);
  static const Color statusConfirmed = Color(0xFF277701);
  static const Color statusPaid = Color(0xFFE6FDDB);


  static Color fieldsHeadingColor = fromHex('#999999');
  static const Color fieldsBgColor = Color(0xFFF8F8F8);
  static const Color textFieldBorderColor = Color(0xFFEEEEEE);
  static const Color blackColor = Color(0xFF231F20);
  static Color separatorColor = fromHex('#D9D9D9');
  static Color barrierColor = fromHex('#333333');
  static Color dividerColor = fromHex('#E6E6E6');
  static Color bottomSheetDividerColor = fromHex('#F7F7F7');
  static const Color gray600 = Color(0xFF7c7c7e);

  static const Color classBg = Color(0xFFFBF9F4);
  static const Color classBg2 = Color(0xFFFBFBFB);

  static Color divider = fromHex('#3C3C435C');

  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
