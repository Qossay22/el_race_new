import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:el_race/core/utils/shared_pref.dart';

class UserModeStatusWidget extends StatefulWidget {
  const UserModeStatusWidget({super.key});

  @override
  State<UserModeStatusWidget> createState() => _UserModeStatusWidgetState();
}

class _UserModeStatusWidgetState extends State<UserModeStatusWidget> {
  bool isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadOnlineState();
  }

  void _loadOnlineState() {
    setState(() {
      isOnline = SharedPref().getPreferenceBoolean('isOnline');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Status Text
        Text(
          isOnline ? 'you are now online' : 'you are now offline',
          style: GoogleFonts.poppins(
            fontSize: 17.sp,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            color: const Color.fromARGB(255, 20, 20, 63),
          ),
        ),
        const SizedBox(width: 4),
        // Toggle Container
        GestureDetector(
          onTap: () {
            setState(() {
              isOnline = !isOnline;
              SharedPref().setPreferencesBoolean('isOnline', isOnline);
            });
          },
          child: Container(
            width: 60.w,
            height: 20.w,
            decoration: BoxDecoration(
              color: isOnline ? red : Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // Toggle Icon
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: isOnline ? 36 : 2,
                  top: 2,
                  child: Container(
                    width: 17.w,
                    height: 17.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.circle,
                      size: 14.w,
                      color: red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
