import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../utils/color_utils.dart';
import '../../../../../../utils/dimens.dart';
import '../../../../../../utils/orientation_helper.dart';

class CardTile extends StatelessWidget {
  final int itemIndex;
  const CardTile({super.key, required this.itemIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160.h,
      width: 345.w,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          gradient: LinearGradient(
            colors: itemIndex.isOdd
                ? [buttonLight, Colors.white, buttonDark]
                : [lightGrey, darkGrey],
          )),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: SizeConfig().getWidth(40),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20.r),
                        bottomLeft: Radius.circular(20.r)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: itemIndex.isOdd
                          ? [
                              buttonLight,
                              buttonDark.withAlpha((0.2 * 255).toInt())
                            ]
                          : [lightGrey, darkGrey],
                    )),
                child: SizedBox(
                  height: 160.h,
                ),
              ),
              /*  SizedBox(
              height: 160,
              child: Row(
                children: [
                  Image.asset('assets/png/spike1.png'),
                  Image.asset('assets/png/spike2.png'),
                ],
              ),
            ),*/
              Container(
                width: SizeConfig().getWidth(40),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                        topRight: Radius.circular(20.r),
                        bottomRight: Radius.circular(20.r)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      colors: itemIndex.isOdd
                          ? [
                              buttonLight,
                              buttonDark.withAlpha((0.2 * 255).toInt())
                            ]
                          : [lightGrey, darkGrey],
                    )),
                child: SizedBox(
                  height: 160.h,
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                vertical: SizeConfig().getHeight(20),
                horizontal: SizeConfig().getWidth(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 23.h,
                      width: 45.w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5.r),
                        color: white,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white,
                            Colors.black
                                .withAlpha((0.3 * 255).toInt()), // Shadow color
                          ],
                          center: Alignment.center,
                          radius: 3,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.arrow_right,
                          color: shadowBlueDark,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      height: 40.h,
                      width: 40.w,
                      color: shadowBlueDark,
                      child: Icon(
                        size: SizeConfig().getTextSize(24),
                        Icons.access_time_filled_rounded,
                        color: white,
                      ),
                    ),
                    SizedBox(
                      width: 10.w,
                    ),
                    Text(
                      'My Title',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: SizeConfig().getTextSize(18),
                        color: shadowBlueDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GrayCardComponent extends StatelessWidget {
  const GrayCardComponent({
    super.key,
    this.mainIcon,
    this.onClick,
    required this.cardTitle,
    this.backgroundImagePath,
    this.backgroundFit = BoxFit.cover,
    this.gradient,
    required this.childWidget,
    this.upperCaseTitle = true,
    this.childAlignment = Alignment.topLeft,
    this.childPadding,
    this.topPadding = false,
    this.topPaddingValue = 60,
    this.titleColor,
  });
  final double? topPaddingValue;
  final bool topPadding;
  final String? mainIcon;
  final String? backgroundImagePath;
  final BoxFit backgroundFit;
  final Gradient? gradient;
  final VoidCallback? onClick;
  final String cardTitle;
  final Widget childWidget;
  final Color? titleColor;
  final bool upperCaseTitle;
  final Alignment childAlignment;
  final EdgeInsets? childPadding;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(23.r);

    return SizedBox(
      width: double.infinity,
      height: AppDimen.homeWidgetCardHeight.w,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onClick,
            child: gradient != null
                ? Ink(
                    decoration: BoxDecoration(
                      gradient: gradient,
                    ),
                    child: _buildContent(),
                  )
                : backgroundImagePath != null
                    ? Ink.image(
                        image: AssetImage(backgroundImagePath!),
                        fit: backgroundFit,
                        child: _buildContent(),
                      )
                    : Ink(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                        ),
                        child: _buildContent(),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Stack(
      children: [
        Positioned(
          left: 36.w,
          top: 16,
          child: SizedBox(
            height: SizeConfig().getHeight(43),
            child: Row(
              children: [
                // SizedBox(
                //   width: SizeConfig().getWidth(40.26),
                //   height: SizeConfig().getHeight(40.31),
                //   child: Image.asset(
                //     mainIcon,
                //     width: SizeConfig().getWidth(40),
                //     height: SizeConfig().getHeight(40),
                //   ),
                // ),
                // const SizedBox(width: 10),
                Text(
                  upperCaseTitle ? cardTitle.toUpperCase() : cardTitle,
                  style: GoogleFonts.poppins(
                    color: titleColor ?? const Color(0xFF151544),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.9,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: childPadding ??
                EdgeInsets.only(
                  left: 37.w,
                  top: topPadding ? (topPaddingValue ?? 60) : 30.h,
                ),
            child: Align(
              alignment: childAlignment,
              child: DefaultTextStyle(
                style: GoogleFonts.poppins(
                  fontSize: 12.w,
                  color: Colors.black,
                ),
                child: childWidget,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
