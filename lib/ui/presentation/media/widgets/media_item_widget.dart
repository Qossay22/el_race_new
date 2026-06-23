import 'dart:io';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../utils/di.dart';
import '../data/media_model.dart';
import '../repository/i_media_repository.dart';

class MediaItemWidget extends StatelessWidget {
  final MediaModel media;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MediaItemWidget({
    super.key,
    required this.media,
    this.onTap,
    this.onLongPress,
  });

  Rect _shareOriginRect(BuildContext context) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final origin = box.localToGlobal(Offset.zero);
      final rect = origin & box.size;
      // Ensure non-zero rect (iOS requirement)
      if (rect.width > 0 && rect.height > 0) return rect;
    }
    // Fallback: center of screen
    final size = MediaQuery.of(context).size;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
  }

  Widget _buildThumbnail() {
    final String imageUrl = media.previewUrl;
    final borderRadius = BorderRadius.circular(18.r);
    const borderColor = Color(0xB8484848);

    Widget placeholder() {
      return Container(
        color: Colors.black.withOpacity(0.04),
        alignment: Alignment.center,
        child: Icon(
          media.isVideo ? Icons.play_circle_outline : Icons.image_outlined,
          size: 44.sp,
          color: appFontColor.withOpacity(0.55),
        ),
      );
    }

    Widget buildAssetImage() {
      return Image.asset(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => placeholder(),
      );
    }

    Widget buildNetworkImage() {
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => placeholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 22.w,
              height: 22.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    }

    final Widget inner = imageUrl.startsWith('assets/')
        ? buildAssetImage()
        : buildNetworkImage();

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: inner,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(22.r);
    const borderColor = Color(0xB8484848);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE6E6E6),
            borderRadius: borderRadius,
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 10.h, right: 14.w, left: 14.w),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Uploaded at ${DateFormat('dd/MM/yyyy').format(media.dateCreated)}',
                    style: GoogleFonts.poppins(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF6E6E6E),
                    ),
                    maxLines: null,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                child: SizedBox(
                  width: double.infinity,
                  height: 170.h,
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildThumbnail()),
                      if (media.isVideo)
                        Positioned.fill(
                          child: Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              size: 56.sp,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: 16.w,
                  right: 12.w,
                  bottom: 14.h,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            media.displayName,
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                            maxLines: null,
                            overflow: TextOverflow.visible,
                          ),
                          if (media.client != null &&
                              media.client!.trim().isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            Text(
                              media.client!,
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF6E6E6E),
                              ),
                              maxLines: null,
                              overflow: TextOverflow.visible,
                            ),
                          ],
                        ],
                      ),
                    ),
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () async {
                        await _shareMediaAsLink(context);
                      },
                      child: SizedBox(
                        width: 42.w,
                        height: 42.w,
                        child: Center(
                          child: Image.asset(
                            'assets/newapp/newicon/media_share_icon.png',
                            width: 40.w,
                            height: 24.h,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Share media with thumbnail and video URL
  Future<void> _shareMediaAsLink(BuildContext context) async {
    // Capture origin rect immediately (before async gaps invalidate context)
    final originRect = _shareOriginRect(context);
    try {
      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Preparing share...',
              style: GoogleFonts.poppins(),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      String? shareableUrl;

      // 1. Try to call prepare_share API to get the shareable URL
      try {
        final mediaRepository = sl.get<IMediaRepository>();
        shareableUrl = await mediaRepository.prepareShare(media.id);
      } catch (e) {
        // ignore, fallback below
      }

      // 2. If API failed, use x_web_url as fallback
      if (shareableUrl == null || shareableUrl.isEmpty) {
        shareableUrl = media.xWebUrl ?? media.streamingUrl;
      }

      // Trim whitespace and encode URL to handle spaces
      shareableUrl = shareableUrl.trim();

      // Parse and properly encode the URL to replace spaces with %20
      try {
        final uri = Uri.parse(shareableUrl);
        // Reconstruct URL with properly encoded path
        shareableUrl = uri
            .replace(
              path: uri.pathSegments
                  .map((segment) => Uri.encodeComponent(segment))
                  .join('/'),
            )
            .toString();
      } catch (e) {
        // Fallback: simple space replacement
        shareableUrl = shareableUrl!.replaceAll(' ', '%20');
      }

      if (shareableUrl.isEmpty) {
        throw Exception('No URL available to share');
      }

      // 3. Download the thumbnail image if available
      XFile? thumbnailFile;
      if (media.thumbnail != null && media.thumbnail!.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(media.thumbnail!));
          if (response.statusCode == 200) {
            final tempDir = await getTemporaryDirectory();
            final fileName =
                'share_thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final filePath = '${tempDir.path}/$fileName';
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);
            thumbnailFile = XFile(filePath);
          }
        } catch (e) {
          // Continue without thumbnail if download fails
        }
      }

      // 4. Share the thumbnail image + video URL
      if (thumbnailFile != null) {
        // Share with both thumbnail and URL
        await SharePlus.instance.share(
          ShareParams(
            files: [thumbnailFile],
            text: shareableUrl,
            sharePositionOrigin: originRect,
          ),
        );
      } else {
        // Share only the URL if thumbnail download failed
        await SharePlus.instance.share(
          ShareParams(
            text: shareableUrl,
            sharePositionOrigin: originRect,
          ),
        );
      }
    } catch (e, stackTrace) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to share: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
  }

  // removed unused _buildMediaIcon to avoid unused declaration warnings
}
