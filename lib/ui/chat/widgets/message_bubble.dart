import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../chat/chat.dart';
import '../../../resources/app_colors.dart';
import '../chat_display_utils.dart';
import 'signable_document_card.dart';
import '../screens/sign_document_screen.dart';

/// Callback types for message actions
typedef MessageActionCallback = void Function(Message message);

/// Message bubble widget for displaying a single message
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isStarred;
  final bool isHighlighted;
  final String? senderName; // for showing sender name in group/support chats
  final bool
      showSenderName; // whether to display the sender name above the bubble
  final MessageActionCallback? onStar;
  final MessageActionCallback? onReply;
  final MessageActionCallback? onForward;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isStarred = false,
    this.isHighlighted = false,
    this.senderName,
    this.showSenderName = false,
    this.onStar,
    this.onReply,
    this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActions(context),
        child: Container(
          margin: EdgeInsets.only(
            left: isMe ? 60 : 8,
            right: isMe ? 8 : 60,
            top: 4,
            bottom: 4,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (showSenderName && senderName != null && !isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 2),
                  child: Text(
                    limitChatDisplayName(senderName!),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7B8D),
                    ),
                  ),
                ),
              _buildBubble(context),
              _buildStatus(context),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageActions(BuildContext context) {
    HapticFeedback.mediumImpact();

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset position = box.localToGlobal(Offset.zero);
    final Size size = box.size;

    // Position the menu above or below the bubble based on screen space
    final screenHeight = MediaQuery.of(context).size.height;
    final bubbleCenter = position.dx + size.width / 2;
    final showAbove = position.dy > screenHeight / 2;

    final RelativeRect menuPosition = RelativeRect.fromLTRB(
      isMe ? position.dx + size.width - 200 : position.dx,
      showAbove ? position.dy - 8 : position.dy + size.height,
      isMe ? position.dx + size.width : position.dx + 200,
      showAbove ? position.dy + size.height : position.dy,
    );

    showMenu<String>(
      context: context,
      position: menuPosition,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      items: [
        _buildMenuItem(
          value: 'star',
          icon: isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
          label: isStarred ? 'Unstar' : 'Star',
        ),
        _buildMenuItem(
          value: 'reply',
          icon: Icons.reply_rounded,
          label: 'Reply',
        ),
        _buildMenuItem(
          value: 'forward',
          icon: Icons.shortcut_rounded,
          label: 'Forward',
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'star':
          onStar?.call(message);
          break;
        case 'reply':
          onReply?.call(message);
          break;
        case 'forward':
          onForward?.call(message);
          break;
      }
    });
  }

  PopupMenuItem<String> _buildMenuItem({
    required String value,
    required IconData icon,
    required String label,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 48,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8E8E93), size: 22),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF2C2C2E),
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    final textColor = isMe ? Colors.white : const Color(0xFF141E24);

    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 6),
      bottomRight: Radius.circular(isMe ? 6 : 16),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: bubbleRadius,
        border: isHighlighted
            ? Border.all(
                color: const Color(0xFFF4C542).withValues(alpha: 0.70),
                width: 1.4,
              )
            : null,
        boxShadow: [
          if (isHighlighted)
            BoxShadow(
              color: const Color(0xFFF4C542).withValues(alpha: 0.16),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 0),
            ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isMe ? null : const Color(0xFFE6EAEE),
          gradient: isMe
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1D2449),
                    Color(0xFF2B355D),
                  ],
                )
              : null,
          borderRadius: bubbleRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isMe ? 0.10 : 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: ClipRRect(
          borderRadius: bubbleRadius,
          child: _buildContent(context, textColor),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    Widget content;
    switch (message.type) {
      case MessageType.text:
        content =
            _TextContent(message: message, textColor: textColor, isMe: isMe);
      case MessageType.image:
        content = _ImageContent(message: message, isMe: isMe);
      case MessageType.audio:
        content = _AudioContent(message: message, isMe: isMe);
      case MessageType.video:
        content = _VideoContent(message: message, isMe: isMe);
      case MessageType.file:
        content =
            _FileContent(message: message, textColor: textColor, isMe: isMe);
      case MessageType.signableDoc:
        content = _SignableDocContent(
          message: message,
          isMe: isMe,
        );
    }

    // Wrap with reply-to preview if present
    if (message.replyTo != null && message.replyTo!.messageId.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReplyToPreview(replyTo: message.replyTo!, isMe: isMe),
          content,
        ],
      );
    }

    return content;
  }

  Widget _buildStatus(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(message.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 4),
            _buildReadReceipt(),
          ],
        ],
      ),
    );
  }

  Widget _buildReadReceipt() {
    switch (message.status) {
      case MessageStatus.sending:
        // Clock icon for pending message
        return Icon(
          Icons.access_time,
          size: 14,
          color: Colors.grey[400],
        );
      case MessageStatus.failed:
        // Error icon for failed message
        return Icon(
          Icons.error_outline,
          size: 14,
          color: Colors.red[400],
        );
      case MessageStatus.sent:
        // Single check for sent
        return Icon(
          Icons.done,
          size: 14,
          color: Colors.grey[400],
        );
      case MessageStatus.delivered:
        // Double check gray for delivered
        return Icon(
          Icons.done_all,
          size: 14,
          color: Colors.grey[400],
        );
      case MessageStatus.read:
        // Double check blue for read
        return Icon(
          Icons.done_all,
          size: 14,
          color: Colors.blue[400],
        );
    }
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _TextContent extends StatelessWidget {
  final Message message;
  final Color textColor;
  final bool isMe;

  const _TextContent({
    required this.message,
    required this.textColor,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        message.text ?? '',
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          height: 1.3,
        ),
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _ImageContent({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullImage(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.mediaUrl != null)
            Image.network(
              message.mediaUrl!,
              fit: BoxFit.cover,
              width: 250,
              height: 200,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return SizedBox(
                  width: 250,
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stack) => Container(
                width: 250,
                height: 100,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, size: 40),
              ),
            ),
          if (message.text != null && message.text!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                message.text!,
                style: TextStyle(
                  color: isMe ? AppColors.primaryColor : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context) {
    if (message.mediaUrl == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: InteractiveViewer(
            child: Center(
              child: Image.network(message.mediaUrl!),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioContent extends StatefulWidget {
  final Message message;
  final bool isMe;

  const _AudioContent({
    required this.message,
    required this.isMe,
  });

  @override
  State<_AudioContent> createState() => _AudioContentState();
}

class _AudioContentState extends State<_AudioContent> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Waveform bar heights (simulated – gives a realistic pattern)
  static const List<double> _barHeights = [
    0.25,
    0.40,
    0.55,
    0.70,
    0.50,
    0.80,
    0.95,
    0.60,
    0.85,
    0.45,
    0.70,
    0.90,
    0.35,
    0.65,
    0.80,
    0.50,
    0.75,
    0.55,
    0.40,
    0.90,
    0.60,
    0.35,
    0.70,
    0.85,
    0.45,
  ];

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (widget.message.mediaUrl == null) return;

    try {
      await _player.setUrl(widget.message.mediaUrl!);
      _duration = _player.duration ?? Duration.zero;

      if (widget.message.durationMs != null) {
        _duration = Duration(milliseconds: widget.message.durationMs!);
      }

      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
          // Reset position when playback completes
          if (state.processingState == ProcessingState.completed) {
            _player.seek(Duration.zero);
            _player.pause();
          }
        }
      });

      _player.positionStream.listen((pos) {
        if (mounted) setState(() => _position = pos);
      });
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  double get _progress {
    if (_duration.inMilliseconds == 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    // Colors
    const playedBarColor = Colors.white;
    const unplayedBarColor = Color(0xFF7FE0D8);
    const iconBg = Colors.white;
    const iconColor = Color(0xFF1D2449);

    final displayDuration = _isPlaying ? _position : _duration;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Play / Pause button ──
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: iconBg,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: iconColor,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ── Waveform bars ──
          Flexible(
            child: SizedBox(
              height: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(_barHeights.length, (i) {
                  final fraction = i / _barHeights.length;
                  final isPlayed = fraction < _progress;
                  return Container(
                    width: 3,
                    height: 6 + (_barHeights[i] * 24),
                    margin: const EdgeInsets.symmetric(horizontal: 1.4),
                    decoration: BoxDecoration(
                      color: isPlayed ? playedBarColor : unplayedBarColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ── Duration ──
          Text(
            _formatDuration(displayDuration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _VideoContent extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _VideoContent({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openVideo(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 250,
            height: 150,
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (message.thumbUrl != null)
                  Image.network(
                    message.thumbUrl!,
                    fit: BoxFit.cover,
                    width: 250,
                    height: 150,
                  ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                if (message.durationMs != null)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(message.durationMs!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (message.text != null && message.text!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                message.text!,
                style: TextStyle(
                  color: isMe ? AppColors.primaryColor : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openVideo(BuildContext context) async {
    if (message.mediaUrl == null) return;

    final uri = Uri.parse(message.mediaUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDuration(int durationMs) {
    final duration = Duration(milliseconds: durationMs);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Signable document content — renders a SignableDocumentCard inside the bubble
class _SignableDocContent extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _SignableDocContent({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SignableDocumentCard(
        message: message,
        isMe: isMe,
        onSignNow: () => _openSignScreen(context),
        onViewSigned: () => _openSignedViewer(context),
      ),
    );
  }

  void _openSignScreen(BuildContext context) {
    // Find the chatId from the widget tree (passed via InheritedWidget or via
    // the MessageBubble's context). We look for the Scaffold with ChatScreen.
    // For simplicity, we extract chatId from the Navigator route arguments or
    // pass it through. Here we use a simple approach: find it from context.
    final chatId = _findChatId(context);
    if (chatId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignDocumentScreen(
          message: message,
          chatId: chatId,
        ),
      ),
    );
  }

  void _openSignedViewer(BuildContext context) {
    final chatId = _findChatId(context);
    if (chatId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignDocumentScreen(
          message: message,
          chatId: chatId,
        ),
      ),
    );
  }

  String? _findChatId(BuildContext context) {
    // Walk up the widget tree to find a ChatIdProvider
    final provider = context.findAncestorWidgetOfExactType<ChatIdProvider>();
    return provider?.chatId;
  }
}

/// InheritedWidget to pass chatId down the widget tree
class ChatIdProvider extends InheritedWidget {
  final String chatId;

  const ChatIdProvider({
    super.key,
    required this.chatId,
    required super.child,
  });

  static String? of(BuildContext context) {
    return context.findAncestorWidgetOfExactType<ChatIdProvider>()?.chatId;
  }

  @override
  bool updateShouldNotify(ChatIdProvider oldWidget) =>
      chatId != oldWidget.chatId;
}

class _FileContent extends StatelessWidget {
  final Message message;
  final Color textColor;
  final bool isMe;

  const _FileContent({
    required this.message,
    required this.textColor,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFile(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isMe
                    ? AppColors.primaryColor.withValues(alpha: 0.2)
                    : Colors.grey[300],
              ),
              child: Icon(
                _getFileIcon(),
                color: textColor,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.fileName ?? 'ملف',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                  ),
                  if (message.fileSize != null)
                    Text(
                      _formatFileSize(message.fileSize!),
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download,
              color: textColor.withValues(alpha: 0.7),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon() {
    final mimeType = message.mimeType?.toLowerCase() ?? '';

    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('doc'))
      return Icons.description;
    if (mimeType.contains('excel') || mimeType.contains('sheet'))
      return Icons.table_chart;
    if (mimeType.contains('powerpoint') || mimeType.contains('presentation'))
      return Icons.slideshow;
    if (mimeType.contains('zip') || mimeType.contains('rar'))
      return Icons.folder_zip;
    if (mimeType.contains('text')) return Icons.article;

    return Icons.insert_drive_file;
  }

  void _openFile() async {
    if (message.mediaUrl == null) return;

    final uri = Uri.parse(message.mediaUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Reply-to preview shown inside the message bubble
class _ReplyToPreview extends StatelessWidget {
  final ReplyTo replyTo;
  final bool isMe;

  const _ReplyToPreview({required this.replyTo, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isMe ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFD6DCE2);
    final accentColor =
        isMe ? const Color(0xFF7FE0D8) : const Color(0xFF1D2449);
    final textColor = isMe ? Colors.white70 : const Color(0xFF5A6570);

    String preview = replyTo.text ?? '';
    if (preview.isEmpty) {
      final type = replyTo.type;
      if (type == 'image')
        preview = '📷 Photo';
      else if (type == 'audio')
        preview = '🎵 Voice message';
      else if (type == 'video')
        preview = '🎬 Video';
      else if (type == 'file') preview = '📎 File';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: accentColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            replyTo.senderId.length > 8
                ? replyTo.senderId.substring(0, 8)
                : replyTo.senderId,
            style: TextStyle(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            maxLines: null,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 2),
          Text(
            preview,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.visible,
          ),
        ],
      ),
    );
  }
}
