import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../domain/entities/entities.dart';

/// Service for image processing operations.
///
/// This service handles all image manipulation including:
/// - Perspective correction
/// - Filter application
/// - Thumbnail generation
/// - Image format conversion
///
/// Heavy operations are performed in isolates to avoid blocking the UI thread.
class ImageProcessingService {
  /// Generates a thumbnail from an image file.
  ///
  /// [imagePath] - Path to the source image
  /// [maxSize] - Maximum dimension for the thumbnail
  /// Returns the thumbnail as bytes.
  Future<Uint8List> generateThumbnail(String imagePath,
      {int maxSize = 200}) async {
    return compute(
        _generateThumbnailIsolate, _ThumbnailParams(imagePath, maxSize));
  }

  /// Gets the dimensions of an image.
  Future<ui.Size> getImageSize(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }
    return ui.Size(image.width.toDouble(), image.height.toDouble());
  }

  /// Applies perspective correction to an image.
  ///
  /// [imagePath] - Path to the source image
  /// [corners] - Four corner points of the document (top-left, top-right, bottom-right, bottom-left)
  /// [outputPath] - Path to save the corrected image
  /// Returns the path to the corrected image.
  Future<String> applyPerspectiveCorrection(
    String imagePath,
    List<ui.Offset> corners,
    String outputPath,
  ) async {
    final params = _PerspectiveParams(
      imagePath: imagePath,
      corners: corners.map((o) => [o.dx, o.dy]).toList(),
      outputPath: outputPath,
    );
    return compute(_perspectiveCorrectionIsolate, params);
  }

  /// Applies a filter to an image.
  ///
  /// [imagePath] - Path to the source image
  /// [filterType] - Type of filter to apply
  /// [outputPath] - Path to save the filtered image
  /// Returns the path to the filtered image.
  Future<String> applyFilter(
    String imagePath,
    ImageFilterType filterType,
    String outputPath,
  ) async {
    final params = _FilterParams(
      imagePath: imagePath,
      filterType: filterType.index,
      outputPath: outputPath,
    );
    return compute(_applyFilterIsolate, params);
  }

  /// Encodes an image to JPEG with specified quality.
  Future<Uint8List> encodeToJpeg(String imagePath, int quality) async {
    final params = _EncodeParams(imagePath, quality, true);
    return compute(_encodeImageIsolate, params);
  }

  /// Encodes an image to PNG.
  Future<Uint8List> encodeToPng(String imagePath) async {
    final params = _EncodeParams(imagePath, 100, false);
    return compute(_encodeImageIsolate, params);
  }
}

// ============================================================================
// Isolate Functions (Top-level for compute())
// ============================================================================

class _ThumbnailParams {
  final String imagePath;
  final int maxSize;
  _ThumbnailParams(this.imagePath, this.maxSize);
}

Uint8List _generateThumbnailIsolate(_ThumbnailParams params) {
  final bytes = File(params.imagePath).readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Failed to decode image for thumbnail');
  }

  // Calculate new dimensions maintaining aspect ratio
  final double ratio = image.width / image.height;
  int newWidth, newHeight;

  if (image.width > image.height) {
    newWidth = params.maxSize;
    newHeight = (params.maxSize / ratio).round();
  } else {
    newHeight = params.maxSize;
    newWidth = (params.maxSize * ratio).round();
  }

  // Resize the image
  final thumbnail = img.copyResize(
    image,
    width: newWidth,
    height: newHeight,
    interpolation: img.Interpolation.linear,
  );

  // Encode to JPEG
  return Uint8List.fromList(img.encodeJpg(thumbnail, quality: 80));
}

class _PerspectiveParams {
  final String imagePath;
  final List<List<double>> corners;
  final String outputPath;

  _PerspectiveParams({
    required this.imagePath,
    required this.corners,
    required this.outputPath,
  });
}

String _perspectiveCorrectionIsolate(_PerspectiveParams params) {
  final bytes = File(params.imagePath).readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Failed to decode image for perspective correction');
  }

  // Extract corners
  final topLeft = params.corners[0];
  final topRight = params.corners[1];
  final bottomRight = params.corners[2];
  final bottomLeft = params.corners[3];

  // Calculate output dimensions based on the document shape
  final widthTop = _distance(topLeft, topRight);
  final widthBottom = _distance(bottomLeft, bottomRight);
  final heightLeft = _distance(topLeft, bottomLeft);
  final heightRight = _distance(topRight, bottomRight);

  final outputWidth = math.max(widthTop, widthBottom).round();
  final outputHeight = math.max(heightLeft, heightRight).round();

  // Perform perspective transformation using bilinear interpolation
  final result = img.Image(width: outputWidth, height: outputHeight);

  // Source quadrilateral corners
  final srcCorners = [
    [topLeft[0], topLeft[1]],
    [topRight[0], topRight[1]],
    [bottomRight[0], bottomRight[1]],
    [bottomLeft[0], bottomLeft[1]],
  ];

  // Destination quadrilateral corners (output image bounds)
  final dstCorners = [
    [0.0, 0.0],
    [outputWidth.toDouble() - 1, 0.0],
    [outputWidth.toDouble() - 1, outputHeight.toDouble() - 1],
    [0.0, outputHeight.toDouble() - 1],
  ];

  // Calculate perspective transform matrix
  final matrix = _computePerspectiveTransform(dstCorners, srcCorners);

  // Apply transformation
  for (int y = 0; y < outputHeight; y++) {
    for (int x = 0; x < outputWidth; x++) {
      // Apply inverse transform to get source coordinates
      final srcPoint =
          _applyPerspectiveTransform(matrix, x.toDouble(), y.toDouble());
      final srcX = srcPoint[0];
      final srcY = srcPoint[1];

      // Bilinear interpolation
      if (srcX >= 0 &&
          srcX < image.width - 1 &&
          srcY >= 0 &&
          srcY < image.height - 1) {
        final x0 = srcX.floor();
        final y0 = srcY.floor();
        final x1 = x0 + 1;
        final y1 = y0 + 1;

        final fx = srcX - x0;
        final fy = srcY - y0;

        final p00 = image.getPixel(x0, y0);
        final p10 = image.getPixel(x1, y0);
        final p01 = image.getPixel(x0, y1);
        final p11 = image.getPixel(x1, y1);

        final r = ((1 - fx) * (1 - fy) * p00.r +
                fx * (1 - fy) * p10.r +
                (1 - fx) * fy * p01.r +
                fx * fy * p11.r)
            .round();

        final g = ((1 - fx) * (1 - fy) * p00.g +
                fx * (1 - fy) * p10.g +
                (1 - fx) * fy * p01.g +
                fx * fy * p11.g)
            .round();

        final b = ((1 - fx) * (1 - fy) * p00.b +
                fx * (1 - fy) * p10.b +
                (1 - fx) * fy * p01.b +
                fx * fy * p11.b)
            .round();

        result.setPixelRgb(x, y, r, g, b);
      }
    }
  }

  // Save the result
  final outputBytes = img.encodeJpg(result, quality: 95);
  File(params.outputPath).writeAsBytesSync(outputBytes);

  return params.outputPath;
}

double _distance(List<double> p1, List<double> p2) {
  final dx = p1[0] - p2[0];
  final dy = p1[1] - p2[1];
  return math.sqrt(dx * dx + dy * dy);
}

/// Computes a perspective transformation matrix from source to destination quad.
List<double> _computePerspectiveTransform(
  List<List<double>> src,
  List<List<double>> dst,
) {
  // Uses the DLT (Direct Linear Transform) algorithm
  final a = <List<double>>[];
  final b = <double>[];

  for (int i = 0; i < 4; i++) {
    final x = src[i][0];
    final y = src[i][1];
    final u = dst[i][0];
    final v = dst[i][1];

    a.add([-x, -y, -1, 0, 0, 0, u * x, u * y]);
    b.add(-u);

    a.add([0, 0, 0, -x, -y, -1, v * x, v * y]);
    b.add(-v);
  }

  // Solve using Gaussian elimination
  final matrix = _solveLinearSystem(a, b);
  return [...matrix, 1.0];
}

List<double> _solveLinearSystem(List<List<double>> a, List<double> b) {
  final n = b.length;
  final augmented = List.generate(n, (i) => [...a[i], b[i]]);

  // Forward elimination
  for (int col = 0; col < n; col++) {
    // Find pivot
    int maxRow = col;
    for (int row = col + 1; row < n; row++) {
      if (augmented[row][col].abs() > augmented[maxRow][col].abs()) {
        maxRow = row;
      }
    }
    final temp = augmented[col];
    augmented[col] = augmented[maxRow];
    augmented[maxRow] = temp;

    // Eliminate
    for (int row = col + 1; row < n; row++) {
      final factor = augmented[row][col] / augmented[col][col];
      for (int j = col; j <= n; j++) {
        augmented[row][j] -= factor * augmented[col][j];
      }
    }
  }

  // Back substitution
  final x = List<double>.filled(n, 0);
  for (int row = n - 1; row >= 0; row--) {
    x[row] = augmented[row][n];
    for (int j = row + 1; j < n; j++) {
      x[row] -= augmented[row][j] * x[j];
    }
    x[row] /= augmented[row][row];
  }

  return x;
}

List<double> _applyPerspectiveTransform(
    List<double> matrix, double x, double y) {
  final w = matrix[6] * x + matrix[7] * y + matrix[8];
  return [
    (matrix[0] * x + matrix[1] * y + matrix[2]) / w,
    (matrix[3] * x + matrix[4] * y + matrix[5]) / w,
  ];
}

class _FilterParams {
  final String imagePath;
  final int filterType;
  final String outputPath;

  _FilterParams({
    required this.imagePath,
    required this.filterType,
    required this.outputPath,
  });
}

String _applyFilterIsolate(_FilterParams params) {
  final bytes = File(params.imagePath).readAsBytesSync();
  var image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Failed to decode image for filter');
  }

  final filterType = ImageFilterType.values[params.filterType];

  switch (filterType) {
    case ImageFilterType.original:
      // No processing needed
      break;

    case ImageFilterType.grayscale:
      image = img.grayscale(image);
      break;

    case ImageFilterType.blackAndWhite:
      // Convert to grayscale first
      image = img.grayscale(image);
      // Apply adaptive thresholding for document scanning
      image = _adaptiveThreshold(image);
      break;

    case ImageFilterType.enhanced:
      // Increase contrast and sharpen
      image = img.adjustColor(image, contrast: 1.3);
      image = img.convolution(image, filter: [
        0,
        -1,
        0,
        -1,
        5,
        -1,
        0,
        -1,
        0,
      ]);
      break;

    case ImageFilterType.magic:
      // Auto-enhance for documents
      image = _autoEnhance(image);
      break;
  }

  // Save the result
  final outputBytes = img.encodeJpg(image, quality: 95);
  File(params.outputPath).writeAsBytesSync(outputBytes);

  return params.outputPath;
}

/// Applies adaptive thresholding for document scanning.
/// Optimized version using integral image for O(1) local mean calculation.
img.Image _adaptiveThreshold(img.Image image) {
  final result = img.Image(width: image.width, height: image.height);
  const blockSize = 15;
  const c = 10;
  final halfBlock = blockSize ~/ 2;

  // Build integral image for O(1) mean calculation
  final integral = List.generate(
    image.height + 1,
    (_) => List.filled(image.width + 1, 0),
  );

  // Pre-compute luminance values and build integral image
  for (int y = 0; y < image.height; y++) {
    int rowSum = 0;
    for (int x = 0; x < image.width; x++) {
      final lum = img.getLuminance(image.getPixel(x, y)).toInt();
      rowSum += lum;
      integral[y + 1][x + 1] = integral[y][x + 1] + rowSum;
    }
  }

  // Apply threshold using integral image
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      // Calculate block bounds
      final x1 = (x - halfBlock).clamp(0, image.width - 1);
      final y1 = (y - halfBlock).clamp(0, image.height - 1);
      final x2 = (x + halfBlock).clamp(0, image.width - 1);
      final y2 = (y + halfBlock).clamp(0, image.height - 1);

      final count = (x2 - x1 + 1) * (y2 - y1 + 1);

      // O(1) sum calculation using integral image
      final sum = integral[y2 + 1][x2 + 1] -
          integral[y1][x2 + 1] -
          integral[y2 + 1][x1] +
          integral[y1][x1];

      final mean = sum / count;
      final luminance = img.getLuminance(image.getPixel(x, y)).toInt();

      if (luminance < mean - c) {
        result.setPixelRgb(x, y, 0, 0, 0);
      } else {
        result.setPixelRgb(x, y, 255, 255, 255);
      }
    }
  }

  return result;
}

/// Auto-enhances an image for document readability.
img.Image _autoEnhance(img.Image image) {
  // Convert to grayscale
  var result = img.grayscale(image);

  // Normalize histogram (contrast stretching)
  result = img.normalize(result, min: 0, max: 255);

  // Slight sharpening
  result = img.convolution(result, filter: [
    0,
    -0.5,
    0,
    -0.5,
    3,
    -0.5,
    0,
    -0.5,
    0,
  ]);

  // Increase brightness slightly
  result = img.adjustColor(result, brightness: 1.1);

  return result;
}

class _EncodeParams {
  final String imagePath;
  final int quality;
  final bool asJpeg;

  _EncodeParams(this.imagePath, this.quality, this.asJpeg);
}

Uint8List _encodeImageIsolate(_EncodeParams params) {
  final bytes = File(params.imagePath).readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Failed to decode image for encoding');
  }

  if (params.asJpeg) {
    return Uint8List.fromList(img.encodeJpg(image, quality: params.quality));
  } else {
    return Uint8List.fromList(img.encodePng(image));
  }
}
