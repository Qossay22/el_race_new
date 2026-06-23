import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../chat/models/message.dart';

/// Screen for the sender to pick sign zones on a PDF before sending.
/// The user can add, move, resize, and remove zones.
class SignZonePickerScreen extends StatefulWidget {
  final File pdfFile;
  final String fileName;

  const SignZonePickerScreen({
    super.key,
    required this.pdfFile,
    required this.fileName,
  });

  @override
  State<SignZonePickerScreen> createState() => _SignZonePickerScreenState();
}

class _SignZonePickerScreenState extends State<SignZonePickerScreen> {
  static const double _defaultZoneW = 0.30;
  static const double _defaultZoneH = 0.06;
  static const double _minZoneW = 0.12;
  static const double _minZoneH = 0.04;

  Uint8List? _pdfBytes;
  bool _loading = true;
  String? _error;
  int _totalPages = 0;
  int _currentPage = 0;
  int _pageCount = 0;
  PDFViewController? _pdfController;

  final List<SignZone> _signZones = [];
  final List<Size> _pageSizes = [];

  bool _isPlaceMode = true;
  Size _viewSize = Size.zero;
  int? _selectedZoneIndex;

  int? _resizingZoneIndex;
  Offset? _resizeStartGlobal;
  SignZone? _resizeStartZone;

  int? _scalingZoneIndex;
  Offset? _scaleStartGlobal;
  SignZone? _scaleStartZone;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final bytes = await widget.pdfFile.readAsBytes();
      try {
        final doc = PdfDocument(inputBytes: bytes);
        _pageCount = doc.pages.count;
        _pageSizes
          ..clear()
          ..addAll(List<Size>.generate(_pageCount, (i) {
            final s = doc.pages[i].getClientSize();
            return Size(s.width, s.height);
          }));
        doc.dispose();
      } catch (_) {
        _pageCount = 1;
        _pageSizes
          ..clear()
          ..add(const Size(595, 842));
      }

      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading PDF: $e';
          _loading = false;
        });
      }
    }
  }

  Rect _pdfPageRectForCurrentView() {
    if (_viewSize.width <= 0 || _viewSize.height <= 0) return Rect.zero;

    const fallback = Size(595, 842);
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

  void _addSignZone(Offset tapPosition) {
    if (_viewSize == Size.zero) return;

    final pageRect = _pdfPageRectForCurrentView();
    if (!pageRect.contains(tapPosition)) return;

    final relX =
        ((tapPosition.dx - pageRect.left) / pageRect.width).clamp(0.0, 1.0);
    final relY =
        ((tapPosition.dy - pageRect.top) / pageRect.height).clamp(0.0, 1.0);

    final x = (relX - _defaultZoneW / 2).clamp(0.0, 1.0 - _defaultZoneW);
    final y = (relY - _defaultZoneH / 2).clamp(0.0, 1.0 - _defaultZoneH);

    setState(() {
      _signZones.add(SignZone(
        page: _currentPage,
        x: x,
        y: y,
        width: _defaultZoneW,
        height: _defaultZoneH,
      ));
      _selectedZoneIndex = _signZones.length - 1;
    });
  }

  void _onResizeStart(int index, DragStartDetails details) {
    if (index < 0 || index >= _signZones.length) return;
    _resizingZoneIndex = index;
    _resizeStartGlobal = details.globalPosition;
    _resizeStartZone = _signZones[index];
    setState(() => _selectedZoneIndex = index);
  }

  void _onResizeUpdate(DragUpdateDetails details) {
    final index = _resizingZoneIndex;
    final startGlobal = _resizeStartGlobal;
    final startZone = _resizeStartZone;
    if (index == null || startGlobal == null || startZone == null) return;
    if (index < 0 || index >= _signZones.length) return;

    final pageRect = _pdfPageRectForCurrentView();
    if (pageRect.width <= 0 || pageRect.height <= 0) return;

    final totalDelta = details.globalPosition - startGlobal;
    final dw = totalDelta.dx / pageRect.width;
    final dh = totalDelta.dy / pageRect.height;

    final maxW = math.max(_minZoneW, 1.0 - startZone.x);
    final maxH = math.max(_minZoneH, 1.0 - startZone.y);

    final nextW = (startZone.width + dw).clamp(_minZoneW, maxW);
    final nextH = (startZone.height + dh).clamp(_minZoneH, maxH);

    setState(() {
      _signZones[index] = SignZone(
        page: startZone.page,
        x: startZone.x,
        y: startZone.y,
        width: nextW,
        height: nextH,
      );
    });
  }

  void _onResizeEnd([DragEndDetails? _]) {
    _resizingZoneIndex = null;
    _resizeStartGlobal = null;
    _resizeStartZone = null;
  }

  void _onZoneScaleStart(int index, ScaleStartDetails details) {
    if (index < 0 || index >= _signZones.length) return;
    _scalingZoneIndex = index;
    _scaleStartGlobal = details.focalPoint;
    _scaleStartZone = _signZones[index];
    setState(() => _selectedZoneIndex = index);
  }

  void _onZoneScaleUpdate(ScaleUpdateDetails details) {
    final index = _scalingZoneIndex;
    final startGlobal = _scaleStartGlobal;
    final startZone = _scaleStartZone;
    if (index == null || startGlobal == null || startZone == null) return;
    if (index < 0 || index >= _signZones.length) return;

    final pageRect = _pdfPageRectForCurrentView();
    if (pageRect.width <= 0 || pageRect.height <= 0) return;

    final totalDelta = details.focalPoint - startGlobal;
    final dx = totalDelta.dx / pageRect.width;
    final dy = totalDelta.dy / pageRect.height;

    final scale = details.scale.clamp(0.4, 5.0);
    final nextW = (startZone.width * scale).clamp(_minZoneW, 1.0);
    final nextH = (startZone.height * scale).clamp(_minZoneH, 1.0);

    final halfW = nextW / 2;
    final halfH = nextH / 2;

    final desiredCenterX = startZone.x + (startZone.width / 2) + dx;
    final desiredCenterY = startZone.y + (startZone.height / 2) + dy;

    final clampedCenterX = desiredCenterX.clamp(halfW, 1.0 - halfW);
    final clampedCenterY = desiredCenterY.clamp(halfH, 1.0 - halfH);

    setState(() {
      _signZones[index] = SignZone(
        page: startZone.page,
        x: clampedCenterX - halfW,
        y: clampedCenterY - halfH,
        width: nextW,
        height: nextH,
      );
    });
  }

  void _onZoneScaleEnd([ScaleEndDetails? _]) {
    _scalingZoneIndex = null;
    _scaleStartGlobal = null;
    _scaleStartZone = null;
  }

  int? _findZoneAt(Offset point, Rect pageRect) {
    for (int i = _signZones.length - 1; i >= 0; i--) {
      final zone = _signZones[i];
      if (zone.page != _currentPage) continue;

      final rect = Rect.fromLTWH(
        pageRect.left + (zone.x * pageRect.width),
        pageRect.top + (zone.y * pageRect.height),
        zone.width * pageRect.width,
        zone.height * pageRect.height,
      );

      if (rect.contains(point)) return i;
    }
    return null;
  }

  void _removeSignZone(int index) {
    setState(() {
      _signZones.removeAt(index);
      if (_resizingZoneIndex == index) _onResizeEnd();

      if (_selectedZoneIndex == index) {
        _selectedZoneIndex = null;
      } else if (_selectedZoneIndex != null && _selectedZoneIndex! > index) {
        _selectedZoneIndex = _selectedZoneIndex! - 1;
      }
    });
  }

  void _confirm() {
    if (_signZones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one sign zone'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'signZones': _signZones,
      'pageCount': _pageCount,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D2449),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Sign Zones',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              widget.fileName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _confirm,
            icon: const Icon(Icons.check, color: Colors.white),
            label: Text(
              'Send (${_signZones.length})',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color:
              _isPlaceMode ? const Color(0xFFFFF3CD) : const Color(0xFFD1ECF1),
          child: Row(
            children: [
              Icon(
                _isPlaceMode ? Icons.touch_app : Icons.swipe,
                size: 20,
                color: _isPlaceMode
                    ? const Color(0xFF856404)
                    : const Color(0xFF0C5460),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isPlaceMode
                      ? 'Tap empty page to add. Drag zone to move. Drag corner to resize.'
                      : 'Scroll to browse pages. Switch back to edit zones.',
                  style: TextStyle(
                    fontSize: 13,
                    color: _isPlaceMode
                        ? const Color(0xFF856404)
                        : const Color(0xFF0C5460),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_signZones.where((z) => z.page == _currentPage).isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _signZones.removeWhere((z) => z.page == _currentPage);
                      _selectedZoneIndex = null;
                    });
                  },
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewSize = Size(constraints.maxWidth, constraints.maxHeight);

              return Stack(
                children: [
                  AbsorbPointer(
                    absorbing: _isPlaceMode,
                    child: _buildPdfView(),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !_isPlaceMode,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: (details) {
                          final pageRect = _pdfPageRectForCurrentView();
                          final tappedZone =
                              _findZoneAt(details.localPosition, pageRect);
                          if (tappedZone != null) {
                            setState(() => _selectedZoneIndex = tappedZone);
                            return;
                          }
                          _addSignZone(details.localPosition);
                        },
                      ),
                    ),
                  ),
                  if (_isPlaceMode) ..._buildSignZoneOverlays(),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'mode_toggle',
                      backgroundColor: _isPlaceMode
                          ? const Color(0xFF1D2449)
                          : const Color(0xFFD4A843),
                      onPressed: () {
                        setState(() {
                          _isPlaceMode = !_isPlaceMode;
                          _selectedZoneIndex = null;
                        });
                      },
                      child: Icon(
                        _isPlaceMode ? Icons.swipe : Icons.touch_app,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                onPressed: _currentPage > 0
                    ? () => _pdfController?.setPage(_currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous page',
                visualDensity: VisualDensity.compact,
              ),
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                onPressed: _currentPage < _totalPages - 1
                    ? () => _pdfController?.setPage(_currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next page',
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _signZones.isEmpty
                      ? Colors.grey[200]
                      : const Color(0xFF1D2449),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_signZones.length} sign zone${_signZones.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _signZones.isEmpty ? Colors.grey[600] : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPdfView() {
    return PDFView(
      pdfData: _pdfBytes,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      backgroundColor: Colors.grey[200]!,
      onViewCreated: (controller) => _pdfController = controller,
      onRender: (pages) {
        setState(() {
          _totalPages = pages ?? 0;
        });
      },
      onPageChanged: (page, total) {
        setState(() {
          _currentPage = page ?? 0;
          _totalPages = total ?? 0;
          _selectedZoneIndex = null;
        });
      },
    );
  }

  List<Widget> _buildSignZoneOverlays() {
    final zonesOnPage = <int, SignZone>{};
    for (int i = 0; i < _signZones.length; i++) {
      if (_signZones[i].page == _currentPage) {
        zonesOnPage[i] = _signZones[i];
      }
    }

    final pageRect = _pdfPageRectForCurrentView();

    return zonesOnPage.entries.map((entry) {
      final zone = entry.value;
      final idx = entry.key;
      final isSelected = _selectedZoneIndex == idx;

      final left = pageRect.left + (zone.x * pageRect.width);
      final top = pageRect.top + (zone.y * pageRect.height);
      final width = zone.width * pageRect.width;
      final height = zone.height * pageRect.height;

      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedZoneIndex = idx),
                onScaleStart: (details) => _onZoneScaleStart(idx, details),
                onScaleUpdate: _onZoneScaleUpdate,
                onScaleEnd: _onZoneScaleEnd,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A843)
                        .withValues(alpha: isSelected ? 0.35 : 0.25),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1D2449)
                          : const Color(0xFFD4A843),
                      width: isSelected ? 2.5 : 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.draw,
                                size: 12, color: Color(0xFF856404)),
                            SizedBox(width: 3),
                            Text(
                              'Sign Here',
                              style: TextStyle(
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
            ),
            Positioned(
              top: -11,
              right: -11,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _removeSignZone(idx),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -14,
              bottom: -14,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedZoneIndex = idx),
                onPanStart: (details) => _onResizeStart(idx, details),
                onPanUpdate: _onResizeUpdate,
                onPanEnd: _onResizeEnd,
                onPanCancel: _onResizeEnd,
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1D2449)
                            : const Color(0xFF5B648F),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                      child: const Icon(
                        Icons.open_in_full,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
