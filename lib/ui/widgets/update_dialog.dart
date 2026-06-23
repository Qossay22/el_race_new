import 'dart:io';

import 'package:el_race/core/services/update_service.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows a force-update or optional-update dialog based on [UpdateCheckResult].
///
/// Usage:
/// ```dart
/// await UpdateDialog.showIfNeeded(context, result);
/// ```
class UpdateDialog extends StatelessWidget {
  final UpdateCheckResult result;
  final bool isRtl;

  const UpdateDialog({
    super.key,
    required this.result,
    this.isRtl = false,
  });

  // ── static helper ────────────────────────────────────────────────────────

  /// Displays the dialog if an update is required / available.
  ///
  /// Returns `true` if a force-update dialog was shown (navigation should stop),
  /// `false` otherwise.
  static Future<bool> showIfNeeded(
    BuildContext context,
    UpdateCheckResult result, {
    bool isRtl = false,
  }) async {
    if (!result.forceUpdate && !result.optionalUpdate) return false;

    final bool? dismissed = await showDialog<bool>(
      context: context,
      barrierDismissible: !result.forceUpdate,
      builder: (_) => UpdateDialog(result: result, isRtl: isRtl),
    );

    // Force update: user cannot dismiss → block navigation
    return result.forceUpdate;
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isForce = result.forceUpdate;
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';

    final title = isForce
        ? (isArabic ? 'تحديث إلزامي' : 'Required Update')
        : (isArabic ? 'تحديث متاح' : 'Update Available');

    final message = _resolveMessage(isArabic);

    final updateBtnLabel = isArabic ? 'تحديث الآن' : 'Update Now';
    final laterBtnLabel = isArabic ? 'لاحقاً' : 'Later';

    return PopScope(
      canPop: !isForce,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── icon ──
              Container(
                width: 64.r,
                height: 64.r,
                decoration: BoxDecoration(
                  color: isForce
                      ? const Color(0xFFFFEEEE)
                      : const Color(0xFFE8F0FE),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isForce ? Icons.system_update_alt_rounded : Icons.update_rounded,
                  size: 36.r,
                  color: isForce ? const Color(0xFFBA1719) : appFontColor,
                ),
              ),

              SizedBox(height: 16.h),

              // ── title ──
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: appFontColor,
                ),
              ),

              SizedBox(height: 10.h),

              // ── message ──
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF555555),
                  height: 1.5,
                ),
              ),

              // ── version badge ──
              if (result.latestVersion != null) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: appFontColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    'v${result.latestVersion}',
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: appFontColor,
                    ),
                  ),
                ),
              ],

              SizedBox(height: 24.h),

              // ── buttons ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Update button
                  ElevatedButton(
                    onPressed: () => _openStore(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appFontColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 13.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      updateBtnLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Optional: "Later" button
                  if (!isForce) ...[
                    SizedBox(height: 10.h),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        foregroundColor: const Color(0xFF888888),
                      ),
                      child: Text(
                        laterBtnLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── private helpers ──────────────────────────────────────────────────────

  String _resolveMessage(bool isArabic) {
    // Custom message from backend takes priority
    if (isArabic && (result.updateMessageAr?.isNotEmpty ?? false)) {
      return result.updateMessageAr!;
    }
    if (!isArabic && (result.updateMessageEn?.isNotEmpty ?? false)) {
      return result.updateMessageEn!;
    }

    if (result.forceUpdate) {
      return isArabic
          ? 'يتطلب هذا الإصدار تحديث التطبيق للمتابعة. يرجى تحديثه الآن.'
          : 'This version requires an app update to continue.\nPlease update now.';
    }
    return isArabic
        ? 'يتوفر إصدار جديد من التطبيق. يُنصح بالتحديث للحصول على أفضل تجربة.'
        : 'A new version is available.\nUpdate for the best experience.';
  }

  Future<void> _openStore(BuildContext context) async {
    final rawUrl = result.updateUrl ?? _defaultStoreUrl();
    final uri = Uri.parse(rawUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    // For force update we do NOT pop – user must update and restart the app
    if (!result.forceUpdate && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  String _defaultStoreUrl() {
    if (Platform.isIOS) {
      // Replace with your App Store ID
      return 'https://apps.apple.com/app/id0000000000';
    }
    return 'https://play.google.com/store/apps/details?id=com.el_race.app';
  }
}
