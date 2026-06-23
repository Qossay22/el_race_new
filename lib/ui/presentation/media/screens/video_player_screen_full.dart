import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../widgets/header_widget.dart';
import '../data/media_model.dart';

class VideoPlayerScreenFull extends StatefulWidget {
  final MediaModel media;

  const VideoPlayerScreenFull({
    super.key,
    required this.media,
  });

  @override
  State<VideoPlayerScreenFull> createState() => _VideoPlayerScreenFullState();
}

class _VideoPlayerScreenFullState extends State<VideoPlayerScreenFull> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    try {
      String videoUrl = widget.media.streamingUrl;

      if (videoUrl.startsWith('assets/')) {
        _controller = VideoPlayerController.asset(videoUrl);
      } else {
        // Use streaming URL for video playback
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          httpHeaders: {
            'Range': 'bytes=0-', // Enable range requests for streaming
            'Accept': 'video/*', // Accept video content
          },
        );
      }

      _controller.initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }).catchError((error) {
        // ignore
      });
    } catch (e) {
      // ignore
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const HeaderWidget(),
      body: Stack(
        children: [
          // Video player
          Center(
            child: _buildVideoPlayer(),
          ),

          // Video controls overlay
          if (_showControls)
            Positioned.fill(
              child: _buildControlsOverlay(),
            ),

          // Video title overlay
          Positioned(
            top: 20.h,
            left: 16.w,
            right: 16.w,
            child: _buildTitleOverlay(),
          ),

          // Download button - Hidden
          // Positioned(
          //   top: 20.h,
          //   right: 16.w,
          //   child: _buildDownloadButton(),
          // ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isInitialized) {
      return Container(
        width: double.infinity,
        height: 300.h,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Colors.white,
            ),
            SizedBox(height: 16.h),
            Text(
              'Loading video...',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }

  Widget _buildTitleOverlay() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        widget.media.name,
        style: GoogleFonts.poppins(
          fontSize: 14.sp,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
        maxLines: null,
        overflow: TextOverflow.visible,
      ),
    );
  }

  Widget _buildDownloadButton() {
    return Container(
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download URL not available')),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to open download link')),
            );
          }
        },
        icon: Icon(
          Icons.download,
          color: Colors.white,
          size: 24.sp,
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Container(
        color: Colors.transparent,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Rewind button
                    _buildControlButton(
                      icon: Icons.replay_10,
                      onPressed: () {
                        final currentPosition = _controller.value.position;
                        final newPosition =
                            currentPosition - const Duration(seconds: 10);
                        _controller.seekTo(newPosition > Duration.zero
                            ? newPosition
                            : Duration.zero);
                      },
                    ),

                    SizedBox(width: 20.w),

                    // Play/Pause button
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) {
                        return Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () {
                              if (_controller.value.isPlaying) {
                                _controller.pause();
                              } else {
                                _controller.play();
                              }
                            },
                            icon: Icon(
                              value.isPlaying ? Icons.pause : Icons.play_arrow,
                              size: 50.sp,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(width: 20.w),

                    // Forward button
                    _buildControlButton(
                      icon: Icons.forward_10,
                      onPressed: () {
                        final currentPosition = _controller.value.position;
                        final duration = _controller.value.duration;
                        final newPosition =
                            currentPosition + const Duration(seconds: 10);
                        _controller.seekTo(
                            newPosition < duration ? newPosition : duration);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Progress bar
            _buildProgressBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 40.sp,
        color: Colors.white,
      ),
    );
  }

  Widget _buildProgressBar() {
    if (!_isInitialized) return const SizedBox.shrink();

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Column(
            children: [
              VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.red,
                  bufferedColor: Colors.grey,
                  backgroundColor: Colors.black54,
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(value.position),
                    style: TextStyle(color: Colors.white, fontSize: 12.sp),
                  ),
                  Text(
                    _formatDuration(value.duration),
                    style: TextStyle(color: Colors.white, fontSize: 12.sp),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }
}
