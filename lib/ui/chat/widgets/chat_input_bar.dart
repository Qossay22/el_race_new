import 'dart:async';

import 'package:flutter/material.dart';

import '../../../chat/chat.dart';
import '../../../resources/app_colors.dart';

/// Chat input bar with text field and attachment buttons
class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool isRecording;
  final VoidCallback onSendText;
  final VoidCallback onPickImage;
  final VoidCallback onPickGallery;
  final VoidCallback onPickFile;
  final VoidCallback? onPickSignableDoc;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.isRecording,
    required this.onSendText,
    required this.onPickImage,
    required this.onPickGallery,
    required this.onPickFile,
    this.onPickSignableDoc,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  bool _hasText = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  late AnimationController _recordingAnimController;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _recordingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _recordingTimer?.cancel();
    _recordingAnimController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void didUpdateWidget(ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle recording state changes
    if (widget.isRecording && !oldWidget.isRecording) {
      _startRecordingTimer();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _stopRecordingTimer();
    }
  }

  void _startRecordingTimer() {
    _recordingDuration = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingDuration++);
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingDuration = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: const Color(0xFFDCE6E5).withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 6,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: widget.isRecording ? _buildRecordingBar() : _buildInputBar(),
    );
  }

  Widget _buildInputBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AttachmentButton(
          onPickGallery: widget.onPickGallery,
          onPickFile: widget.onPickFile,
          onPickSignableDoc: widget.onPickSignableDoc,
          isLoading: widget.isLoading,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 54, maxHeight: 120),
            decoration: BoxDecoration(
              color: const Color(0xFFE9EAEC),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TextField(
              controller: widget.controller,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Write your message',
                hintStyle: TextStyle(
                  color: Color(0xFF9DA2A6),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => widget.onSendText(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _hasText
              ? _buildSideIcon(
                  icon: Icons.send_rounded, onTap: widget.onSendText)
              : _buildSideIcon(
                  icon: Icons.camera_alt_outlined, onTap: widget.onPickImage),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: widget.isLoading
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : _buildSideIcon(
                  icon: Icons.mic_none_rounded, onTap: widget.onStartRecording),
        ),
      ],
    );
  }

  Widget _buildSideIcon({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Icon(
          icon,
          size: 22,
          color: const Color(0xFF1C2226),
        ),
      ),
    );
  }

  Widget _buildRecordingBar() {
    return Row(
      children: [
        // Cancel button
        TextButton.icon(
          onPressed: widget.onCancelRecording,
          icon: const Icon(Icons.delete, color: Colors.red),
          label: const Text('Cancel', style: TextStyle(color: Colors.red)),
        ),

        const Spacer(),

        // Recording indicator
        AnimatedBuilder(
          animation: _recordingAnimController,
          builder: (context, child) {
            return Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(
                        alpha: 0.5 + _recordingAnimController.value * 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_recordingDuration),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),

        const Spacer(),

        // Stop and send button
        Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: widget.onStopRecording,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: const Icon(
                Icons.stop,
                color: AppColors.primaryColor,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

class _AttachmentButton extends StatelessWidget {
  final VoidCallback onPickGallery;
  final VoidCallback onPickFile;
  final VoidCallback? onPickSignableDoc;
  final bool isLoading;

  const _AttachmentButton({
    required this.onPickGallery,
    required this.onPickFile,
    this.onPickSignableDoc,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: !isLoading,
      onSelected: (value) {
        switch (value) {
          case 'image':
            onPickGallery();
            break;
          case 'file':
            onPickFile();
            break;
          case 'signable_doc':
            onPickSignableDoc?.call();
            break;
        }
      },
      offset: const Offset(0, -180),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'image',
          child: Row(
            children: [
              Icon(Icons.image, color: Colors.green[600]),
              const SizedBox(width: 12),
              const Text('Image'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'file',
          child: Row(
            children: [
              Icon(Icons.insert_drive_file, color: Colors.blue[600]),
              const SizedBox(width: 12),
              const Text('File'),
            ],
          ),
        ),
        if (onPickSignableDoc != null)
          PopupMenuItem(
            value: 'signable_doc',
            child: Row(
              children: [
                Icon(Icons.draw, color: Colors.orange[700]),
                const SizedBox(width: 12),
                const Text('Document for Signing'),
              ],
            ),
          ),
      ],
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(
          Icons.attach_file_rounded,
          color: const Color(0xFF1C2226),
          size: 22,
        ),
      ),
    );
  }
}
