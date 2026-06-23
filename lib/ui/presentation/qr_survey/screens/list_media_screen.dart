import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:provider/provider.dart';
import '../models/qr_media_model.dart';
import '../providers/qr_survey_data_provider.dart';

class ListMediaScreen extends StatefulWidget {
  final List<dynamic> mediaList;

  const ListMediaScreen({
    super.key,
    required this.mediaList,
  });

  @override
  State<ListMediaScreen> createState() => _ListMediaScreenState();
}

class _ListMediaScreenState extends State<ListMediaScreen> {
  late List<QrMediaModel> _mediaList;

  @override
  void initState() {
    super.initState();
    print(
        '📱 ListMediaScreen - Received ${widget.mediaList.length} media items');
    _mediaList = widget.mediaList.cast<QrMediaModel>();
    print(
        '📱 ListMediaScreen - Casted to ${_mediaList.length} QrMediaModel items');
    for (var media in _mediaList) {
      print('📱 Media: ${media.name} - ${media.url}');
    }
  }

  Widget _buildMediaItem(QrMediaModel media) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: media.isVideo ? Colors.blue.shade50 : Colors.purple.shade50,
            borderRadius: BorderRadius.circular(8),
            image: media.thumbnailUrl != null
                ? DecorationImage(
                    image: NetworkImage(media.thumbnailUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: media.thumbnailUrl == null
              ? Icon(
                  media.isVideo ? Icons.videocam : Icons.image,
                  color: media.isVideo ? Colors.blue : Colors.purple,
                  size: 30,
                )
              : null,
        ),
        title: Text(
          media.name,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: media.description != null
            ? Text(
                media.description!,
                style: GoogleFonts.poppins(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.visible,
              )
            : null,
        trailing: const Icon(Icons.play_circle, size: 32),
        onTap: () {
          if (media.isVideo) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(
                  media: media,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Verify this screen was accessed via QR code
    final provider = Provider.of<QrSurveyDataProvider>(context, listen: false);
    if (!provider.isFromQrCode) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'QR Code Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'This content is only accessible by scanning a QR code.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.grey[100],
      child: _mediaList.isEmpty
          ? const Center(
              child: Text(
                'No media found',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _mediaList.length,
              itemBuilder: (context, index) {
                return _buildMediaItem(_mediaList[index]);
              },
            ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final QrMediaModel media;

  const VideoPlayerScreen({
    super.key,
    required this.media,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  ChewieController? _chewieController;
  VideoPlayerController? _videoPlayerController;
  YoutubePlayerController? _youtubeController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    if (widget.media.isYouTube) {
      final videoId = YoutubePlayer.convertUrlToId(widget.media.url);
      if (videoId != null) {
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: false,
          ),
        );
      }
    } else {
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(widget.media.url));
      _videoPlayerController!.initialize().then((_) {
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: true,
          looping: false,
        );
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.media.name),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: widget.media.isYouTube && _youtubeController != null
            ? YoutubePlayer(
                controller: _youtubeController!,
                showVideoProgressIndicator: true,
              )
            : _chewieController != null
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(),
      ),
    );
  }
}
