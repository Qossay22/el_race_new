import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/entities.dart';
import '../../domain/repositories/document_scanner_repository.dart';
import '../services/document_export_service.dart';
import '../services/edge_detection_service.dart';
import '../services/image_processing_service.dart';

/// Implementation of the document scanner repository.
///
/// This class coordinates between different services to provide
/// a unified interface for document scanning operations.
class DocumentScannerRepositoryImpl implements IDocumentScannerRepository {
  final ImageProcessingService _imageProcessingService;
  final EdgeDetectionService _edgeDetectionService;
  final DocumentExportService _exportService;
  final Uuid _uuid = const Uuid();

  /// Temporary directory for processing
  Directory? _tempDirectory;

  /// Storage directory for permanent files
  Directory? _storageDirectory;

  DocumentScannerRepositoryImpl({
    ImageProcessingService? imageProcessingService,
    EdgeDetectionService? edgeDetectionService,
    DocumentExportService? exportService,
  })  : _imageProcessingService =
            imageProcessingService ?? ImageProcessingService(),
        _edgeDetectionService = edgeDetectionService ?? EdgeDetectionService(),
        _exportService = exportService ?? DocumentExportService();

  /// Initializes directories if needed.
  Future<void> _ensureDirectories() async {
    if (_tempDirectory == null) {
      final tempDir = await getTemporaryDirectory();
      _tempDirectory = Directory('${tempDir.path}/document_scanner');
      if (!await _tempDirectory!.exists()) {
        await _tempDirectory!.create(recursive: true);
      }
    }

    if (_storageDirectory == null) {
      final appDir = await getApplicationDocumentsDirectory();
      _storageDirectory = Directory('${appDir.path}/scanned_documents');
      if (!await _storageDirectory!.exists()) {
        await _storageDirectory!.create(recursive: true);
      }
    }
  }

  @override
  Future<String> captureImage() async {
    // This is handled by the camera controller in the presentation layer
    // This method can be used to post-process the captured image
    throw UnimplementedError('Capture is handled by CameraController');
  }

  @override
  Future<List<ui.Offset>?> detectEdges(String imagePath) async {
    try {
      return await _edgeDetectionService.detectEdges(imagePath);
    } catch (e) {
      throw EdgeDetectionException('Failed to detect edges', e);
    }
  }

  @override
  Future<List<ui.Offset>?> detectEdgesFromBytes(
    Uint8List imageBytes,
    int imageWidth,
    int imageHeight,
  ) async {
    try {
      return await _edgeDetectionService.detectEdgesWithDimensions(
        imageBytes,
        imageWidth,
        imageHeight,
      );
    } catch (e) {
      throw EdgeDetectionException('Failed to detect edges from bytes', e);
    }
  }

  @override
  Future<String> applyPerspectiveCorrection(
    String imagePath,
    List<ui.Offset> corners,
  ) async {
    await _ensureDirectories();

    try {
      final outputPath = '${_tempDirectory!.path}/corrected_${_uuid.v4()}.jpg';
      return await _imageProcessingService.applyPerspectiveCorrection(
        imagePath,
        corners,
        outputPath,
      );
    } catch (e) {
      throw ImageProcessingException(
          'Failed to apply perspective correction', e);
    }
  }

  @override
  Future<String> applyFilter(
      String imagePath, ImageFilterType filterType) async {
    await _ensureDirectories();

    try {
      final outputPath = '${_tempDirectory!.path}/filtered_${_uuid.v4()}.jpg';
      return await _imageProcessingService.applyFilter(
        imagePath,
        filterType,
        outputPath,
      );
    } catch (e) {
      throw ImageProcessingException('Failed to apply filter', e);
    }
  }

  @override
  Future<Uint8List> generateThumbnail(String imagePath,
      {int maxSize = 200}) async {
    try {
      return await _imageProcessingService.generateThumbnail(imagePath,
          maxSize: maxSize);
    } catch (e) {
      throw ImageProcessingException('Failed to generate thumbnail', e);
    }
  }

  @override
  Future<ui.Size> getImageSize(String imagePath) async {
    try {
      return await _imageProcessingService.getImageSize(imagePath);
    } catch (e) {
      throw ImageProcessingException('Failed to get image size', e);
    }
  }

  @override
  Future<String> exportToPdf(
    List<DocumentPage> pages,
    String outputPath,
    ExportQuality quality,
  ) async {
    try {
      return await _exportService.exportToPdf(pages, outputPath, quality);
    } catch (e) {
      throw ExportException('Failed to export to PDF', e);
    }
  }

  @override
  Future<String> exportToImage(
    DocumentPage page,
    String outputPath,
    ExportFormat format,
    ExportQuality quality,
  ) async {
    try {
      return await _exportService.exportToImage(
          page, outputPath, format, quality);
    } catch (e) {
      throw ExportException('Failed to export to image', e);
    }
  }

  @override
  Future<List<String>> exportAllToImages(
    List<DocumentPage> pages,
    String outputDirectory,
    ExportFormat format,
    ExportQuality quality,
  ) async {
    try {
      return await _exportService.exportAllToImages(
        pages,
        outputDirectory,
        format,
        quality,
      );
    } catch (e) {
      throw ExportException('Failed to export images', e);
    }
  }

  @override
  Future<String> saveProcessedImage(
    String sourcePath,
    String documentId,
    int pageNumber,
  ) async {
    await _ensureDirectories();

    try {
      final docDir = Directory('${_storageDirectory!.path}/$documentId');
      if (!await docDir.exists()) {
        await docDir.create(recursive: true);
      }

      final destPath = '${docDir.path}/page_$pageNumber.jpg';
      final sourceFile = File(sourcePath);
      await sourceFile.copy(destPath);

      return destPath;
    } catch (e) {
      throw ImageProcessingException('Failed to save processed image', e);
    }
  }

  @override
  Future<void> cleanupTemporaryFiles(String documentId) async {
    await _ensureDirectories();

    try {
      // Clean temp directory
      if (await _tempDirectory!.exists()) {
        final files = await _tempDirectory!.list().toList();
        for (final file in files) {
          if (file is File) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  @override
  Future<String> getDocumentStorageDirectory() async {
    await _ensureDirectories();
    return _storageDirectory!.path;
  }
}
