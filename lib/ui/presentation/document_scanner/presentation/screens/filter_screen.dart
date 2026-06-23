import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../bloc/document_scanner_bloc.dart';
import '../bloc/document_scanner_event.dart';
import '../bloc/document_scanner_state.dart';

/// Screen for applying filters to scanned documents.
///
/// Features:
/// - Filter preview thumbnails
/// - Before/after comparison
/// - Apply to all pages option
class FilterScreen extends StatefulWidget {
  /// The page to apply filter to
  final DocumentPage page;

  /// Callback when filter is applied
  final VoidCallback? onComplete;

  const FilterScreen({
    super.key,
    required this.page,
    this.onComplete,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late ImageFilterType _selectedFilter;
  bool _showOriginal = false;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.page.filterType;
  }

  void _applyFilter(ImageFilterType filter) {
    setState(() {
      _selectedFilter = filter;
    });

    context.read<DocumentScannerBloc>().add(
          ApplyFilter(
            pageId: widget.page.id,
            filterType: filter,
          ),
        );
  }

  void _applyToAll() {
    context.read<DocumentScannerBloc>().add(
          ApplyFilterToAll(filterType: _selectedFilter),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Filter applied to all pages'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Filters',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.onComplete?.call();
              Navigator.of(context).pop();
            },
            child: const Text(
              'Done',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: BlocBuilder<DocumentScannerBloc, DocumentScannerState>(
        builder: (context, state) {
          // Get the updated page from state
          final currentPage = state.document?.pages.firstWhere(
                (p) => p.id == widget.page.id,
                orElse: () => widget.page,
              ) ??
              widget.page;

          return Column(
            children: [
              // Image preview
              Expanded(
                child: GestureDetector(
                  onLongPressStart: (_) {
                    setState(() => _showOriginal = true);
                  },
                  onLongPressEnd: (_) {
                    setState(() => _showOriginal = false);
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Processed image
                      Center(
                        child: _buildImagePreview(currentPage),
                      ),

                      // Processing indicator
                      if (state.isProcessing)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),

                      // Long press hint
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _showOriginal
                                  ? 'Showing original'
                                  : 'Hold to see original',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Filter options
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    // Filter list
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: ImageFilterType.values.length,
                        itemBuilder: (context, index) {
                          final filter = ImageFilterType.values[index];
                          return _buildFilterOption(filter, currentPage);
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Apply to all button
                    if ((state.document?.pageCount ?? 0) > 1)
                      TextButton.icon(
                        onPressed: _applyToAll,
                        icon: const Icon(Icons.select_all, color: Colors.white),
                        label: const Text(
                          'Apply to all pages',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImagePreview(DocumentPage page) {
    final imagePath = _showOriginal
        ? page.originalImagePath
        : (page.processedImagePath ?? page.originalImagePath);

    return Image.file(
      File(imagePath),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.grey,
            size: 64,
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(ImageFilterType filter, DocumentPage page) {
    final isSelected = _selectedFilter == filter;

    return GestureDetector(
      onTap: () => _applyFilter(filter),
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            // Filter preview
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: _buildFilterThumbnail(filter, page),
              ),
            ),

            const SizedBox(height: 4),

            // Filter name
            Text(
              filter.displayName,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.white,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: null,
              overflow: TextOverflow.visible,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterThumbnail(ImageFilterType filter, DocumentPage page) {
    // Use thumbnail if available
    if (page.thumbnail != null) {
      return ColorFiltered(
        colorFilter: _getColorFilter(filter),
        child: Image.memory(
          page.thumbnail!,
          fit: BoxFit.cover,
        ),
      );
    }

    // Fallback to file
    return ColorFiltered(
      colorFilter: _getColorFilter(filter),
      child: Image.file(
        File(page.originalImagePath),
        fit: BoxFit.cover,
        cacheWidth: 100,
      ),
    );
  }

  ColorFilter _getColorFilter(ImageFilterType filter) {
    switch (filter) {
      case ImageFilterType.original:
        return const ColorFilter.mode(Colors.transparent, BlendMode.multiply);

      case ImageFilterType.grayscale:
        return const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);

      case ImageFilterType.blackAndWhite:
        return const ColorFilter.matrix([
          0.5,
          0.5,
          0.5,
          0,
          -128,
          0.5,
          0.5,
          0.5,
          0,
          -128,
          0.5,
          0.5,
          0.5,
          0,
          -128,
          0,
          0,
          0,
          1,
          0,
        ]);

      case ImageFilterType.enhanced:
        return const ColorFilter.matrix([
          1.2,
          0,
          0,
          0,
          10,
          0,
          1.2,
          0,
          0,
          10,
          0,
          0,
          1.2,
          0,
          10,
          0,
          0,
          0,
          1,
          0,
        ]);

      case ImageFilterType.magic:
        return const ColorFilter.matrix([
          1.1,
          0.1,
          0,
          0,
          20,
          0.1,
          1.1,
          0,
          0,
          20,
          0,
          0,
          1.1,
          0,
          20,
          0,
          0,
          0,
          1,
          0,
        ]);
    }
  }
}
