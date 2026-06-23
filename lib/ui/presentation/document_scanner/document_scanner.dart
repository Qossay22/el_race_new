/// Document Scanner Module
///
/// A comprehensive document scanning feature for Flutter, similar to CamScanner.
///
/// ## Features
/// - Camera capture with automatic edge detection
/// - Automatic corner adjustment and cropping
/// - Image enhancement filters (Original, Grayscale, B&W, Enhanced)
/// - Multi-page document support
/// - PDF and image export
/// - Share functionality
///
/// ## Simple Usage (Recommended)
/// ```dart
/// import 'package:el_race/ui/presentation/document_scanner/document_scanner.dart';
///
/// // Navigate to the simple scanner (uses cunning_document_scanner)
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => SimpleDocumentScanner(
///       onScanComplete: (imagePaths) {
///         print('Scanned ${imagePaths.length} pages');
///       },
///       onExportComplete: (path, format) {
///         print('Exported to: $path');
///       },
///       maxPages: 10,
///       allowGalleryImport: true,
///     ),
///   ),
/// );
/// ```
///
/// ## Advanced Usage (Custom UI)
/// ```dart
/// // Use the advanced scanner with custom BLoC-based UI
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => DocumentScannerScreen(
///       onDocumentScanned: (document) {
///         print('Scanned ${document.pages.length} pages');
///       },
///     ),
///   ),
/// );
/// ```
library document_scanner;

// Simple Scanner (Recommended - uses cunning_document_scanner)
export 'simple_document_scanner.dart' hide ExportFormat;

// Domain layer
export 'domain/entities/entities.dart';
export 'domain/repositories/document_scanner_repository.dart';
export 'domain/usecases/scan_document_usecase.dart';

// Data layer
export 'data/repositories/document_scanner_repository_impl.dart';
export 'data/services/image_processing_service.dart';
export 'data/services/edge_detection_service.dart';
export 'data/services/document_export_service.dart';

// Presentation layer (Advanced - BLoC-based)
export 'presentation/bloc/document_scanner_bloc.dart';
export 'presentation/bloc/document_scanner_event.dart';
export 'presentation/bloc/document_scanner_state.dart';
export 'presentation/screens/document_scanner_screen.dart';
export 'presentation/screens/scanner_camera_screen.dart';
export 'presentation/screens/crop_adjustment_screen.dart';
export 'presentation/screens/filter_screen.dart';
export 'presentation/screens/document_preview_screen.dart';
export 'presentation/widgets/document_edge_overlay.dart';
export 'presentation/widgets/scanner_controls.dart';
export 'presentation/widgets/corner_handle.dart';
