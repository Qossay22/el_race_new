import 'dart:io';
import 'dart:typed_data';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Simple PDF viewer for LPO reports - loads PDF from URL and displays in-app.
class LpoPdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String? title;

  const LpoPdfViewerScreen({
    super.key,
    required this.pdfUrl,
    this.title,
  });

  @override
  State<LpoPdfViewerScreen> createState() => _LpoPdfViewerScreenState();
}

class _LpoPdfViewerScreenState extends State<LpoPdfViewerScreen> {
  bool _loading = true;
  String? _error;
  Uint8List? _pdfBytes;
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (rootNavigator.canPop()) {
      rootNavigator.pop();
    }
  }

  Future<void> _loadPdf() async {
    try {
      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (response.statusCode == 200) {
        final empId =
            SharedPref.getLoginData().result?.data?.emp_id ?? '';
        final Uint8List watermarked = empId.isNotEmpty
            ? _addWatermarkToPdf(response.bodyBytes, empId)
            : response.bodyBytes;
        setState(() {
          _pdfBytes = watermarked;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load PDF (HTTP ${response.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading PDF: $e';
        _loading = false;
      });
    }
  }

  Uint8List _addWatermarkToPdf(Uint8List pdfBytes, String empId) {
    try {
      final PdfDocument document =
          PdfDocument(inputBytes: pdfBytes);
      final PdfFont font = PdfStandardFont(
        PdfFontFamily.helvetica,
        28,
        style: PdfFontStyle.bold,
      );
      final PdfBrush brush = PdfSolidBrush(PdfColor(180, 180, 180));

      const int cols = 3;
      const int rows = 6;
      const double rotateDeg = -30;

      for (int i = 0; i < document.pages.count; i++) {
        final PdfPage page = document.pages[i];
        final Size pageSize = page.getClientSize();
        final double cellW = pageSize.width / cols;
        final double cellH = pageSize.height / rows;
        final PdfGraphics graphics = page.graphics;

        for (int row = 0; row < rows; row++) {
          for (int col = 0; col < cols; col++) {
            final double cx = cellW * col + cellW / 2;
            final double cy = cellH * row + cellH / 2;

            final PdfGraphicsState state = graphics.save();
            graphics
              ..setTransparency(0.18)
              ..translateTransform(cx, cy)
              ..rotateTransform(rotateDeg)
              ..drawString(
                empId,
                font,
                brush: brush,
                bounds: Rect.fromLTWH(-60, -20, 120, 40),
              );
            graphics.restore(state);
          }
        }
      }

      final List<int> bytes = document.saveSync();
      document.dispose();
      return Uint8List.fromList(bytes);
    } catch (e) {
      debugPrint('Watermark error: $e');
      return pdfBytes;
    }
  }

  Future<void> _sharePdf() async {
    if (_pdfBytes == null) return;

    final renderObject = context.findRenderObject();
    final shareOrigin = renderObject is RenderBox
        ? (renderObject.localToGlobal(Offset.zero) & renderObject.size)
        : const Rect.fromLTWH(1, 1, 1, 1);
    final rawName = widget.title?.trim() ?? 'lpo_report';
    // Only strip characters that are truly invalid in file names, keep spaces and dots
    final safeName = rawName.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final fileName =
        safeName.toLowerCase().endsWith('.pdf') ? safeName : '$safeName.pdf';
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(_pdfBytes!, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        sharePositionOrigin: shareOrigin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFFD0D2D8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF0E3A76)),
          onPressed: _goBack,
        ),
        title: Text(
          widget.title ?? 'LPO Report',
          style: GoogleFonts.poppins(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0E3A76),
          ),
        ),
        centerTitle: true,
        actions: [
          if (_pdfBytes != null)
            IconButton(
              icon: const Icon(Icons.share, color: Color(0xFF0E3A76)),
              onPressed: _sharePdf,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF0E3A76),
            ),
            SizedBox(height: 16.h),
            Text(
              'Loading PDF...',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64.w,
                color: Colors.red[400],
              ),
              SizedBox(height: 16.h),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadPdf();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E3A76),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfBytes == null) {
      return const Center(child: Text('No PDF data'));
    }

    return Column(
      children: [
        Expanded(
          child: SfPdfViewer.memory(
            _pdfBytes!,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            enableDoubleTapZooming: true,
            enableTextSelection: true,
            pageSpacing: 4,
            onDocumentLoaded: (PdfDocumentLoadedDetails details) {
              setState(() {
                _totalPages = details.document.pages.count;
              });
            },
            onPageChanged: (PdfPageChangedDetails details) {
              setState(() {
                _currentPage = details.newPageNumber;
              });
            },
          ),
        ),
        if (_totalPages > 0)
          Container(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Page $_currentPage of $_totalPages',
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
