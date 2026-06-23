import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../utils/safe_insets.dart';

import '../../../core/constants/colors.dart';

/// Image filter options
enum ImageFilter {
  original('Original'),
  grayscale('Grayscale'),
  blackAndWhite('B&W');

  final String displayName;
  const ImageFilter(this.displayName);
}

/// Export format options
enum ExportFormat { pdf, images }

/// Model for a scanned page
class ScannedPage {
  final String originalPath;
  final String currentPath;
  final ImageFilter filter;

  ScannedPage({
    required this.originalPath,
    required this.currentPath,
    required this.filter,
  });

  ScannedPage copyWith({
    String? originalPath,
    String? currentPath,
    ImageFilter? filter,
  }) {
    return ScannedPage(
      originalPath: originalPath ?? this.originalPath,
      currentPath: currentPath ?? this.currentPath,
      filter: filter ?? this.filter,
    );
  }
}

/// Simple Document Scanner using cunning_document_scanner package.
///
/// Opens the scanner directly and shows review screen after scanning.
class SimpleDocumentScanner extends StatefulWidget {
  /// Callback when scanning is complete with file paths
  final void Function(List<String> imagePaths)? onScanComplete;

  /// Callback when export is complete
  final void Function(String exportPath, ExportFormat format)? onExportComplete;

  /// Maximum number of pages to scan (null for unlimited)
  final int? maxPages;

  /// Allow importing from gallery (Android only)
  final bool allowGalleryImport;

  /// Document name for export
  final String? documentName;

  const SimpleDocumentScanner({
    super.key,
    this.onScanComplete,
    this.onExportComplete,
    this.maxPages,
    this.allowGalleryImport = true,
    this.documentName,
  });

  @override
  State<SimpleDocumentScanner> createState() => _SimpleDocumentScannerState();
}

class _SimpleDocumentScannerState extends State<SimpleDocumentScanner> {
  final List<ScannedPage> _scannedPages = [];
  bool _isProcessing = false;
  int _selectedIndex = 0;
  ImageFilter _currentFilter = ImageFilter.original;

  @override
  void initState() {
    super.initState();
    // Start scanning immediately when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScanning();
    });
  }

  Future<void> _startScanning() async {
    try {
      final pictures = await CunningDocumentScanner.getPictures(
        noOfPages: widget.maxPages ?? 100,
        isGalleryImportAllowed: widget.allowGalleryImport,
      );

      if (pictures == null || pictures.isEmpty) {
        // User cancelled - go back
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      // Add scanned pages
      for (final path in pictures) {
        _scannedPages.add(ScannedPage(
          originalPath: path,
          currentPath: path,
          filter: ImageFilter.original,
        ));
      }

      widget.onScanComplete?.call(pictures);

      setState(() {});
    } on PlatformException catch (e) {
      debugPrint('Scan error: ${e.message}');
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If no pages scanned yet, show loading
    if (_scannedPages.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: CustomColors.blue),
              const SizedBox(height: 16),
              const Text(
                'Opening Scanner...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Show review screen
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(child: _buildImageViewer()),
            _buildFilterOptions(),
            if (_scannedPages.length > 1) _buildThumbnailList(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.black,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              '${_scannedPages.length} ${_scannedPages.length > 1 ? 'Pages' : 'Page'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_a_photo, color: Colors.white),
            onPressed: _addMorePages,
            tooltip: 'Add More',
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _showExportOptions,
            tooltip: 'Export',
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewer() {
    if (_scannedPages.isEmpty) {
      return const Center(
        child: Text(
          'No images scanned',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final currentImage = _scannedPages[_selectedIndex];

    return Stack(
      children: [
        GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! < 0 &&
                _selectedIndex < _scannedPages.length - 1) {
              setState(() => _selectedIndex++);
            } else if (details.primaryVelocity! > 0 && _selectedIndex > 0) {
              setState(() => _selectedIndex--);
            }
          },
          child: InteractiveViewer(
            child: Center(
              child: Image.file(
                File(currentImage.currentPath),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterOptions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.black,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: ImageFilter.values.map((filter) {
            final isSelected = _currentFilter == filter;
            return GestureDetector(
              onTap: () => _applyFilter(filter),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? CustomColors.blue
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  filter.displayName,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildThumbnailList() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.black,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _scannedPages.length,
        itemBuilder: (context, index) {
          final page = _scannedPages[index];
          final isSelected = index == _selectedIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = index;
              });
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? CustomColors.blue : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(page.currentPath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
              Icons.delete_outline, 'Delete', _deleteCurrentPage),
          _buildActionButton(Icons.rotate_right, 'Rotate', _rotateCurrentPage),
          _buildActionButton(Icons.share, 'Share', _shareCurrentPage),
          _buildActionButton(Icons.picture_as_pdf, 'PDF', _exportAsPdf),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ==================== ACTIONS ====================

  Future<void> _addMorePages() async {
    try {
      final pictures = await CunningDocumentScanner.getPictures(
        noOfPages: widget.maxPages ?? 100,
        isGalleryImportAllowed: widget.allowGalleryImport,
      );

      if (pictures == null || pictures.isEmpty) {
        return;
      }

      for (final path in pictures) {
        _scannedPages.add(ScannedPage(
          originalPath: path,
          currentPath: path,
          filter: ImageFilter.original,
        ));
      }

      setState(() {
        _selectedIndex = _scannedPages.length - 1;
      });
    } on PlatformException catch (e) {
      debugPrint('Scan error: ${e.message}');
    }
  }

  Future<void> _applyFilter(ImageFilter filter) async {
    if (_scannedPages.isEmpty) return;

    setState(() {
      _currentFilter = filter;
      _isProcessing = true;
    });

    try {
      final page = _scannedPages[_selectedIndex];
      final newPath = await _processImageWithFilter(page.originalPath, filter);

      setState(() {
        _scannedPages[_selectedIndex] = page.copyWith(
          currentPath: newPath,
          filter: filter,
        );
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showSnackBar('Failed to apply filter');
    }
  }

  Future<String> _processImageWithFilter(
      String imagePath, ImageFilter filter) async {
    if (filter == ImageFilter.original) {
      return imagePath;
    }

    final bytes = await File(imagePath).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return imagePath;

    switch (filter) {
      case ImageFilter.grayscale:
        image = img.grayscale(image);
        break;
      case ImageFilter.blackAndWhite:
        image = img.grayscale(image);
        image = img.adjustColor(image, contrast: 1.5);
        for (int y = 0; y < image.height; y++) {
          for (int x = 0; x < image.width; x++) {
            final pixel = image.getPixel(x, y);
            final luminance = img.getLuminance(pixel);
            final newColor = luminance > 128
                ? img.ColorFloat32.rgb(255, 255, 255)
                : img.ColorFloat32.rgb(0, 0, 0);
            image.setPixel(x, y, newColor);
          }
        }
        break;
      case ImageFilter.original:
        break;
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = 'filtered_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = '${tempDir.path}/$fileName';
    await File(filePath).writeAsBytes(img.encodeJpg(image, quality: 90));

    return filePath;
  }

  void _deleteCurrentPage() {
    if (_scannedPages.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Page'),
        content: const Text('Are you sure you want to delete this page?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _scannedPages.removeAt(_selectedIndex);
                if (_scannedPages.isEmpty) {
                  Navigator.of(context).pop();
                } else if (_selectedIndex >= _scannedPages.length) {
                  _selectedIndex = _scannedPages.length - 1;
                }
              });
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _rotateCurrentPage() async {
    if (_scannedPages.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final page = _scannedPages[_selectedIndex];
      final bytes = await File(page.currentPath).readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) {
        setState(() => _isProcessing = false);
        return;
      }

      image = img.copyRotate(image, angle: 90);

      final tempDir = await getTemporaryDirectory();
      final fileName = 'rotated_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${tempDir.path}/$fileName';
      await File(filePath).writeAsBytes(img.encodeJpg(image, quality: 90));

      setState(() {
        _scannedPages[_selectedIndex] = page.copyWith(currentPath: filePath);
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnackBar('Failed to rotate image');
    }
  }

  Future<void> _shareCurrentPage() async {
    if (_scannedPages.isEmpty) return;

    try {
      final page = _scannedPages[_selectedIndex];
      await Share.shareXFiles(
        [XFile(page.currentPath)],
        text: 'Scanned Document',
      );
    } catch (e) {
      _showSnackBar('Failed to share');
    }
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Export As',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildExportOption(
              icon: Icons.picture_as_pdf,
              title: 'PDF Document',
              subtitle: 'Export all pages as a single PDF',
              onTap: () {
                Navigator.pop(ctx);
                _exportAsPdf();
              },
            ),
            const SizedBox(height: 12),
            _buildExportOption(
              icon: Icons.image,
              title: 'Images',
              subtitle: 'Share as individual images',
              onTap: () {
                Navigator.pop(ctx);
                _shareAllImages();
              },
            ),
            SizedBox(height: context.systemBottomInset + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: CustomColors.blue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
      onTap: onTap,
    );
  }

  Future<void> _exportAsPdf() async {
    setState(() => _isProcessing = true);

    try {
      final pdf = pw.Document();

      for (final page in _scannedPages) {
        final imageBytes = await File(page.currentPath).readAsBytes();
        final pdfImage = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName = widget.documentName ??
          'scan_${DateTime.now().millisecondsSinceEpoch}';
      final filePath = '${dir.path}/$fileName.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      widget.onExportComplete?.call(filePath, ExportFormat.pdf);

      setState(() => _isProcessing = false);
      _showSnackBar('PDF created');

      // Share the PDF
      await Share.shareXFiles([XFile(filePath)], text: 'Scanned Document');
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnackBar('Failed to create PDF');
    }
  }

  Future<void> _shareAllImages() async {
    try {
      final List<XFile> files =
          _scannedPages.map((page) => XFile(page.currentPath)).toList();

      await Share.shareXFiles(files, text: 'Scanned Documents');
    } catch (e) {
      _showSnackBar('Failed to share images');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.grey[800],
      ),
    );
  }
}
