import 'dart:typed_data';
import 'dart:ui';

import '../entities/entities.dart';

/// Repository interface for document scanning operations.
///
/// This interface defines the contract for all document scanning operations,
/// following the Dependency Inversion Principle. The implementation details
/// are abstracted away from the domain layer.
abstract class IDocumentScannerRepository {
  /// Captures an image from the camera and returns the file path.
  ///
  /// Returns the path to the captured image file.
  /// Throws [CaptureException] if capture fails.
  Future<String> captureImage();

  /// Detects document edges in the given image.
  ///
  /// [imagePath] - Path to the image to analyze
  /// Returns a list of 4 corner points if a document is detected,
  /// or null if no document edges are found.
  Future<List<Offset>?> detectEdges(String imagePath);

  /// Detects document edges from image bytes (for real-time detection).
  ///
  /// [imageBytes] - Raw image bytes
  /// [imageWidth] - Width of the image
  /// [imageHeight] - Height of the image
  /// Returns corner points if detected, null otherwise.
  Future<List<Offset>?> detectEdgesFromBytes(
    Uint8List imageBytes,
    int imageWidth,
    int imageHeight,
  );

  /// Applies perspective correction to crop the document.
  ///
  /// [imagePath] - Path to the original image
  /// [corners] - Four corner points defining the document boundary
  /// Returns the path to the cropped and corrected image.
  Future<String> applyPerspectiveCorrection(
    String imagePath,
    List<Offset> corners,
  );

  /// Applies an image filter to the document.
  ///
  /// [imagePath] - Path to the image
  /// [filterType] - Type of filter to apply
  /// Returns the path to the filtered image.
  Future<String> applyFilter(String imagePath, ImageFilterType filterType);

  /// Generates a thumbnail from an image.
  ///
  /// [imagePath] - Path to the source image
  /// [maxSize] - Maximum dimension (width or height) of thumbnail
  /// Returns the thumbnail as bytes.
  Future<Uint8List> generateThumbnail(String imagePath, {int maxSize = 200});

  /// Gets the dimensions of an image.
  ///
  /// [imagePath] - Path to the image
  /// Returns the Size of the image.
  Future<Size> getImageSize(String imagePath);

  /// Exports pages as a PDF document.
  ///
  /// [pages] - List of pages to include
  /// [outputPath] - Path where the PDF should be saved
  /// [quality] - Export quality setting
  /// Returns the path to the created PDF.
  Future<String> exportToPdf(
    List<DocumentPage> pages,
    String outputPath,
    ExportQuality quality,
  );

  /// Exports a page as an image.
  ///
  /// [page] - The page to export
  /// [outputPath] - Path where the image should be saved
  /// [format] - Image format (JPEG or PNG)
  /// [quality] - Export quality setting
  /// Returns the path to the exported image.
  Future<String> exportToImage(
    DocumentPage page,
    String outputPath,
    ExportFormat format,
    ExportQuality quality,
  );

  /// Exports all pages as individual images.
  ///
  /// [pages] - List of pages to export
  /// [outputDirectory] - Directory where images should be saved
  /// [format] - Image format
  /// [quality] - Export quality
  /// Returns list of paths to exported images.
  Future<List<String>> exportAllToImages(
    List<DocumentPage> pages,
    String outputDirectory,
    ExportFormat format,
    ExportQuality quality,
  );

  /// Saves the processed image to a permanent location.
  ///
  /// [sourcePath] - Path to the source image
  /// [documentId] - ID of the document for organizing
  /// [pageNumber] - Page number for naming
  /// Returns the permanent storage path.
  Future<String> saveProcessedImage(
    String sourcePath,
    String documentId,
    int pageNumber,
  );

  /// Cleans up temporary files for a document.
  ///
  /// [documentId] - ID of the document to clean up
  Future<void> cleanupTemporaryFiles(String documentId);

  /// Gets the application's document storage directory.
  Future<String> getDocumentStorageDirectory();
}

/// Exception thrown when image capture fails
class CaptureException implements Exception {
  final String message;
  final dynamic originalError;

  const CaptureException(this.message, [this.originalError]);

  @override
  String toString() => 'CaptureException: $message';
}

/// Exception thrown when edge detection fails
class EdgeDetectionException implements Exception {
  final String message;
  final dynamic originalError;

  const EdgeDetectionException(this.message, [this.originalError]);

  @override
  String toString() => 'EdgeDetectionException: $message';
}

/// Exception thrown when image processing fails
class ImageProcessingException implements Exception {
  final String message;
  final dynamic originalError;

  const ImageProcessingException(this.message, [this.originalError]);

  @override
  String toString() => 'ImageProcessingException: $message';
}

/// Exception thrown when export fails
class ExportException implements Exception {
  final String message;
  final dynamic originalError;

  const ExportException(this.message, [this.originalError]);

  @override
  String toString() => 'ExportException: $message';
}
