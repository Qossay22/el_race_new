import 'package:el_race/core/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomTextStyle {
  static TextStyle heading = GoogleFonts.poppins().copyWith(
      fontSize: 14, fontWeight: FontWeight.w600, color: CustomColors.white);
  static TextStyle reportTitle = GoogleFonts.poppins().copyWith(
      fontSize: 13, fontWeight: FontWeight.w600, color: CustomColors.black);
  static TextStyle reportHeader = GoogleFonts.poppins().copyWith(
      fontSize: 12, fontWeight: FontWeight.w600, color: CustomColors.white);
  static TextStyle smallGrey = GoogleFonts.poppins().copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: CustomColors.lightBlack);
  static TextStyle smallWhite = GoogleFonts.poppins().copyWith(
      fontSize: 10, fontWeight: FontWeight.w600, color: CustomColors.white);
}
