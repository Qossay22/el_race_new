import 'package:flutter/material.dart';
import 'package:lecle_yoyo_player/lecle_yoyo_player.dart';

import '../../../../utils/url_encoder.dart';
import '../../../widgets/header_widget.dart';

class TestYoYoPlayer extends StatefulWidget {
  const TestYoYoPlayer({super.key});

  @override
  State<TestYoYoPlayer> createState() => _TestYoYoPlayerState();
}

class _TestYoYoPlayerState extends State<TestYoYoPlayer> {
  bool fullscreen = false;

  // Test URL with space that needs encoding
  final String testUrl =
      "https://myhlsmedia.s3.amazonaws.com/media-videos-hlsm3u8/Comp 1_hls.m3u8";

  @override
  Widget build(BuildContext context) {
    final encodedUrl = UrlEncoder.encode(testUrl);
    print('🎥 Original URL: $testUrl');
    print('🎥 Encoded URL: $encodedUrl');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: fullscreen ? null : const HeaderWidget(),
      body: YoYoPlayer(
        aspectRatio: 16 / 9,
        // Test URL with space - encoded to handle the space in "Comp 1"
        url: encodedUrl,
        videoStyle: const VideoStyle(
          qualityStyle: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          forwardAndBackwardBtSize: 30.0,
          playButtonIconSize: 40.0,
          playIcon: Icon(
            Icons.add_circle_outline_outlined,
            size: 40.0,
            color: Colors.white,
          ),
          pauseIcon: Icon(
            Icons.remove_circle_outline_outlined,
            size: 40.0,
            color: Colors.white,
          ),
          videoQualityPadding: EdgeInsets.all(5.0),
        ),
        videoLoadingStyle: const VideoLoadingStyle(
          loading: Center(
            child: Text(
              "Loading video",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        allowCacheFile: true,
        onCacheFileCompleted: (files) {
          print('Cached file length ::: ${files?.length}');

          if (files != null && files.isNotEmpty) {
            for (var file in files) {
              print('File path ::: ${file.path}');
            }
          }
        },
        onCacheFileFailed: (error) {
          print('Cache file error ::: $error');
        },
        onFullScreen: (value) {
          setState(() {
            if (fullscreen != value) {
              fullscreen = value;
            }
          });
        },
      ),
    );
  }
}
