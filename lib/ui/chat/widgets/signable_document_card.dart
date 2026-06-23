import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;

import '../../../chat/chat.dart';
import '../../../resources/app_colors.dart';

/// Card widget displayed inside a message bubble for signable documents.
/// Shows a PDF thumbnail, document info, sign status, and action button.
class SignableDocumentCard extends StatefulWidget {
  final Message message;
  final bool isMe;
  final VoidCallback? onSignNow;
  final VoidCallback? onViewSigned;

  const SignableDocumentCard({
    super.key,
    required this.message,
    required this.isMe,
    this.onSignNow,
    this.onViewSigned,
  });

  @override
  State<SignableDocumentCard> createState() => _SignableDocumentCardState();
}

class _SignableDocumentCardState extends State<SignableDocumentCard> {
  Uint8List? _pdfBytes;
  bool _loadingThumb = true;
  Timer? _countdownTimer;

  bool get _isUploading =>
      widget.message.isUploading ||
      widget.message.status == MessageStatus.sending;

  bool get _isFailed => widget.message.status == MessageStatus.failed;

  @override
  void initState() {
    super.initState();
    // Don't try to load thumbnail if still uploading (no URL yet)
    if (_isUploading || _isFailed) {
      _loadingThumb = false;
    } else {
      _loadPdfThumbnail();
    }
    // Start countdown timer for pending (unsigned) docs with expiry
    if (_shouldShowCountdown()) {
      _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SignableDocumentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When message transitions from uploading → sent, load the PDF thumbnail
    final wasUploading = oldWidget.message.isUploading ||
        oldWidget.message.status == MessageStatus.sending;
    if (wasUploading && !_isUploading && !_isFailed && _pdfBytes == null) {
      _loadPdfThumbnail();
    }
    // Start countdown timer if it wasn't started before
    if (_countdownTimer == null && _shouldShowCountdown()) {
      _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  bool _shouldShowCountdown() {
    return widget.message.expiresAt != null &&
        widget.message.signStatus != SignStatus.signed &&
        !_isUploading &&
        !_isFailed;
  }

  /// Format remaining time until expiry
  String _formatTimeRemaining() {
    final expiresAt = widget.message.expiresAt;
    if (expiresAt == null) return '';
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m remaining';
    }
    return '${minutes}m remaining';
  }

  /// Check if less than 2 hours remaining (for urgent styling)
  bool get _isUrgent {
    final expiresAt = widget.message.expiresAt;
    if (expiresAt == null) return false;
    return expiresAt.difference(DateTime.now()).inHours < 2;
  }

  Future<void> _loadPdfThumbnail() async {
    final url = widget.message.signStatus == SignStatus.signed
        ? widget.message.signedPdfUrl
        : widget.message.mediaUrl;
    if (url == null) {
      setState(() => _loadingThumb = false);
      return;
    }
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _pdfBytes = response.bodyBytes;
          _loadingThumb = false;
        });
      } else {
        if (mounted) setState(() => _loadingThumb = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingThumb = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSigned = widget.message.signStatus == SignStatus.signed;
    final isPending = widget.message.signStatus == SignStatus.pending;
    final fileName = widget.message.fileName ?? 'Document';
    final displayName = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final pages = widget.message.pageCount;
    final fileSize = widget.message.fileSize;
    final expiresIn = widget.message.signExpiresInDays ?? 2;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // PDF thumbnail area
          _buildThumbnail(),

          // Document info section
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1D2449),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (pages != null) '$pages pages',
                          if (fileSize != null) _formatFileSize(fileSize),
                          'PDF',
                        ].join('  |  '),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                // Sign status / action button
                if (_isUploading)
                  _buildSignButton(
                    label: 'SENDING',
                    icon: Icons.cloud_upload_outlined,
                    color: Colors.blueGrey,
                    onTap: null,
                  )
                else if (_isFailed)
                  _buildSignButton(
                    label: 'FAILED',
                    icon: Icons.error_outline,
                    color: Colors.red,
                    onTap: null,
                  )
                else if (isSigned)
                  _buildSignButton(
                    label: 'VIEW',
                    icon: Icons.visibility,
                    color: Colors.green,
                    onTap: widget.onViewSigned,
                  )
                else if (isPending && !widget.isMe)
                  _buildSignButton(
                    label: 'SIGN NOW',
                    icon: Icons.draw,
                    color: const Color(0xFFD4A843),
                    onTap: widget.onSignNow,
                  )
                else if (isPending && widget.isMe)
                  _buildSignButton(
                    label: 'PENDING',
                    icon: Icons.schedule,
                    color: Colors.orange,
                    onTap: null,
                  ),
              ],
            ),
          ),

          // Expiry / status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isUploading
                  ? const Color(0xFFF5F5F5)
                  : _isFailed
                      ? Colors.red.withValues(alpha: 0.06)
                      : isSigned
                          ? Colors.green.withValues(alpha: 0.08)
                          : _isUrgent
                              ? Colors.orange.withValues(alpha: 0.08)
                              : const Color(0xFFF5F5F5),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isUploading
                        ? 'Uploading document...'
                        : _isFailed
                            ? 'Failed to send'
                            : isSigned
                                ? 'Signed ${_formatSignedDate(widget.message.signedAt)}'
                                : _shouldShowCountdown()
                                    ? '⏳ ${_formatTimeRemaining()}'
                                    : 'Expires in 24 hours after sending',
                    style: TextStyle(
                      fontSize: 11,
                      color: _isUploading
                          ? Colors.blueGrey
                          : _isFailed
                              ? Colors.red[400]
                              : isSigned
                                  ? Colors.green[700]
                                  : _isUrgent
                                      ? Colors.orange[800]
                                      : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  _isUploading
                      ? Icons.cloud_upload_outlined
                      : _isFailed
                          ? Icons.error_outline
                          : isSigned
                              ? Icons.verified
                              : _isUrgent
                                  ? Icons.warning_amber_rounded
                                  : Icons.schedule,
                  size: 16,
                  color: _isUploading
                      ? Colors.blueGrey
                      : _isFailed
                          ? Colors.red[400]
                          : isSigned
                              ? Colors.green
                              : _isUrgent
                                  ? Colors.orange
                                  : Colors.grey[400],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        height: 180,
        color: const Color(0xFFE8E8E8),
        child: _isUploading
            ? _buildUploadingOverlay()
            : _isFailed
                ? _buildFailedOverlay()
                : _loadingThumb
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _pdfBytes != null
                        ? IgnorePointer(
                            child: PDFView(
                              pdfData: _pdfBytes,
                              enableSwipe: false,
                              pageFling: false,
                              autoSpacing: false,
                              backgroundColor: Colors.white,
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.picture_as_pdf,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                          ),
      ),
    );
  }

  /// Uploading overlay — shown while PDF is being uploaded
  Widget _buildUploadingOverlay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primaryColor.withValues(alpha: 0.6),
                ),
              ),
              Icon(
                Icons.picture_as_pdf,
                size: 28,
                color: Colors.red.withValues(alpha: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Uploading document...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Failed overlay — shown when upload failed
  Widget _buildFailedOverlay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 44,
            color: Colors.red.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload failed',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red[400],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatSignedDate(DateTime? date) {
    if (date == null) return '';
    final d = date.toLocal();
    return '${d.day}/${d.month}/${d.year}';
  }
}
