import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/orientation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class SaveConfirmationDialog extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const SaveConfirmationDialog({
    super.key,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: SizeConfig().getWidth(280),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: black.withAlpha((0.1 * 255).toInt()),
              spreadRadius: 2,
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            
            Text(
              'Save Changes',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF000F42),
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              'Do you want to save your widget changes?',
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: const Color(0xFF858585),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onSave,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A53),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Save',
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 