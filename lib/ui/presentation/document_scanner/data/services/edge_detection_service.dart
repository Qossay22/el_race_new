import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Service for detecting document edges in images.
///
/// Uses computer vision techniques to find document boundaries:
/// - Canny edge detection
/// - Contour detection
/// - Quadrilateral fitting
///
/// All heavy processing is done in isolates to keep the UI responsive.
class EdgeDetectionService {
  /// Detects document edges from an image file.
  ///
  /// [imagePath] - Path to the image file
  /// Returns four corners if a document is detected, null otherwise.
  Future<List<ui.Offset>?> detectEdges(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    return detectEdgesFromBytes(bytes);
  }

  /// Detects document edges from image bytes.
  ///
  /// [imageBytes] - Raw image bytes
  /// Returns four corners if detected, null otherwise.
  Future<List<ui.Offset>?> detectEdgesFromBytes(Uint8List imageBytes) async {
    try {
      final result = await compute(_detectEdgesIsolate, imageBytes);
      if (result == null) return null;

      return result.map((point) => ui.Offset(point[0], point[1])).toList();
    } catch (e) {
      debugPrint('Edge detection error: $e');
      return null;
    }
  }

  /// Detects edges with specific image dimensions (for camera preview).
  Future<List<ui.Offset>?> detectEdgesWithDimensions(
    Uint8List imageBytes,
    int width,
    int height,
  ) async {
    try {
      final params = _EdgeDetectionParams(imageBytes, width, height);
      final result = await compute(_detectEdgesWithDimensionsIsolate, params);
      if (result == null) return null;

      return result.map((point) => ui.Offset(point[0], point[1])).toList();
    } catch (e) {
      debugPrint('Edge detection error: $e');
      return null;
    }
  }
}

class _EdgeDetectionParams {
  final Uint8List bytes;
  final int width;
  final int height;

  _EdgeDetectionParams(this.bytes, this.width, this.height);
}

/// Isolate function for edge detection from bytes.
List<List<double>>? _detectEdgesIsolate(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;

  return _detectDocumentEdges(image);
}

/// Isolate function for edge detection with known dimensions.
List<List<double>>? _detectEdgesWithDimensionsIsolate(
    _EdgeDetectionParams params) {
  final image = img.decodeImage(params.bytes);
  if (image == null) return null;

  return _detectDocumentEdges(image);
}

/// Core edge detection algorithm.
///
/// Uses a simplified approach suitable for document scanning:
/// 1. Convert to grayscale
/// 2. Apply Gaussian blur
/// 3. Apply Canny edge detection
/// 4. Find contours
/// 5. Find largest quadrilateral
List<List<double>>? _detectDocumentEdges(img.Image image) {
  // Resize for faster processing
  const maxDimension = 500;
  double scale = 1.0;
  img.Image processImage;

  if (image.width > maxDimension || image.height > maxDimension) {
    scale = maxDimension / math.max(image.width, image.height);
    processImage = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
    );
  } else {
    processImage = image;
  }

  // Convert to grayscale
  final grayscale = img.grayscale(processImage);

  // Apply Gaussian blur to reduce noise
  final blurred = img.gaussianBlur(grayscale, radius: 5);

  // Apply edge detection (Sobel operator)
  final edges = _applySobel(blurred);

  // Apply threshold to get binary edges
  final binary = _applyThreshold(edges, 50);

  // Find contours
  final contours = _findContours(binary);

  // Find the largest quadrilateral contour
  final quad = _findLargestQuadrilateral(contours, binary.width, binary.height);

  if (quad == null) return null;

  // Scale corners back to original image size
  return quad.map((point) {
    return [point[0] / scale, point[1] / scale];
  }).toList();
}

/// Applies Sobel edge detection.
img.Image _applySobel(img.Image image) {
  final result = img.Image(width: image.width, height: image.height);

  // Sobel kernels
  const sobelX = [
    [-1, 0, 1],
    [-2, 0, 2],
    [-1, 0, 1],
  ];
  const sobelY = [
    [-1, -2, -1],
    [0, 0, 0],
    [1, 2, 1],
  ];

  for (int y = 1; y < image.height - 1; y++) {
    for (int x = 1; x < image.width - 1; x++) {
      double gx = 0;
      double gy = 0;

      for (int ky = -1; ky <= 1; ky++) {
        for (int kx = -1; kx <= 1; kx++) {
          final pixel = image.getPixel(x + kx, y + ky);
          final gray = img.getLuminance(pixel);

          gx += gray * sobelX[ky + 1][kx + 1];
          gy += gray * sobelY[ky + 1][kx + 1];
        }
      }

      final magnitude = math.sqrt(gx * gx + gy * gy).clamp(0, 255).round();
      result.setPixelRgb(x, y, magnitude, magnitude, magnitude);
    }
  }

  return result;
}

/// Applies binary threshold to an image.
img.Image _applyThreshold(img.Image image, int threshold) {
  final result = img.Image(width: image.width, height: image.height);

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final gray = img.getLuminance(pixel).toInt();
      final value = gray > threshold ? 255 : 0;
      result.setPixelRgb(x, y, value, value, value);
    }
  }

  return result;
}

/// Finds contours in a binary image using a simplified approach.
List<List<List<int>>> _findContours(img.Image binary) {
  final contours = <List<List<int>>>[];
  final visited = List.generate(
    binary.height,
    (_) => List.filled(binary.width, false),
  );

  for (int y = 0; y < binary.height; y++) {
    for (int x = 0; x < binary.width; x++) {
      if (!visited[y][x] && _isEdgePixel(binary, x, y)) {
        final contour = _traceContour(binary, x, y, visited);
        if (contour.length > 50) {
          contours.add(contour);
        }
      }
    }
  }

  return contours;
}

bool _isEdgePixel(img.Image binary, int x, int y) {
  final pixel = binary.getPixel(x, y);
  return img.getLuminance(pixel) > 128;
}

/// Traces a contour starting from a point.
List<List<int>> _traceContour(
  img.Image binary,
  int startX,
  int startY,
  List<List<bool>> visited,
) {
  final contour = <List<int>>[];
  final stack = <List<int>>[
    [startX, startY]
  ];

  while (stack.isNotEmpty) {
    final point = stack.removeLast();
    final x = point[0];
    final y = point[1];

    if (x < 0 || x >= binary.width || y < 0 || y >= binary.height) continue;
    if (visited[y][x]) continue;
    if (!_isEdgePixel(binary, x, y)) continue;

    visited[y][x] = true;
    contour.add([x, y]);

    // Add neighbors
    stack.add([x + 1, y]);
    stack.add([x - 1, y]);
    stack.add([x, y + 1]);
    stack.add([x, y - 1]);
  }

  return contour;
}

/// Finds the largest quadrilateral from contours.
List<List<double>>? _findLargestQuadrilateral(
  List<List<List<int>>> contours,
  int imageWidth,
  int imageHeight,
) {
  List<List<double>>? bestQuad;
  double bestArea = 0;
  final imageArea = imageWidth * imageHeight;
  final minArea = imageArea * 0.1; // Minimum 10% of image

  for (final contour in contours) {
    // Simplify contour using Douglas-Peucker algorithm
    final simplified = _douglasPeucker(contour, 10.0);

    // Try to find a quadrilateral approximation
    final quad = _approximateQuadrilateral(simplified);
    if (quad == null) continue;

    final area = _quadrilateralArea(quad);

    // Check if this is a valid document-like quadrilateral
    if (area > minArea && area < imageArea * 0.95 && area > bestArea) {
      if (_isConvexQuadrilateral(quad)) {
        bestArea = area;
        bestQuad = quad;
      }
    }
  }

  // If no good quad found, try to use convex hull of largest contour
  if (bestQuad == null && contours.isNotEmpty) {
    // Sort by contour size
    contours.sort((a, b) => b.length.compareTo(a.length));
    final largest = contours.first;

    final hull = _convexHull(largest);
    final quad = _approximateQuadrilateral(hull);

    if (quad != null && _isConvexQuadrilateral(quad)) {
      final area = _quadrilateralArea(quad);
      if (area > minArea) {
        bestQuad = quad;
      }
    }
  }

  if (bestQuad != null) {
    // Order corners: top-left, top-right, bottom-right, bottom-left
    return _orderCorners(bestQuad);
  }

  return null;
}

/// Douglas-Peucker line simplification algorithm.
List<List<int>> _douglasPeucker(List<List<int>> points, double epsilon) {
  if (points.length < 3) return points;

  // Find the point with the maximum distance from the line
  double maxDist = 0;
  int maxIndex = 0;

  final first = points.first;
  final last = points.last;

  for (int i = 1; i < points.length - 1; i++) {
    final dist = _perpendicularDistance(points[i], first, last);
    if (dist > maxDist) {
      maxDist = dist;
      maxIndex = i;
    }
  }

  // If max distance is greater than epsilon, recursively simplify
  if (maxDist > epsilon) {
    final left = _douglasPeucker(points.sublist(0, maxIndex + 1), epsilon);
    final right = _douglasPeucker(points.sublist(maxIndex), epsilon);

    return [...left.sublist(0, left.length - 1), ...right];
  }

  return [first, last];
}

double _perpendicularDistance(
    List<int> point, List<int> lineStart, List<int> lineEnd) {
  final dx = lineEnd[0] - lineStart[0];
  final dy = lineEnd[1] - lineStart[1];

  if (dx == 0 && dy == 0) {
    return math.sqrt(
      math.pow(point[0] - lineStart[0], 2) +
          math.pow(point[1] - lineStart[1], 2),
    );
  }

  final t = ((point[0] - lineStart[0]) * dx + (point[1] - lineStart[1]) * dy) /
      (dx * dx + dy * dy);

  final nearestX = lineStart[0] + t * dx;
  final nearestY = lineStart[1] + t * dy;

  return math.sqrt(
    math.pow(point[0] - nearestX, 2) + math.pow(point[1] - nearestY, 2),
  );
}

/// Approximates a contour as a quadrilateral.
List<List<double>>? _approximateQuadrilateral(List<List<int>> contour) {
  if (contour.length < 4) return null;

  // Find 4 corner points
  final corners = <List<double>>[];

  // Simple approach: find extreme points
  int minXIdx = 0, maxXIdx = 0, minYIdx = 0, maxYIdx = 0;

  for (int i = 0; i < contour.length; i++) {
    if (contour[i][0] < contour[minXIdx][0]) minXIdx = i;
    if (contour[i][0] > contour[maxXIdx][0]) maxXIdx = i;
    if (contour[i][1] < contour[minYIdx][1]) minYIdx = i;
    if (contour[i][1] > contour[maxYIdx][1]) maxYIdx = i;
  }

  final indices = {minXIdx, maxXIdx, minYIdx, maxYIdx};
  if (indices.length < 4) {
    // Not enough distinct corners found
    // Try to find 4 corners using different approach
    return _findFourCorners(contour);
  }

  for (final idx in indices) {
    corners.add([contour[idx][0].toDouble(), contour[idx][1].toDouble()]);
  }

  return corners;
}

/// Finds 4 corners from a contour using angular sweep.
List<List<double>>? _findFourCorners(List<List<int>> contour) {
  if (contour.length < 4) return null;

  // Find center of mass
  double cx = 0, cy = 0;
  for (final p in contour) {
    cx += p[0];
    cy += p[1];
  }
  cx /= contour.length;
  cy /= contour.length;

  // Group points by quadrant and find extreme in each
  final quadrants = <int, List<List<int>>>{0: [], 1: [], 2: [], 3: []};

  for (final p in contour) {
    final angle = math.atan2(p[1] - cy, p[0] - cx);
    int quadrant;
    if (angle >= -math.pi / 4 && angle < math.pi / 4) {
      quadrant = 0; // Right
    } else if (angle >= math.pi / 4 && angle < 3 * math.pi / 4) {
      quadrant = 1; // Bottom
    } else if (angle >= -3 * math.pi / 4 && angle < -math.pi / 4) {
      quadrant = 3; // Top
    } else {
      quadrant = 2; // Left
    }
    quadrants[quadrant]!.add(p);
  }

  final corners = <List<double>>[];
  for (int q = 0; q < 4; q++) {
    if (quadrants[q]!.isEmpty) return null;

    // Find point furthest from center in this quadrant
    var maxDist = 0.0;
    List<int>? best;
    for (final p in quadrants[q]!) {
      final dist = math.sqrt(math.pow(p[0] - cx, 2) + math.pow(p[1] - cy, 2));
      if (dist > maxDist) {
        maxDist = dist;
        best = p;
      }
    }
    if (best != null) {
      corners.add([best[0].toDouble(), best[1].toDouble()]);
    }
  }

  if (corners.length != 4) return null;
  return corners;
}

/// Calculates the area of a quadrilateral using Shoelace formula.
double _quadrilateralArea(List<List<double>> quad) {
  double area = 0;
  for (int i = 0; i < 4; i++) {
    final j = (i + 1) % 4;
    area += quad[i][0] * quad[j][1];
    area -= quad[j][0] * quad[i][1];
  }
  return area.abs() / 2;
}

/// Checks if a quadrilateral is convex.
bool _isConvexQuadrilateral(List<List<double>> quad) {
  int sign = 0;
  for (int i = 0; i < 4; i++) {
    final p1 = quad[i];
    final p2 = quad[(i + 1) % 4];
    final p3 = quad[(i + 2) % 4];

    final cross =
        (p2[0] - p1[0]) * (p3[1] - p2[1]) - (p2[1] - p1[1]) * (p3[0] - p2[0]);

    if (sign == 0) {
      sign = cross > 0 ? 1 : -1;
    } else if ((cross > 0 && sign < 0) || (cross < 0 && sign > 0)) {
      return false;
    }
  }
  return true;
}

/// Orders corners in clockwise order starting from top-left.
List<List<double>> _orderCorners(List<List<double>> corners) {
  // Find center
  double cx = 0, cy = 0;
  for (final c in corners) {
    cx += c[0];
    cy += c[1];
  }
  cx /= 4;
  cy /= 4;

  // Sort by angle from center
  final sorted = List<List<double>>.from(corners);
  sorted.sort((a, b) {
    final angleA = math.atan2(a[1] - cy, a[0] - cx);
    final angleB = math.atan2(b[1] - cy, b[0] - cx);
    return angleA.compareTo(angleB);
  });

  // Find top-left (minimum x+y sum)
  int topLeftIdx = 0;
  double minSum = double.infinity;
  for (int i = 0; i < 4; i++) {
    final sum = sorted[i][0] + sorted[i][1];
    if (sum < minSum) {
      minSum = sum;
      topLeftIdx = i;
    }
  }

  // Reorder starting from top-left
  final ordered = <List<double>>[];
  for (int i = 0; i < 4; i++) {
    ordered.add(sorted[(topLeftIdx + i) % 4]);
  }

  return ordered;
}

/// Computes the convex hull of a set of points using Graham scan.
List<List<int>> _convexHull(List<List<int>> points) {
  if (points.length < 3) return points;

  // Find bottom-most point (or left-most in case of tie)
  int bottomIdx = 0;
  for (int i = 1; i < points.length; i++) {
    if (points[i][1] > points[bottomIdx][1] ||
        (points[i][1] == points[bottomIdx][1] &&
            points[i][0] < points[bottomIdx][0])) {
      bottomIdx = i;
    }
  }

  final pivot = points[bottomIdx];

  // Sort points by polar angle with respect to pivot
  final sorted = List<List<int>>.from(points);
  sorted.removeAt(bottomIdx);
  sorted.sort((a, b) {
    final angleA = math.atan2(a[1] - pivot[1], a[0] - pivot[0]);
    final angleB = math.atan2(b[1] - pivot[1], b[0] - pivot[0]);
    return angleA.compareTo(angleB);
  });

  final hull = <List<int>>[pivot];
  for (final p in sorted) {
    while (hull.length > 1) {
      final top = hull.last;
      final second = hull[hull.length - 2];
      final cross = (top[0] - second[0]) * (p[1] - second[1]) -
          (top[1] - second[1]) * (p[0] - second[0]);
      if (cross <= 0) {
        hull.removeLast();
      } else {
        break;
      }
    }
    hull.add(p);
  }

  return hull;
}
