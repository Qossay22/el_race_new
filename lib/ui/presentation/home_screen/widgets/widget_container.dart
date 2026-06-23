import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/screens/custom_swipe_button.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/list_view_widgets.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/my_actions_section.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/orientation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';

class WidgetContainer extends StatelessWidget {
  const WidgetContainer({super.key});

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = SharedPref.isUserAuthenticated();
    final loginData = SharedPref.getLoginData();
    final isCheckInWidgetDisabled = loginData
            .result?.data?.defaultWidgets?.data?.checkinWidget?.isDisabled ==
        true;
    final isSwipeEnabled = isAuthenticated && !isCheckInWidgetDisabled;

    return Container(
      //width: ScreenUtil().screenWidth,
      width: double.infinity,
      decoration: BoxDecoration(
        color: white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, -8), // shadow بس من فوق
          ),
        ],
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20.r),
          topLeft: Radius.circular(20.r),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: SizeConfig().getWidth(20)),
            child: Column(
              children: [
                SizedBox(height: 15.h),
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: SizeConfig().getWidth(20)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        translate('home.my_widgets'),
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF484848),
                        ),
                      ),
                      /* GestureDetector(
                        onTap: () =>
                            Util.pushPage(const EditWidgetsScreen(), context),
                        child: Text(
                          translate('home.edit'),
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF858585),
                          ),
                        ),
                      ),
                      */
                    ],
                  ),
                ),
                Opacity(
                  opacity: isSwipeEnabled ? 1 : 0.5,
                  child: SizedBox(
                    width: double.infinity,
                    height: 190.h,
                    child: Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(top: 6.h),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(23.r),
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: Image(
                                image: AssetImage(
                                  'assets/newapp/widgets_background.png',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                            // Gray theme overlay applied on top of the blue
                            // background once the user has swiped (checked in).
                            // Placed BELOW the curve overlay so the curve stays
                            // visible both before and after the swipe.
                            Positioned.fill(
                              child: IgnorePointer(
                                child: ValueListenableBuilder<bool>(
                                  valueListenable: swipeCheckedInNotifier,
                                  builder: (context, isCheckedIn, _) {
                                    return AnimatedOpacity(
                                      duration:
                                          const Duration(milliseconds: 260),
                                      curve: Curves.easeInOut,
                                      opacity: isCheckedIn ? 1.0 : 0.0,
                                      child: const DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF858995), // dark gray
                                              Color(0xFF9297A4), // light gray
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const Positioned.fill(
                              child: IgnorePointer(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Image(
                                    image: AssetImage(
                                      'assets/newapp/vector_curved_forswip_widget.png',
                                    ),
                                    fit: BoxFit.fitHeight,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: 32.h, horizontal: 35.w),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Swipe button
                                  IgnorePointer(
                                    ignoring: !isSwipeEnabled,
                                    child: const CustomSwipeButton(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
              ],
            ),
          ),
          const MyActionsSection(),
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: SizeConfig().getWidth(20)),
            child: Column(
              children: [
                SizedBox(height: 10.w),
                const ListViewWidgets(),

                // prayer times card
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AiSupportWidget extends StatefulWidget {
  const AiSupportWidget({super.key});

  @override
  State<AiSupportWidget> createState() => _AiSupportWidgetState();
}

class _AiSupportWidgetState extends State<AiSupportWidget> {
  bool _tapped = false;
  int _tapVersion = 0;

  Future<void> _showComingSoonForFiveSeconds() async {
    final currentTap = ++_tapVersion;
    if (mounted) {
      setState(() => _tapped = true);
    }

    await Future.delayed(const Duration(seconds: 5));

    if (!mounted || currentTap != _tapVersion) return;
    setState(() => _tapped = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showComingSoonForFiveSeconds,
      child: Container(
        width: double.infinity,
        height: 170.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: Color(0x596B3FA0),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.r),
          child: Stack(
            children: [
              // GIF as full background
              Positioned.fill(
                child: Image.asset(
                  'assets/gif/ai.gif',
                  fit: BoxFit.cover,
                ),
              ),

              // Dark overlay so text stays readable
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF1A1040).withOpacity(0.72),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Animated label top-left
              Positioned(
                top: 14.h,
                left: 22.w,
                right: 22.w,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    ));
                    return SlideTransition(
                      position: slide,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: _tapped
                      ? Align(
                          key: const ValueKey('coming'),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Coming Soon',
                            textAlign: TextAlign.left,
                            style: GoogleFonts.poppins(
                              fontSize: 26.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      : Align(
                          key: const ValueKey('ai'),
                          alignment: Alignment.centerLeft,
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Ai ',
                                  style: GoogleFonts.poppins(
                                    fontSize: 32.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                TextSpan(
                                  text: 'support',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xD9FFFFFF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
