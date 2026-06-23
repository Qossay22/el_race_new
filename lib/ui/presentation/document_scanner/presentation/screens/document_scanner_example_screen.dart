import 'package:flutter/material.dart';

import '../../simple_document_scanner.dart';

/// Example screen demonstrating the document scanner feature.
///
/// This screen shows how to integrate the document scanner into your app
/// and handle the scanned document results.
class DocumentScannerExampleScreen extends StatefulWidget {
  const DocumentScannerExampleScreen({super.key});

  @override
  State<DocumentScannerExampleScreen> createState() =>
      _DocumentScannerExampleScreenState();
}

class _DocumentScannerExampleScreenState
    extends State<DocumentScannerExampleScreen> {
  List<String>? _lastScannedPaths;
  String? _lastExportPath;
  ExportFormat? _lastExportFormat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Scanner'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHeader(),

            const SizedBox(height: 24),

            // Scan button
            _buildScanButton(),

            const SizedBox(height: 24),

            // Last scanned document info
            if (_lastScannedPaths != null && _lastScannedPaths!.isNotEmpty)
              _buildLastDocumentInfo(),

            const SizedBox(height: 24),

            // Features info
            _buildFeaturesInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.document_scanner,
              size: 64,
              color: Colors.blue[700],
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan Documents',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Capture, enhance, and export documents with ease',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return ElevatedButton.icon(
      onPressed: _openScanner,
      icon: const Icon(Icons.camera_alt, size: 28),
      label: const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Start Scanning',
          style: TextStyle(fontSize: 18),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildLastDocumentInfo() {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text(
                  'Last Scanned Document',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Pages', '${_lastScannedPaths!.length}'),
            if (_lastExportPath != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                'Export Format',
                _lastExportFormat == ExportFormat.pdf ? 'PDF' : 'Images',
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Path', _lastExportPath!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Features',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              Icons.auto_fix_high,
              'Automatic Edge Detection',
              'Automatically detects document edges',
            ),
            _buildFeatureItem(
              Icons.crop,
              'Smart Cropping',
              'Crops and adjusts perspective automatically',
            ),
            _buildFeatureItem(
              Icons.filter,
              'Image Filters',
              'Apply Original, Grayscale, B&W, or Enhanced filters',
            ),
            _buildFeatureItem(
              Icons.pages,
              'Multi-Page Scanning',
              'Scan multiple pages into one document',
            ),
            _buildFeatureItem(
              Icons.picture_as_pdf,
              'PDF Export',
              'Export documents as PDF files',
            ),
            _buildFeatureItem(
              Icons.share,
              'Easy Sharing',
              'Share scanned documents instantly',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SimpleDocumentScanner(
          maxPages: 10,
          allowGalleryImport: true,
          documentName: 'MyDocument_${DateTime.now().millisecondsSinceEpoch}',
          onScanComplete: (imagePaths) {
            setState(() {
              _lastScannedPaths = imagePaths;
            });
          },
          onExportComplete: (path, format) {
            setState(() {
              _lastExportPath = path;
              _lastExportFormat = format;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Exported ${format == ExportFormat.pdf ? "PDF" : "Images"} to: $path',
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          },
        ),
      ),
    );
  }
}
