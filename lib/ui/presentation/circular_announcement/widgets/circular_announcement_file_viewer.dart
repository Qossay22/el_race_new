import 'dart:io';
import 'dart:typed_data';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/circular_announcement/data/circular_announcement_model.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// File viewer for circular/announcement attachments
/// Supports PDF, images, and other file types
class CircularAnnouncementFileViewer extends StatefulWidget {
  final CircularAnnouncementItem item;

  const CircularAnnouncementFileViewer({
    super.key,
    required this.item,
  });

  @override
  State<CircularAnnouncementFileViewer> createState() =>
      _CircularAnnouncementFileViewerState();
}

class _CircularAnnouncementFileViewerState
    extends State<CircularAnnouncementFileViewer> {
  bool _isLoading = true;
  String? _error;
  Uint8List? _fileBytes;
  String? _localFilePath;
  _FileType _fileType = _FileType.unknown;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    if (widget.item.fileUrl == null) {
      setState(() {
        _error = 'No file URL provided';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get authentication token
      final token = SharedPref.getLoginData().result?.token;

      // Build URL with access_token (required for Odoo web/content endpoints)
      String downloadUrl = widget.item.fileUrl!;
      if (token != null && token.isNotEmpty) {
        // Add access_token as query parameter for Odoo file access
        if (downloadUrl.contains('?')) {
          downloadUrl = '$downloadUrl&access_token=$token';
        } else {
          downloadUrl = '$downloadUrl?access_token=$token';
        }
      }

      // Prepare headers (keep Authorization header as backup)
      final headers = <String, String>{
        'Accept': '*/*',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      print('📥 Downloading file from: $downloadUrl');

      // Download file
      final response = await http.get(
        Uri.parse(downloadUrl),
        headers: headers,
      );

      print('📥 Download response: ${response.statusCode}');
      print('📥 Content-Type: ${response.headers['content-type']}');
      print('📥 Content-Length: ${response.contentLength}');

      if (response.statusCode == 200) {
        _fileBytes = response.bodyBytes;

        // Determine file type from content-type header or URL
        _fileType = _determineFileType(
          contentType: response.headers['content-type'],
          url: widget.item.fileUrl!,
        );

        print('📄 Detected file type: $_fileType');

        // For PDF, save to temp file for PDFView
        if (_fileType == _FileType.pdf) {
          final tempDir = await getTemporaryDirectory();
          final fileName =
              'circular_${widget.item.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(_fileBytes!);
          _localFilePath = file.path;
        }

        setState(() {
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        // File not found - show user-friendly message
        setState(() {
          _error = 'file_not_available';
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading file: $e');
      setState(() {
        _error = 'Failed to load file: $e';
        _isLoading = false;
      });
    }
  }

  _FileType _determineFileType({String? contentType, required String url}) {
    // Check content-type header first
    if (contentType != null) {
      final ct = contentType.toLowerCase();
      if (ct.contains('pdf')) return _FileType.pdf;
      if (ct.contains('image/')) return _FileType.image;
      if (ct.contains('word') || ct.contains('document')) return _FileType.doc;
      if (ct.contains('excel') || ct.contains('spreadsheet')) {
        return _FileType.excel;
      }
    }

    // Check URL extension
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('.pdf')) return _FileType.pdf;
    if (lowerUrl.contains('.png') ||
        lowerUrl.contains('.jpg') ||
        lowerUrl.contains('.jpeg') ||
        lowerUrl.contains('.gif') ||
        lowerUrl.contains('.webp')) {
      return _FileType.image;
    }
    if (lowerUrl.contains('.doc') || lowerUrl.contains('.docx')) {
      return _FileType.doc;
    }
    if (lowerUrl.contains('.xls') || lowerUrl.contains('.xlsx')) {
      return _FileType.excel;
    }

    // Default to PDF as it's most common for circulars/announcements
    return _FileType.pdf;
  }

  Future<void> _shareFile() async {
    if (_fileBytes == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      String extension = '.pdf';
      switch (_fileType) {
        case _FileType.image:
          extension = '.png';
          break;
        case _FileType.doc:
          extension = '.docx';
          break;
        case _FileType.excel:
          extension = '.xlsx';
          break;
        default:
          extension = '.pdf';
      }

      final baseName = widget.item.displayTitle.trim().isNotEmpty
          ? widget.item.displayTitle.trim()
          : 'announcement_${widget.item.id}';
      final safeName = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName = '$safeName$extension';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(_fileBytes!);

      final shareText = widget.item.displayBody.isNotEmpty
          ? widget.item.displayBody
          : widget.item.displayTitle;

      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: appFontColor,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.displayTitle,
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: null,
              overflow: TextOverflow.visible,
            ),
            Text(
              widget.item.isCircular ? 'Circular' : 'Announcement',
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          if (!_isLoading && _error == null)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: appFontColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.share,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: _shareFile,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: appFontColor),
            SizedBox(height: 16),
            Text('Loading file...'),
          ],
        ),
      );
    }

    if (_error != null) {
      // Special case for file not available (404)
      final isFileNotAvailable = _error == 'file_not_available';

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isFileNotAvailable
                    ? Icons.file_present_outlined
                    : Icons.error_outline,
                size: 64,
                color: isFileNotAvailable ? Colors.grey[400] : Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                isFileNotAvailable
                    ? 'File Not Available'
                    : 'Failed to load file',
                style: GoogleFonts.poppins(
                  fontSize: 18.sp,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isFileNotAvailable
                    ? 'This file is not available or has been removed.\nPlease contact the administrator.'
                    : _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 24),
              if (!isFileNotAvailable)
                ElevatedButton.icon(
                  onPressed: _loadFile,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appFontColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              if (isFileNotAvailable)
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: appFontColor,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    switch (_fileType) {
      case _FileType.pdf:
        return _buildPdfViewer();
      case _FileType.image:
        return _buildImageViewer();
      default:
        return _buildPdfViewer(); // Try PDF viewer for unknown types
    }
  }

  Widget _buildPdfViewer() {
    // Use Syncfusion PDF viewer for network/memory loading
    if (_fileBytes != null) {
      return SfPdfViewer.memory(
        _fileBytes!,
        onDocumentLoadFailed: (details) {
          print('❌ PDF load failed: ${details.description}');
          // Fallback to flutter_pdfview
          if (_localFilePath != null) {
            setState(() {});
          }
        },
      );
    }

    // Fallback to local file viewer
    if (_localFilePath != null) {
      return PDFView(
        filePath: _localFilePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: false,
        pageFling: false,
        onError: (error) {
          print('❌ PDFView error: $error');
        },
        onPageError: (page, error) {
          print('❌ PDFView page $page error: $error');
        },
      );
    }

    return const Center(child: Text('Unable to load PDF'));
  }

  Widget _buildImageViewer() {
    if (_fileBytes == null) {
      return const Center(child: Text('Unable to load image'));
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.memory(
          _fileBytes!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _FileType {
  pdf,
  image,
  doc,
  excel,
  unknown,
}
