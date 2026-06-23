import 'package:cached_network_image/cached_network_image.dart';
import 'package:el_race/data/models/announcement_details_model.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Reusable banner widget for displaying announcement details
/// with image background and text overlay
class AnnouncementBanner extends StatelessWidget {
  final AnnouncementDetailsModel announcement;
  final VoidCallback? onTap;
  final double? height;
  final BorderRadius? borderRadius;

  const AnnouncementBanner({
    super.key,
    required this.announcement,
    this.onTap,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final bannerHeight = height ?? 190.h;
    final bannerBorderRadius = borderRadius ??
        BorderRadius.only(
          topLeft: Radius.circular(23.r),
          topRight: Radius.circular(23.r),
          bottomRight: Radius.circular(23.r),
          bottomLeft: const Radius.circular(0),
        );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: bannerBorderRadius,
          gradient: LinearGradient(
            colors: [buttonLight, Colors.white, buttonDark],
          ),
        ),
        child: Stack(
          children: [
            // Background image + gradient clipped to banner shape
            ClipRRect(
              borderRadius: bannerBorderRadius,
              child: SizedBox(
                height: bannerHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildBackgroundImage(),
                    _buildGradientOverlay(),
                  ],
                ),
              ),
            ),

            // Text Content outside clip so it can expand freely
            _buildTextContent(context),
          ],
        ),
      ),
    );
  }

  /// Build background image with fallback
  Widget _buildBackgroundImage() {
    if (announcement.hasAttachment && announcement.attachmentUrl != null) {
      return CachedNetworkImage(
        imageUrl: announcement.attachmentUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: lightGrey,
          child: Center(
            child: CircularProgressIndicator(
              color: buttonDark,
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildFallbackBackground(),
      );
    } else {
      return _buildFallbackBackground();
    }
  }

  /// Build fallback background when no image is available
  Widget _buildFallbackBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A53),
            const Color(0xFF2D2D7A),
            buttonDark,
          ],
        ),
      ),
      child: Opacity(
        opacity: 0.1,
        child: Image.asset(
          'assets/png/carousal1.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const SizedBox(),
        ),
      ),
    );
  }

  /// Build gradient overlay for text readability
  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.3),
            Colors.black.withOpacity(0.6),
          ],
          stops: const [0.3, 0.7, 1.0],
        ),
      ),
    );
  }

  /// Build text content with overlay styling
  Widget _buildTextContent(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/png/news-liner-bg.png'),
            fit: BoxFit.fitWidth,
          ),
          borderRadius: BorderRadius.circular(2.r),
        ),
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            if (announcement.title.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Text(
                  announcement.title.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 1),
                        blurRadius: 6,
                        color: Colors.black.withAlpha((0.6 * 255).toInt()),
                      ),
                    ],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Announcement Text
            Text(
              announcement.announcementText,
              style: TextStyle(
                color: appFontColor,
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 6,
                    color: Colors.black.withAlpha((0.4 * 255).toInt()),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
