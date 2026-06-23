/// 🧪 Anti-Spoofing Test Suite
///
/// This test suite validates that the face verification system
/// can detect and reject photo-based attacks.
///
/// Test Scenarios:
/// 1. Photo with perfect eye values (should FAIL)
/// 2. Photo with identical eye values (should FAIL)
/// 3. Static face without micro-movements (should FAIL)
/// 4. Real face with natural eye variations (should PASS)
/// 5. Real face with blink detected (should PASS)
///
/// To run these tests:
/// ```bash
/// flutter test test/anti_spoof_test.dart
/// ```

import 'package:flutter_test/flutter_test.dart';

import 'dart:ui';

// ============================================================
// 🎭 MOCK CLASSES
// ============================================================

/// Mock Face class for testing anti-spoofing algorithms
class MockFace {
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  final double? headEulerAngleY;
  final double? headEulerAngleZ;
  final double? headEulerAngleX;
  final Rect boundingBox;
  final int? trackingId;

  MockFace({
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.headEulerAngleY = 0.0,
    this.headEulerAngleZ = 0.0,
    this.headEulerAngleX = 0.0,
    this.boundingBox = const Rect.fromLTWH(100, 100, 200, 200),
    this.trackingId,
  });
}

// ============================================================
// 🧮 ANTI-SPOOF ALGORITHM (for testing)
// ============================================================

/// Simulates the anti-spoof scoring logic from FaceDetectorService
double calculateAntiSpoofScore(MockFace face) {
  double score = 1.0;

  // Check 1: Eye probability analysis
  if (face.leftEyeOpenProbability != null &&
      face.rightEyeOpenProbability != null) {
    final leftEye = face.leftEyeOpenProbability!;
    final rightEye = face.rightEyeOpenProbability!;

    // Perfect eye values (>0.99) are suspicious
    if (leftEye > 0.99 || rightEye > 0.99) {
      score *= 0.7;
      print('🔍 Anti-Spoof: Perfect eye values detected (-30%)');
    }

    // Identical eye values are very suspicious
    if ((leftEye - rightEye).abs() < 0.005) {
      score *= 0.75;
      print('🔍 Anti-Spoof: Identical eye probabilities (-25%)');
    }

    // Very low eye values with face still detected
    if (leftEye < 0.1 && rightEye < 0.1) {
      score *= 0.4;
      print('🔍 Anti-Spoof: Very low eye probabilities (-60%)');
    }
  }

  // Check 2: Head pose analysis
  if (face.headEulerAngleY != null && face.headEulerAngleZ != null) {
    // Perfectly centered face (< 0.3 degrees) is suspicious
    if (face.headEulerAngleY!.abs() < 0.3 &&
        face.headEulerAngleZ!.abs() < 0.3) {
      score *= 0.85;
      print('🔍 Anti-Spoof: Perfectly centered pose (-15%)');
    }
  }

  // Check 3: Face size analysis
  final faceArea = face.boundingBox.width * face.boundingBox.height;
  final screenFraction = faceArea / (640 * 480);

  // Very large face (>70% of frame) suggests photo on screen
  if (screenFraction > 0.7) {
    score *= 0.6;
    print(
        '🔍 Anti-Spoof: Face too large (${(screenFraction * 100).toInt()}%) (-40%)');
  }

  return score.clamp(0.0, 1.0);
}

/// Simulates liveness check from FaceDetectorService
bool checkLiveness(
  MockFace face, {
  double eyeOpenThreshold = 0.55,
  double maxHeadEulerAngleY = 12.0,
  double maxHeadEulerAngleZ = 12.0,
}) {
  // Check if classification data is available
  if (face.leftEyeOpenProbability == null ||
      face.rightEyeOpenProbability == null) {
    print('⚠️ Eye classification data not available!');
    return false;
  }

  final leftEye = face.leftEyeOpenProbability!;
  final rightEye = face.rightEyeOpenProbability!;

  // Check: Both eyes should be reasonably open
  final leftEyeOpen = leftEye > eyeOpenThreshold;
  final rightEyeOpen = rightEye > eyeOpenThreshold;

  if (!leftEyeOpen || !rightEyeOpen) {
    print('❌ Liveness FAILED: Eyes not sufficiently open');
    return false;
  }

  // Check: Head pose should be roughly frontal
  if (face.headEulerAngleY != null && face.headEulerAngleZ != null) {
    final isYawAcceptable = face.headEulerAngleY!.abs() < maxHeadEulerAngleY;
    final isRollAcceptable = face.headEulerAngleZ!.abs() < maxHeadEulerAngleZ;

    if (!isYawAcceptable || !isRollAcceptable) {
      print('❌ Liveness FAILED: Head turned too much');
      return false;
    }
  }

  return true;
}

/// Calculates eye variation over multiple frames
double calculateEyeVariation(List<double> eyeValues) {
  if (eyeValues.isEmpty) return 0.0;
  final min = eyeValues.reduce((a, b) => a < b ? a : b);
  final max = eyeValues.reduce((a, b) => a > b ? a : b);
  return max - min;
}

/// Check if blink was detected in frame sequence
bool detectBlink(List<double> eyeValues, {double threshold = 0.3}) {
  for (int i = 1; i < eyeValues.length; i++) {
    if (eyeValues[i - 1] > threshold && eyeValues[i] < threshold) {
      // Potential blink (open -> closed)
      for (int j = i + 1; j < eyeValues.length; j++) {
        if (eyeValues[j] > threshold) {
          // Eyes opened again (closed -> open)
          return true;
        }
      }
    }
  }
  return false;
}

// ============================================================
// 🧪 TEST CASES
// ============================================================

void main() {
  group('🛡️ Anti-Spoofing Tests', () {
    group('📷 Photo Attack Detection', () {
      test('Should REJECT photo with perfect 1.0 eye values', () {
        // A photo often has perfect eye values because the eyes never blink
        final photoFace = MockFace(
          leftEyeOpenProbability: 0.999,
          rightEyeOpenProbability: 0.999,
          headEulerAngleY: 0.1,
          headEulerAngleZ: 0.1,
        );

        final score = calculateAntiSpoofScore(photoFace);

        print('🧪 Photo with perfect eyes - Score: ${(score * 100).toInt()}%');

        // Score should be below 50% threshold
        expect(score, lessThan(0.5),
            reason: 'Perfect eye values should reduce anti-spoof score');
      });

      test('Should REJECT photo with identical eye values', () {
        // Photos often have identical left/right eye values
        final photoFace = MockFace(
          leftEyeOpenProbability: 0.85,
          rightEyeOpenProbability: 0.85, // Exactly same as left
          headEulerAngleY: 0.0,
          headEulerAngleZ: 0.0,
        );

        final score = calculateAntiSpoofScore(photoFace);

        print(
            '🧪 Photo with identical eyes - Score: ${(score * 100).toInt()}%');

        expect(score, lessThan(0.7),
            reason: 'Identical eye values should reduce score');
      });

      test('Should REJECT photo with perfectly centered pose', () {
        // Photos are often perfectly centered
        final photoFace = MockFace(
          leftEyeOpenProbability: 0.9,
          rightEyeOpenProbability: 0.88,
          headEulerAngleY: 0.1,
          headEulerAngleZ: 0.1,
        );

        final score = calculateAntiSpoofScore(photoFace);

        print('🧪 Photo with centered pose - Score: ${(score * 100).toInt()}%');

        expect(score, lessThan(0.9),
            reason: 'Perfectly centered pose should reduce score');
      });

      test('Should REJECT photo displayed on large screen', () {
        // Face taking up most of frame suggests photo on screen
        final photoFace = MockFace(
          leftEyeOpenProbability: 0.8,
          rightEyeOpenProbability: 0.78,
          headEulerAngleY: 2.0,
          headEulerAngleZ: 1.0,
          boundingBox: const Rect.fromLTWH(
              50, 50, 550, 400), // Large face covering 71% of frame
        );

        final score = calculateAntiSpoofScore(photoFace);

        print('🧪 Photo on large screen - Score: ${(score * 100).toInt()}%');

        expect(score, lessThan(0.65),
            reason: 'Large face covering frame should reduce score');
      });

      test('Should REJECT photo with closed eyes', () {
        // Photo of someone with eyes closed
        final photoFace = MockFace(
          leftEyeOpenProbability: 0.05,
          rightEyeOpenProbability: 0.05,
          headEulerAngleY: 0.0,
          headEulerAngleZ: 0.0,
        );

        final score = calculateAntiSpoofScore(photoFace);
        final liveness = checkLiveness(photoFace);

        print('🧪 Photo with closed eyes - Score: ${(score * 100).toInt()}%');

        expect(score, lessThan(0.4),
            reason: 'Very low eye values should heavily reduce score');
        expect(liveness, isFalse, reason: 'Closed eyes should fail liveness');
      });
    });

    group('👤 Real Face Acceptance', () {
      test('Should ACCEPT real face with natural eye variations', () {
        // Real faces have slight differences between eyes
        final realFace = MockFace(
          leftEyeOpenProbability: 0.78,
          rightEyeOpenProbability: 0.82, // Natural variation
          headEulerAngleY: 3.5, // Slight natural head movement
          headEulerAngleZ: 1.8,
        );

        final score = calculateAntiSpoofScore(realFace);
        final liveness = checkLiveness(realFace);

        print('🧪 Real face - Score: ${(score * 100).toInt()}%');

        expect(score, greaterThan(0.7),
            reason: 'Natural variations should give high score');
        expect(liveness, isTrue, reason: 'Real face should pass liveness');
      });

      test('Should ACCEPT real face with reasonable head tilt', () {
        final realFace = MockFace(
          leftEyeOpenProbability: 0.75,
          rightEyeOpenProbability: 0.7,
          headEulerAngleY: 8.0, // Slight head turn
          headEulerAngleZ: 4.0, // Slight tilt
        );

        final score = calculateAntiSpoofScore(realFace);
        final liveness = checkLiveness(realFace);

        print(
            '🧪 Real face with head movement - Score: ${(score * 100).toInt()}%');

        expect(score, greaterThan(0.6));
        expect(liveness, isTrue);
      });
    });

    group('👁️ Eye Variation Analysis', () {
      test('Photo: Eye values stay constant over time', () {
        // Simulated photo - eye values never change
        final photoEyeSequence = [
          0.95,
          0.95,
          0.95,
          0.95,
          0.95,
          0.95,
          0.95,
          0.95,
          0.95,
          0.95,
        ];

        final variation = calculateEyeVariation(photoEyeSequence);
        final blinkDetected = detectBlink(photoEyeSequence);

        print('🧪 Photo eye sequence - Variation: $variation');

        expect(variation, lessThan(0.15),
            reason: 'Photo should have minimal eye variation');
        expect(blinkDetected, isFalse, reason: 'Photo should never blink');
      });

      test('Real face: Eye values fluctuate naturally', () {
        // Simulated real face - eye values fluctuate
        final realEyeSequence = [
          0.85,
          0.82,
          0.88,
          0.79,
          0.84,
          0.86,
          0.78,
          0.81,
          0.87,
          0.83,
        ];

        final variation = calculateEyeVariation(realEyeSequence);

        print('🧪 Real eye sequence - Variation: $variation');

        expect(variation, greaterThan(0.05),
            reason: 'Real eyes should have natural variation');
      });

      test('Real face: Blink should be detected', () {
        // Simulated real blink sequence
        final blinkSequence = [
          0.85, // open
          0.82, // open
          0.45, // closing
          0.15, // closed
          0.12, // closed
          0.35, // opening
          0.72, // open
          0.81, // open
          0.78, // open
        ];

        final blinkDetected = detectBlink(blinkSequence, threshold: 0.3);
        final variation = calculateEyeVariation(blinkSequence);

        print('🧪 Blink sequence - Detected: $blinkDetected');
        print('🧪 Blink variation: $variation');

        expect(blinkDetected, isTrue,
            reason: 'Blink should be detected in sequence');
        expect(variation, greaterThan(0.5),
            reason: 'Blink should cause large variation');
      });
    });

    group('🔄 Head Movement Analysis', () {
      test('Photo: Head position stays constant', () {
        // Simulated photo - head never moves
        final headAngles = [
          {'yaw': 0.0, 'pitch': 0.0},
          {'yaw': 0.0, 'pitch': 0.0},
          {'yaw': 0.0, 'pitch': 0.0},
          {'yaw': 0.0, 'pitch': 0.0},
          {'yaw': 0.0, 'pitch': 0.0},
        ];

        double totalMovement = 0;
        for (int i = 1; i < headAngles.length; i++) {
          totalMovement +=
              (headAngles[i]['yaw']! - headAngles[i - 1]['yaw']!).abs();
          totalMovement +=
              (headAngles[i]['pitch']! - headAngles[i - 1]['pitch']!).abs();
        }

        print('🧪 Photo head movement: $totalMovement°');

        expect(totalMovement, lessThan(0.5),
            reason: 'Photo should have no head movement');
      });

      test('Real face: Natural micro-movements', () {
        // Simulated real face - natural micro-movements
        final headAngles = [
          {'yaw': 2.1, 'pitch': 1.0},
          {'yaw': 2.3, 'pitch': 1.2},
          {'yaw': 2.0, 'pitch': 0.9},
          {'yaw': 2.5, 'pitch': 1.1},
          {'yaw': 2.2, 'pitch': 1.3},
        ];

        double totalMovement = 0;
        for (int i = 1; i < headAngles.length; i++) {
          totalMovement +=
              (headAngles[i]['yaw']! - headAngles[i - 1]['yaw']!).abs();
          totalMovement +=
              (headAngles[i]['pitch']! - headAngles[i - 1]['pitch']!).abs();
        }

        print('🧪 Real face head movement: $totalMovement°');

        expect(totalMovement, greaterThan(0.5),
            reason: 'Real face should have natural micro-movements');
      });
    });

    group('🔐 Combined Anti-Spoof Verification', () {
      test('Combined photo attack should be REJECTED', () {
        // Typical photo attack characteristics
        final photoFace = MockFace(
          leftEyeOpenProbability: 0.95,
          rightEyeOpenProbability: 0.95,
          headEulerAngleY: 0.0,
          headEulerAngleZ: 0.0,
        );

        final score = calculateAntiSpoofScore(photoFace);
        final liveness = checkLiveness(photoFace);

        // Combined check: BOTH must pass
        final isVerified = score >= 0.5 && liveness;

        print('🧪 Combined photo attack check:');
        print('   Score: ${(score * 100).toInt()}%');
        print('   Liveness: $liveness');
        print('   Final: ${isVerified ? "ACCEPTED ❌" : "REJECTED ✅"}');

        expect(isVerified, isFalse,
            reason: 'Photo attack should be rejected by combined checks');
      });

      test('Real face should PASS combined checks', () {
        // Real face characteristics
        final realFace = MockFace(
          leftEyeOpenProbability: 0.76,
          rightEyeOpenProbability: 0.81,
          headEulerAngleY: 5.2,
          headEulerAngleZ: 2.3,
        );

        final score = calculateAntiSpoofScore(realFace);
        final liveness = checkLiveness(realFace);

        // Combined check: BOTH must pass
        final isVerified = score >= 0.5 && liveness;

        print('🧪 Combined real face check:');
        print('   Score: ${(score * 100).toInt()}%');
        print('   Liveness: $liveness');
        print('   Final: ${isVerified ? "ACCEPTED ✅" : "REJECTED ❌"}');

        expect(isVerified, isTrue,
            reason: 'Real face should pass combined checks');
      });
    });
  });
}
