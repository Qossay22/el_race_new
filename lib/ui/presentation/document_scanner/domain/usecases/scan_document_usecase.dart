import 'dart:typed_data';
import 'dart:ui';

import 'package:uuid/uuid.dart';

import '../entities/entities.dart';
import '../repositories/document_scanner_repository.dart';

/// Use case for managing the complete document scanning workflow.
///
/// This use case orchestrates the scanning process from capture to export,
/// maintaining the scanned document state throughout the session.
class ScanDocumentUseCase {
  final IDocumentScannerRepository _repository;
  final Uuid _uuid = const Uuid();

  ScanDocumentUseCase({required IDocumentScannerRepository repository})
      : _repository = repository;

  /// Creates a new empty document for scanning session.
  ScannedDocument createNewDocument({String? name}) {
    final now = DateTime.now();
    return ScannedDocument(
      id: _uuid.v4(),
      name: name ?? 'Scan_${now.millisecondsSinceEpoch}',
      pages: const [],
      createdAt: now,
      modifiedAt: now,
    );
  }

  /// Captures a new page and adds it to the document.
  ///
  /// [document] - The current document
  /// [imagePath] - Path to the captured image
  /// [autoDetectEdges] - Whether to automatically detect edges
  /// Returns the updated document with the new page.
  Future<ScannedDocument> addCapturedPage(
    ScannedDocument document,
    String imagePath, {
    bool autoDetectEdges = true,
  }) async {
    // Detect edges if enabled
    List<Offset>? detectedCorners;
    bool edgeDetectionSuccessful = false;

    // Get image size for corner calculations
    Size imageSize;
    try {
      imageSize = await _repository.getImageSize(imagePath);
    } catch (e) {
      // Default size if we can't read the image
      imageSize = const Size(1920, 1080);
    }

    if (autoDetectEdges) {
      try {
        detectedCorners = await _repository.detectEdges(imagePath);
        edgeDetectionSuccessful =
            detectedCorners != null && detectedCorners.length == 4;
      } catch (e) {
        // Edge detection failed, continue without corners
        edgeDetectionSuccessful = false;
      }
    }

    // If no corners detected, use full image bounds
    detectedCorners ??= [
      const Offset(0, 0),
      Offset(imageSize.width, 0),
      Offset(imageSize.width, imageSize.height),
      Offset(0, imageSize.height),
    ];

    // Generate thumbnail (optional - continue even if it fails)
    Uint8List? thumbnail;
    try {
      thumbnail = await _repository.generateThumbnail(imagePath);
    } catch (e) {
      // Thumbnail generation failed, continue without it
      thumbnail = null;
    }

    // Create the page
    final page = DocumentPage(
      id: _uuid.v4(),
      originalImagePath: imagePath,
      pageNumber: document.pages.length + 1,
      capturedAt: DateTime.now(),
      detectedCorners: detectedCorners,
      edgeDetectionSuccessful: edgeDetectionSuccessful,
      originalSize: imageSize,
      thumbnail: thumbnail,
    );

    return document.addPage(page);
  }

  /// Updates the corners for a page (after manual adjustment).
  Future<ScannedDocument> updatePageCorners(
    ScannedDocument document,
    String pageId,
    List<Offset> newCorners,
  ) async {
    final page = document.pages.firstWhere((p) => p.id == pageId);
    final updatedPage = page.copyWith(adjustedCorners: newCorners);
    return document.updatePage(updatedPage);
  }

  /// Processes a page with perspective correction and filter.
  ///
  /// [document] - The current document
  /// [pageId] - ID of the page to process
  /// [filterType] - Filter to apply
  /// Returns updated document with processed page.
  Future<ScannedDocument> processPage(
    ScannedDocument document,
    String pageId, {
    ImageFilterType filterType = ImageFilterType.original,
  }) async {
    final page = document.pages.firstWhere((p) => p.id == pageId);
    final corners = page.effectiveCorners;

    if (corners == null || corners.length != 4) {
      throw ImageProcessingException('Invalid corners for page $pageId');
    }

    // Apply perspective correction
    final correctedPath = await _repository.applyPerspectiveCorrection(
      page.originalImagePath,
      corners,
    );

    // Apply filter
    final filteredPath =
        await _repository.applyFilter(correctedPath, filterType);

    // Save to permanent location
    final savedPath = await _repository.saveProcessedImage(
      filteredPath,
      document.id,
      page.pageNumber,
    );

    // Generate new thumbnail
    final thumbnail = await _repository.generateThumbnail(savedPath);

    final updatedPage = page.copyWith(
      processedImagePath: savedPath,
      filterType: filterType,
      thumbnail: thumbnail,
    );

    return document.updatePage(updatedPage);
  }

  /// Applies a filter to all pages in the document.
  Future<ScannedDocument> applyFilterToAll(
    ScannedDocument document,
    ImageFilterType filterType,
  ) async {
    var updatedDocument = document;

    for (final page in document.pages) {
      updatedDocument = await processPage(
        updatedDocument,
        page.id,
        filterType: filterType,
      );
    }

    return updatedDocument;
  }

  /// Exports the document as a PDF.
  Future<ScannedDocument> exportAsPdf(
    ScannedDocument document, {
    ExportQuality quality = ExportQuality.high,
  }) async {
    final directory = await _repository.getDocumentStorageDirectory();
    final outputPath = '$directory/${document.name}.pdf';

    final pdfPath = await _repository.exportToPdf(
      document.pages,
      outputPath,
      quality,
    );

    return document.copyWith(
      exportedPdfPath: pdfPath,
      modifiedAt: DateTime.now(),
    );
  }

  /// Exports the document as images.
  Future<ScannedDocument> exportAsImages(
    ScannedDocument document, {
    ExportFormat format = ExportFormat.jpeg,
    ExportQuality quality = ExportQuality.high,
  }) async {
    final directory = await _repository.getDocumentStorageDirectory();
    final outputDirectory = '$directory/${document.name}';

    final imagePaths = await _repository.exportAllToImages(
      document.pages,
      outputDirectory,
      format,
      quality,
    );

    return document.copyWith(
      exportedImagePaths: imagePaths,
      modifiedAt: DateTime.now(),
    );
  }

  /// Removes a page from the document.
  Future<ScannedDocument> removePage(
    ScannedDocument document,
    String pageId,
  ) async {
    return document.removePage(pageId);
  }

  /// Reorders pages in the document.
  Future<ScannedDocument> reorderPages(
    ScannedDocument document,
    List<String> newOrder,
  ) async {
    return document.reorderPages(newOrder);
  }

  /// Cleans up temporary files when done.
  Future<void> cleanup(ScannedDocument document) async {
    await _repository.cleanupTemporaryFiles(document.id);
  }
}
