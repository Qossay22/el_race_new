import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../utils/safe_insets.dart';

import '../../domain/entities/entities.dart';
import '../bloc/document_scanner_bloc.dart';
import '../bloc/document_scanner_event.dart';
import '../bloc/document_scanner_state.dart';
import 'filter_screen.dart';

/// Screen for previewing scanned document before export.
///
/// Features:
/// - Page thumbnail grid/list view
/// - Reorder pages
/// - Delete pages
/// - Edit individual pages
/// - Export options
class DocumentPreviewScreen extends StatefulWidget {
  /// Callback when user wants to add more pages
  final VoidCallback? onAddPages;

  /// Callback when export is complete
  final void Function(String path, ExportFormat format)? onExportComplete;

  const DocumentPreviewScreen({
    super.key,
    this.onAddPages,
    this.onExportComplete,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  bool _isGridView = true;
  int _selectedPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DocumentScannerBloc, DocumentScannerState>(
      listenWhen: (previous, current) =>
          previous.phase != current.phase ||
          previous.exportedFilePath != current.exportedFilePath,
      listener: (context, state) {
        if (state.phase == ScannerPhase.completed &&
            state.exportedFilePath != null) {
          widget.onExportComplete?.call(
            state.exportedFilePath!,
            state.exportFormat ?? ExportFormat.pdf,
          );

          // Show success dialog
          _showExportSuccessDialog(
            context,
            state.exportedFilePath!,
            state.exportFormat ?? ExportFormat.pdf,
          );
        }
      },
      builder: (context, state) {
        final document = state.document;
        if (document == null || !document.hasPages) {
          return _buildEmptyState(context);
        }

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: _buildAppBar(context, document),
          body: Stack(
            children: [
              Column(
                children: [
                  // View toggle
                  _buildViewToggle(),

                  // Page grid or list
                  Expanded(
                    child: _isGridView
                        ? _buildGridView(document)
                        : _buildPageView(document),
                  ),
                ],
              ),

              // Processing overlay
              if (state.isProcessing)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          if (state.processingMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(state.processingMessage!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(context, document),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, ScannedDocument document) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            document.name,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${document.pageCount} ${document.pageCount == 1 ? 'page' : 'pages'}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        // Rename
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.black87),
          onPressed: () => _showRenameDialog(context, document),
        ),
        // More options
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.black87),
          onSelected: (value) => _handleMenuAction(context, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'select_all_filter',
              child: Text('Apply filter to all'),
            ),
            const PopupMenuItem(
              value: 'delete_all',
              child: Text('Delete all pages'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildToggleButton(
            icon: Icons.grid_view,
            isSelected: _isGridView,
            onTap: () => setState(() => _isGridView = true),
          ),
          const SizedBox(width: 8),
          _buildToggleButton(
            icon: Icons.view_carousel,
            isSelected: !_isGridView,
            onTap: () => setState(() => _isGridView = false),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey[600],
          size: 24,
        ),
      ),
    );
  }

  Widget _buildGridView(ScannedDocument document) {
    return ReorderableGridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.7,
      onReorder: (oldIndex, newIndex) {
        _handleReorder(document, oldIndex, newIndex);
      },
      children: List.generate(document.pages.length, (index) {
        final page = document.pages[index];
        return _buildPageCard(page, index, key: ValueKey(page.id));
      }),
    );
  }

  Widget _buildPageView(ScannedDocument document) {
    return PageView.builder(
      controller: PageController(initialPage: _selectedPageIndex),
      onPageChanged: (index) {
        setState(() => _selectedPageIndex = index);
      },
      itemCount: document.pages.length,
      itemBuilder: (context, index) {
        final page = document.pages[index];
        return _buildFullPageView(page, index);
      },
    );
  }

  Widget _buildPageCard(DocumentPage page, int index, {Key? key}) {
    return GestureDetector(
      key: key,
      onTap: () => _showPageOptions(context, page),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: _buildPageImage(page),
              ),
            ),

            // Page number and actions
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Page ${page.pageNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Filter indicator
                      if (page.filterType != ImageFilterType.original)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            page.filterType.displayName,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                            ),
                          ),
                        ),

                      const SizedBox(width: 4),

                      // Delete button
                      GestureDetector(
                        onTap: () => _confirmDelete(context, page),
                        child: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullPageView(DocumentPage page, int index) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Full image
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildPageImage(page),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Page actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.tune,
                label: 'Filter',
                onTap: () => _openFilterScreen(page),
              ),
              _buildActionButton(
                icon: Icons.crop,
                label: 'Crop',
                onTap: () => _openCropScreen(page),
              ),
              _buildActionButton(
                icon: Icons.rotate_right,
                label: 'Rotate',
                onTap: () => _rotatePage(page),
              ),
              _buildActionButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                onTap: () => _confirmDelete(context, page),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageImage(DocumentPage page) {
    final imagePath = page.processedImagePath ?? page.originalImagePath;

    if (page.thumbnail != null) {
      return Image.memory(
        page.thumbnail!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Image.file(
      File(imagePath),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[200],
          child: const Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 48,
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ScannedDocument document) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + context.systemBottomInset, // Use viewPadding not padding
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Add more pages
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onAddPages,
              icon: const Icon(Icons.add),
              label: const Text('Add Pages'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Export
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => _showExportOptions(context),
              icon: const Icon(Icons.save_alt),
              label: const Text('Export'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Document Preview',
          style: TextStyle(color: Colors.black87),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No pages scanned',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onAddPages,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan Document'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Export As',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // PDF option
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: const Text('PDF Document'),
                  subtitle: const Text('Best for sharing and printing'),
                  onTap: () {
                    Navigator.pop(context);
                    context.read<DocumentScannerBloc>().add(
                          const ExportAsPdf(),
                        );
                  },
                ),

                // JPEG option
                ListTile(
                  leading: const Icon(Icons.image, color: Colors.green),
                  title: const Text('JPEG Images'),
                  subtitle: const Text('Smaller file size'),
                  onTap: () {
                    Navigator.pop(context);
                    context.read<DocumentScannerBloc>().add(
                          const ExportAsImages(format: ExportFormat.jpeg),
                        );
                  },
                ),

                // PNG option
                ListTile(
                  leading: const Icon(Icons.image, color: Colors.blue),
                  title: const Text('PNG Images'),
                  subtitle: const Text('Best quality, larger size'),
                  onTap: () {
                    Navigator.pop(context);
                    context.read<DocumentScannerBloc>().add(
                          const ExportAsImages(format: ExportFormat.png),
                        );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExportSuccessDialog(
    BuildContext context,
    String filePath,
    ExportFormat format,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Export Complete'),
            ],
          ),
          content: Text(
            'Document exported successfully as ${format.displayName}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Share.shareXFiles([XFile(filePath)]);
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, ScannedDocument document) {
    final controller = TextEditingController(text: document.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Document'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Document Name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  context.read<DocumentScannerBloc>().add(
                        SetDocumentName(name: controller.text),
                      );
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showPageOptions(BuildContext context, DocumentPage page) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Apply Filter'),
                onTap: () {
                  Navigator.pop(context);
                  _openFilterScreen(page);
                },
              ),
              ListTile(
                leading: const Icon(Icons.crop),
                title: const Text('Adjust Crop'),
                onTap: () {
                  Navigator.pop(context);
                  _openCropScreen(page);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete Page'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, page);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openFilterScreen(DocumentPage page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: context.read<DocumentScannerBloc>(),
          child: FilterScreen(page: page),
        ),
      ),
    );
  }

  void _openCropScreen(DocumentPage page) {
    // Navigate to crop screen
    // Implementation similar to FilterScreen navigation
  }

  void _rotatePage(DocumentPage page) {
    // Implement rotation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rotation coming soon')),
    );
  }

  void _confirmDelete(BuildContext context, DocumentPage page) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Page?'),
          content:
              Text('Delete page ${page.pageNumber}? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<DocumentScannerBloc>().add(
                      RemovePage(pageId: page.id),
                    );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _handleReorder(ScannedDocument document, int oldIndex, int newIndex) {
    final pageIds = document.pages.map((p) => p.id).toList();

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final pageId = pageIds.removeAt(oldIndex);
    pageIds.insert(newIndex, pageId);

    context.read<DocumentScannerBloc>().add(
          ReorderPages(newOrder: pageIds),
        );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'select_all_filter':
        _showFilterSelectionDialog(context);
        break;
      case 'delete_all':
        _confirmDeleteAll(context);
        break;
    }
  }

  void _showFilterSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Filter'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ImageFilterType.values.map((filter) {
              return ListTile(
                title: Text(filter.displayName),
                subtitle: Text(filter.description),
                onTap: () {
                  Navigator.pop(context);
                  context.read<DocumentScannerBloc>().add(
                        ApplyFilterToAll(filterType: filter),
                      );
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _confirmDeleteAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Pages?'),
          content: const Text(
            'This will delete all scanned pages. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<DocumentScannerBloc>().add(
                      const ResetScanner(),
                    );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }
}

/// Custom reorderable grid view widget
class ReorderableGridView extends StatelessWidget {
  final int crossAxisCount;
  final EdgeInsetsGeometry padding;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final List<Widget> children;
  final void Function(int oldIndex, int newIndex) onReorder;

  const ReorderableGridView.count({
    super.key,
    required this.crossAxisCount,
    required this.children,
    required this.onReorder,
    this.padding = EdgeInsets.zero,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.childAspectRatio = 1,
  });

  @override
  Widget build(BuildContext context) {
    // Using a simple GridView for now
    // For full reordering support, consider using a package like reorderable_grid_view
    return GridView.count(
      crossAxisCount: crossAxisCount,
      padding: padding,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childAspectRatio: childAspectRatio,
      children: children,
    );
  }
}
