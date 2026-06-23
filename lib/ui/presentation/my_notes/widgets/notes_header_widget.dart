import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';

class NotesHeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onBackPressed;
  final VoidCallback? onAddPressed;
  final bool showAddButton;

  const NotesHeaderWidget({
    super.key,
    this.onBackPressed,
    this.onAddPressed,
    this.showAddButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      leading: BackButton(
        style: ButtonStyle(iconSize: WidgetStateProperty.all(30.w)),
      ),
      title: Text(
        translate('home.my_notes'),
        style: GoogleFonts.poppins(
          fontSize: 25.sp,
          fontWeight: FontWeight.w400,
          color: appFontColor,
          letterSpacing: 1.9,
        ),
      ),
      centerTitle: true,
      actions: showAddButton
          ? [
              InkWell(
                onTap: onAddPressed,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset('assets/png/add_note.png',
                      width: 40.w, height: 40.w),
                ),
              ),
            ]
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
