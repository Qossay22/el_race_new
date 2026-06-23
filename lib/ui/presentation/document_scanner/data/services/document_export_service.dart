import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/entities.dart';

/// Service for exporting scanned documents.
///
/// Supports exporting to:
/// - PDF (single or multi-page)
/// - JPEG images
/// - PNG images
class DocumentExportService {
  /// Exports pages as a multi-page PDF document.
  ///
  /// [pages] - List of pages to include in PDF
  /// [outputPath] - Path where PDF should be saved
  /// [quality] - Export quality setting
  /// Returns the path to the created PDF.
  Future<String> exportToPdf(
    List<DocumentPage> pages,
    String outputPath,
    ExportQuality quality,
  ) async {
    final pdf = pw.Document();

    for (final page in pages) {
      final imagePath = page.processedImagePath ?? page.originalImagePath;
      final imageBytes = await File(imagePath).readAsBytes();

      // Determine page format based on image aspect ratio
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Center(
              child: pw.Image(
                image,
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );
    }

    // Save PDF
    final file = File(outputPath);
    await file.writeAsBytes(await pdf.save());

    return outputPath;
  }

  /// Exports a single page as an image.
  ///
  /// [page] - The page to export
  /// [outputPath] - Path where image should be saved
  /// [format] - Image format (JPEG or PNG)
  /// [quality] - Export quality setting
  /// Returns the path to the exported image.
  Future<String> exportToImage(
    DocumentPage page,
    String outputPath,
    ExportFormat format,
    ExportQuality quality,
  ) async {
    final sourcePath = page.processedImagePath ?? page.originalImagePath;
    final sourceBytes = await File(sourcePath).readAsBytes();

    // For now, just copy the file with appropriate extension
    // In production, you might want to re-encode with specific quality
    final file = File(outputPath);
    await file.writeAsBytes(sourceBytes);

    return outputPath;
  }

  /// Exports all pages as individual images.
  ///
  /// [pages] - List of pages to export
  /// [outputDirectory] - Directory where images should be saved
  /// [format] - Image format
  /// [quality] - Export quality
  /// [baseName] - Base name for image files
  /// Returns list of paths to exported images.
  Future<List<String>> exportAllToImages(
    List<DocumentPage> pages,
    String outputDirectory,
    ExportFormat format,
    ExportQuality quality, {
    String baseName = 'page',
  }) async {
    // Ensure directory exists
    final dir = Directory(outputDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final paths = <String>[];

    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];
      final extension = format == ExportFormat.png ? '.png' : '.jpg';
      final outputPath = '$outputDirectory/${baseName}_${i + 1}$extension';

      final exportedPath = await exportToImage(
        page,
        outputPath,
        format,
        quality,
      );
      paths.add(exportedPath);
    }

    return paths;
  }

  /// Gets the default export directory for documents.
  Future<String> getExportDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${appDir.path}/scanned_documents');

    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    return exportDir.path;
  }

  /// Shares a file using the system share sheet.
  /// This is a placeholder - the actual implementation depends on
  /// share_plus or similar package.
  Future<void> shareFile(String filePath) async {
    // Implementation would use share_plus package
    // Share.shareFiles([filePath]);
  }

  /// Opens a file with the system default application.
  Future<void> openFile(String filePath) async {
    // Implementation would use open_file or url_launcher package
  }
}
