import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';

import '../../../chat/chat.dart';

/// Recipient signs a document zone-by-zone.
///
/// PDF is shown page-by-page (native scroll disabled) so overlays
/// never drift. After each stamp the signature is baked into _pdfBytes
/// and the viewer reloads on the same page so the user sees the result.
class SignDocumentScreen extends StatefulWidget {
  final Message message;
  final String chatId;
  final Uint8List? signatureImageBytes;

  const SignDocumentScreen({
    super.key,
    required this.message,
    required this.chatId,
    this.signatureImageBytes,
  });

  @override
  State<SignDocumentScreen> createState() => _SignDocumentScreenState();
}

class _SignDocumentScreenState extends State<SignDocumentScreen> {
  // PDF ------------------------------------------------------------------
  Uint8List? _pdfBytes;
  bool _loading = true;
  String? _error;
  int _totalPages = 0;
  int _currentPage = 0;
  PDFViewController? _pdfController;
  Size _viewSize = Size.zero;

  /// Incremented after every stamp to force PDFView to rebuild with
  /// the new bytes (same key = Flutter reuses the old native view).
  int _pdfVersion = 0;

  /// Page to jump to after the new PDFView has rendered.
  int? _pendingPage;

  // Signing ---------------------------------------------------------------
  bool _sending = false;
  late final List<SignZone> _allZones;
  final Set<int> _signedZoneIndices = {};
  int? _focusedZoneIndex;

  /// Drawn once, reused for all zones
  Uint8List? _cachedSignatureBytes;
  final List<Size> _pageSizes = [];

  bool get _allSigned =>
      _allZones.isNotEmpty && _signedZoneIndices.length == _allZones.length;

  @override
  void initState() {
    super.initState();
    _allZones = List<SignZone>.from(widget.message.signZones ?? []);
    _loadPdf();
  }

  // ─── PDF loading ──────────────────────────────────────────

  Future<void> _loadPdf() async {
    final url = widget.message.signStatus == SignStatus.signed
        ? (widget.message.signedPdfUrl ?? widget.message.mediaUrl)
        : widget.message.mediaUrl;
    if (url == null) {
      setState(() {
        _error = 'No document URL';
        _loading = false;
      });
      return;
    }
    try {
      final r = await http.get(Uri.parse(url));
      if (r.statusCode == 200 && mounted) {
        try {
          final doc = PdfDocument(inputBytes: r.bodyBytes);
          _pageSizes
            ..clear()
            ..addAll(List<Size>.generate(doc.pages.count, (i) {
              final s = doc.pages[i].getClientSize();
              return Size(s.width, s.height);
            }));
          doc.dispose();
        } catch (_) {
          _pageSizes
            ..clear()
            ..add(const Size(595, 842));
        }

        setState(() {
          _pdfBytes = r.bodyBytes;
          _loading = false;
        });
      } else if (mounted) {
        setState(() {
          _error = 'HTTP ${r.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = '$e';
          _loading = false;
        });
    }
  }

  // ─── Page navigation ─────────────────────────────────────

  void _goPage(int page) {
    if (page < 0 || page >= _totalPages) return;
    _pdfController?.setPage(page);
  }

  // ─── Zone navigation ─────────────────────────────────────

  int? _nextUnsignedZoneIndex() {
    final start = (_focusedZoneIndex ?? -1) + 1;
    for (int i = 0; i < _allZones.length; i++) {
      final idx = (start + i) % _allZones.length;
      if (!_signedZoneIndices.contains(idx)) return idx;
    }
    return null;
  }

  void _goToNextZone() {
    final idx = _nextUnsignedZoneIndex();
    if (idx == null) return;
    final zone = _allZones[idx];
    setState(() => _focusedZoneIndex = idx);
    if (zone.page != _currentPage) _goPage(zone.page);
  }

  // ─── Sign a single zone ──────────────────────────────────

  Future<void> _signCurrentZone() async {
    if (_focusedZoneIndex == null || _pdfBytes == null) return;

    Uint8List? sigBytes = _cachedSignatureBytes ?? widget.signatureImageBytes;
    if (sigBytes == null) {
      sigBytes = await _showSignaturePad();
      if (sigBytes == null) return;
      _cachedSignatureBytes = sigBytes;
    }

    final zone = _allZones[_focusedZoneIndex!];
    final updated = _stampSingleZone(_pdfBytes!, zone, sigBytes);
    final stayOnPage = _currentPage;

    setState(() {
      _pdfBytes = updated;
      _pdfVersion++; // forces new PDFView
      _pendingPage = stayOnPage; // will jump here after render
      _signedZoneIndices.add(_focusedZoneIndex!);
      _focusedZoneIndex = null; // clear focus, user sees stamped sig
    });
  }

  Uint8List _stampSingleZone(
    Uint8List pdfBytes,
    SignZone zone,
    Uint8List sigImgBytes,
  ) {
    final doc = PdfDocument(inputBytes: pdfBytes);
    if (zone.page < doc.pages.count) {
      final page = doc.pages[zone.page];
      final ps = page.getClientSize();
      final x = zone.x * ps.width;
      final y = zone.y * ps.height;
      final w = zone.width * ps.width;
      final h = zone.height * ps.height;
      page.graphics
          .drawImage(PdfBitmap(sigImgBytes), Rect.fromLTWH(x, y, w, h));
      page.graphics.drawRectangle(
        pen: PdfPen(PdfColor(180, 180, 180), width: 0.5),
        bounds: Rect.fromLTWH(x, y, w, h),
      );
    }
    final bytes = doc.saveSync();
    doc.dispose();
    return Uint8List.fromList(bytes);
  }

  // ─── Send signed document ─────────────────────────────────

  Future<void> _sendSignedDocument() async {
    if (_pdfBytes == null || _sending) return;
    setState(() => _sending = true);
    try {
      await ChatRepository.instance.signDocument(
        widget.chatId,
        widget.message.id,
        _pdfBytes!,
        widget.message.fileName ?? 'document.pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document signed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Failed to send: $e');
      setState(() => _sending = false);
    }
  }

  // ─── Share ─────────────────────────────────────────────────

  Future<void> _sharePdf() async {
    if (_pdfBytes == null) return;
    try {
      final dir = await getTemporaryDirectory();
      final name = widget.message.fileName ?? 'signed_document.pdf';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(_pdfBytes!);
      if (mounted) {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)]),
        );
      }
    } catch (e) {
      _showError('Share failed: $e');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────

  Future<Uint8List?> _showSignaturePad() {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SignaturePadDialog(),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  B U I L D
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isSigned = widget.message.signStatus == SignStatus.signed;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D2449),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSigned ? 'Signed Document' : 'Sign Document',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              widget.message.fileName ?? 'Document',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          // Share button
          IconButton(
            onPressed: _sharePdf,
            icon: const Icon(Icons.share),
            tooltip: 'Share',
          ),
          if (!isSigned && !_allSigned)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '${_signedZoneIndices.length}/${_allZones.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD4A843),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildBody(isSigned),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _loadPdf();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isSigned) {
    return Column(
      children: [
        _buildStatusBar(isSigned),

        // PDF (native scroll disabled → overlays stay fixed)
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewSize = Size(constraints.maxWidth, constraints.maxHeight);
              return Stack(
                children: [
                  // Block all native touch so PDF never scrolls
                  AbsorbPointer(
                    child: PDFView(
                      key: ValueKey('pdf_$_pdfVersion'),
                      pdfData: _pdfBytes,
                      enableSwipe: false,
                      swipeHorizontal: false,
                      autoSpacing: true,
                      pageFling: false,
                      backgroundColor: Colors.grey[200]!,
                      onViewCreated: (c) => _pdfController = c,
                      onRender: (pages) {
                        setState(() => _totalPages = pages ?? 0);
                        // Restore page after PDF bytes changed
                        if (_pendingPage != null) {
                          final pg = _pendingPage!;
                          _pendingPage = null;
                          Future.microtask(() => _pdfController?.setPage(pg));
                        }
                      },
                      onPageChanged: (p, t) => setState(() {
                        _currentPage = p ?? 0;
                        _totalPages = t ?? 0;
                      }),
                    ),
                  ),

                  // Unsigned zone overlays (signed zones are baked into PDF)
                  if (!isSigned) ..._buildZoneOverlays(),
                ],
              );
            },
          ),
        ),

        _buildBottomBar(isSigned),
      ],
    );
  }

  // ─── Status bar ───────────────────────────────────────────

  Widget _buildStatusBar(bool isSigned) {
    if (isSigned) {
      return _statusBar(
        color: Colors.green.withValues(alpha: 0.1),
        icon: Icons.verified,
        iconColor: Colors.green,
        text: 'This document has been signed',
        textColor: Colors.green[700]!,
      );
    }
    if (_allSigned) {
      return _statusBar(
        color: Colors.green.withValues(alpha: 0.1),
        icon: Icons.check_circle,
        iconColor: Colors.green,
        text: 'All zones signed — tap Send below!',
        textColor: Colors.green,
      );
    }
    final txt = _focusedZoneIndex != null
        ? 'Zone ${_focusedZoneIndex! + 1} of ${_allZones.length} — tap "Sign & Stamp"'
        : 'Tap "Next Zone" to go to a sign zone';
    return _statusBar(
      color: const Color(0xFFFFF3CD),
      icon: Icons.info_outline,
      iconColor: const Color(0xFF856404),
      text: txt,
      textColor: const Color(0xFF856404),
    );
  }

  Widget _statusBar({
    required Color color,
    required IconData icon,
    required Color iconColor,
    required String text,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: color,
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom bar ───────────────────────────────────────────

  Widget _buildBottomBar(bool isSigned) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page nav row (always visible)
          _buildPageNavRow(),
          const SizedBox(height: 6),
          // Action row
          if (isSigned)
            const SizedBox.shrink()
          else if (_allSigned)
            _buildSendButton()
          else
            _buildSignRow(),
        ],
      ),
    );
  }

  Widget _buildPageNavRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _currentPage > 0 ? () => _goPage(_currentPage - 1) : null,
          icon: const Icon(Icons.chevron_left),
          visualDensity: VisualDensity.compact,
        ),
        Text(
          'Page ${_currentPage + 1} of $_totalPages',
          style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500),
        ),
        IconButton(
          onPressed: _currentPage < _totalPages - 1
              ? () => _goPage(_currentPage + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _sending ? null : _sendSignedDocument,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        icon: _sending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send, size: 18),
        label: Text(
          _sending ? 'Sending...' : 'Send Signed Document',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildSignRow() {
    final isFocused = _focusedZoneIndex != null;
    final hasUnsigned = _nextUnsignedZoneIndex() != null;

    return Row(
      children: [
        const Spacer(),
        // "Next Zone" – visible when no zone is focused
        if (!isFocused && hasUnsigned)
          ElevatedButton.icon(
            onPressed: _goToNextZone,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D2449),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.navigate_next, size: 18),
            label: const Text('Next Zone',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),

        // Focused zone → Skip + Sign & Stamp
        if (isFocused) ...[
          OutlinedButton(
            onPressed: () => setState(() => _focusedZoneIndex = null),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Skip', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _signCurrentZone,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4A843),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.draw, size: 18),
            label: const Text('Sign & Stamp',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ],
    );
  }

  // ─── Zone overlays ───────────────────────────────────────

  List<Widget> _buildZoneOverlays() {
    final pageRect = _pdfPageRectForCurrentView();
    final widgets = <Widget>[];
    for (int i = 0; i < _allZones.length; i++) {
      final zone = _allZones[i];
      if (zone.page != _currentPage) continue;
      if (_signedZoneIndices.contains(i)) continue; // baked into PDF

      final left = pageRect.left + (zone.x * pageRect.width);
      final top = pageRect.top + (zone.y * pageRect.height);
      final w = zone.width * pageRect.width;
      final h = zone.height * pageRect.height;
      final isFocused = _focusedZoneIndex == i;

      widgets.add(Positioned(
        left: left,
        top: top,
        width: w,
        height: h,
        child: GestureDetector(
          onTap: () => setState(() => _focusedZoneIndex = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isFocused
                  ? const Color(0xFFD4A843).withValues(alpha: 0.35)
                  : const Color(0xFFD4A843).withValues(alpha: 0.15),
              border: Border.all(
                color: isFocused
                    ? const Color(0xFFD4A843)
                    : const Color(0xFFD4A843).withValues(alpha: 0.6),
                width: isFocused ? 3 : 2,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFocused ? Icons.arrow_downward : Icons.draw,
                        size: 12,
                        color: const Color(0xFF856404),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isFocused ? 'Tap Sign below' : 'Sign Here',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF856404),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
    }
    return widgets;
  }

  Rect _pdfPageRectForCurrentView() {
    if (_viewSize.width <= 0 || _viewSize.height <= 0) return Rect.zero;

    final fallback = const Size(595, 842);
    final pageSize = (_currentPage >= 0 && _currentPage < _pageSizes.length)
        ? _pageSizes[_currentPage]
        : fallback;

    final pageRatio = pageSize.width / pageSize.height;
    final viewRatio = _viewSize.width / _viewSize.height;

    if (viewRatio > pageRatio) {
      final height = _viewSize.height;
      final width = height * pageRatio;
      final left = (_viewSize.width - width) / 2;
      return Rect.fromLTWH(left, 0, width, height);
    }

    final width = _viewSize.width;
    final height = width / pageRatio;
    final top = (_viewSize.height - height) / 2;
    return Rect.fromLTWH(0, top, width, height);
  }
}

// ═══════════════════════════════════════════════════════════════
//  S I G N A T U R E   P A D
// ═══════════════════════════════════════════════════════════════

class _SignaturePadDialog extends StatefulWidget {
  const _SignaturePadDialog();
  @override
  State<_SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<_SignaturePadDialog> {
  static const double _padWidth = 350;
  static const double _padHeight = 150;
  static const double _minPointDistance = 0.7;

  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  bool _isDrawing = false;

  Offset _clampToPad(Offset p) {
    final dx = p.dx.clamp(0.0, _padWidth) as double;
    final dy = p.dy.clamp(0.0, _padHeight) as double;
    return Offset(dx, dy);
  }

  bool _isInsidePad(Offset p) {
    return p.dx >= 0 && p.dx <= _padWidth && p.dy >= 0 && p.dy <= _padHeight;
  }

  void _startStroke(DragStartDetails d) {
    if (!_isInsidePad(d.localPosition)) {
      _isDrawing = false;
      return;
    }

    final point = _clampToPad(d.localPosition);
    setState(() {
      _isDrawing = true;
      _currentStroke = [point];
      _strokes.add(_currentStroke);
    });
  }

  void _appendStroke(DragUpdateDetails d) {
    if (!_isDrawing || _currentStroke.isEmpty) return;

    final point = _clampToPad(d.localPosition);
    final last = _currentStroke.last;

    // Skip tiny movements to reduce rebuild pressure on low-end Android.
    if ((point - last).distance < _minPointDistance) return;

    setState(() => _currentStroke.add(point));
  }

  void _endStroke() {
    _isDrawing = false;
    _currentStroke = [];
  }

  void _clear() => setState(() {
        _strokes.clear();
        _currentStroke.clear();
      });

  Future<void> _confirm() async {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please draw your signature'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in _strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++)
        path.lineTo(stroke[i].dx, stroke[i].dy);
      canvas.drawPath(path, paint);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(_padWidth.toInt(), _padHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null && mounted) {
      Navigator.pop(context, byteData.buffer.asUint8List());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Draw Your Signature'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _padWidth,
            height: _padHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: RepaintBoundary(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _startStroke,
                  onPanUpdate: _appendStroke,
                  onPanEnd: (_) => _endStroke(),
                  onPanCancel: _endStroke,
                  child: CustomPaint(
                    painter: _SignaturePainter(strokes: _strokes),
                    size: const Size(_padWidth, _padHeight),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Draw your signature above',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
      actions: [
        TextButton(onPressed: _clear, child: const Text('Clear')),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _confirm,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D2449)),
          child: const Text('Confirm', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SignaturePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++)
        path.lineTo(stroke[i].dx, stroke[i].dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
