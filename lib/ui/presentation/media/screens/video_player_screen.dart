import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/media_model.dart';
import '../../../widgets/header_widget.dart';

class VideoPlayerScreen extends StatefulWidget {
  final MediaModel media;

  const VideoPlayerScreen({
    super.key,
    required this.media,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool isPlaying = false;
  bool showControls = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const HeaderWidget(),
      body: Stack(
        children: [
          // Video placeholder - this would contain the actual video player
          Center(
            child: _buildVideoPlayer(),
          ),

          // Video controls overlay
          if (showControls)
            Positioned.fill(
              child: _buildControlsOverlay(),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    // Placeholder for video player
    // In a real implementation, this would use video_player package
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
          Icon(
            Icons.videocam,
            size: 80.sp,
            color: Colors.white,
          ),
          SizedBox(height: 16.h),
          Text(
            'Video Player',
            style: GoogleFonts.poppins(
              fontSize: 24.sp,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            widget.media.name,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: Colors.grey[400],
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          Text(
            'Video player package needed',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.orange,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            'Add video_player: ^2.8.1 to pubspec.yaml',
            style: TextStyle(
              fontSize: 10.sp,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return GestureDetector(
      onTap: () {
        setState(() {
          showControls = !showControls;
        });
      },
      child: Container(
        color: Colors.black26,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous/Rewind button
              IconButton(
                onPressed: () {
                  // Rewind 10 seconds
                },
                icon: Icon(
                  Icons.replay_10,
                  size: 40.sp,
                  color: Colors.white,
                ),
              ),

              SizedBox(width: 20.w),

              // Play/Pause button
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      isPlaying = !isPlaying;
                    });
                    // Here you would control actual video playback
                  },
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 50.sp,
                    color: Colors.white,
                  ),
                ),
              ),

              SizedBox(width: 20.w),

              // Forward button
              IconButton(
                onPressed: () {
                  // Forward 10 seconds
                },
                icon: Icon(
                  Icons.forward_10,
                  size: 40.sp,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
