import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../data/media_model.dart';
import '../../../widgets/header_widget.dart';

class YoYoVideoPlayerScreen extends StatefulWidget {
  final MediaModel media;

  const YoYoVideoPlayerScreen({
    super.key,
    required this.media,
  });

  @override
  State<YoYoVideoPlayerScreen> createState() => _YoYoVideoPlayerScreenState();
}

class _YoYoVideoPlayerScreenState extends State<YoYoVideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final url = widget.media.streamingUrl;
      _videoController = url.startsWith('assets/')
          ? VideoPlayerController.asset(url)
          : VideoPlayerController.networkUrl(
              Uri.parse(url),
              httpHeaders: {'Range': 'bytes=0-', 'Accept': 'video/*'},
            );

      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        // Rotate naturally with device — no new route pushed
        deviceOrientationsOnEnterFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
        ],
        allowedScreenSleep: false,
        placeholder: Container(color: Colors.black),
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          bufferedColor: Colors.grey,
          backgroundColor: Colors.black54,
        ),
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (_) {
      // ignore init errors
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFullscreen = _chewieController?.isFullScreen ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isFullscreen ? null : const HeaderWidget(),
      body: Column(
        children: [
          // Header row (title + download)
          if (!isFullscreen)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
              child: Row(
                children: [
                  const BackButton(color: Colors.white),
                  Expanded(
                    child: Text(
                      widget.media.name,
                      style: GoogleFonts.koulen(
                        fontSize: 18.sp,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: IconButton(
                      onPressed: () async {
                        try {
                          final downloadUrl = widget.media.downloadUrl;
                          if (downloadUrl.isNotEmpty) {
                            await launchUrl(Uri.parse(downloadUrl));
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Download URL not available')),
                              );
                            }
                          }
                        } catch (_) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Failed to open download link')),
                            );
                          }
                        }
                      },
                      icon: Icon(Icons.download, color: Colors.white, size: 20.sp),
                    ),
                  ),
                ],
              ),
            ),

          // Video player — chewie keeps the same controller across rotations
          Expanded(
            child: _isInitialized && _chewieController != null
                ? Chewie(controller: _chewieController!)
                : const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),

          // Video details
          if (!isFullscreen)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.media.size != null)
                    Text(
                      'Size: ${widget.media.size!.toStringAsFixed(1)} MB',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
                    ),
                  if (widget.media.duration != null) ...[
                    SizedBox(height: 4.h),
                    Text(
                      'Duration: ${widget.media.duration} seconds',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
                    ),
                  ],
                  SizedBox(height: 8.h),
                  Text(
                    'Created: ${widget.media.dateCreated.day}/${widget.media.dateCreated.month}/${widget.media.dateCreated.year}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
} 