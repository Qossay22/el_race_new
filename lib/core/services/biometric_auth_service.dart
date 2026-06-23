import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

/// Biometric authentication result
class BiometricAuthResult {
  final bool success;
  final String? errorMessage;
  final BiometricAuthErrorType? errorType;

  const BiometricAuthResult({
    required this.success,
    this.errorMessage,
    this.errorType,
  });

  factory BiometricAuthResult.success() {
    return const BiometricAuthResult(success: true);
  }

  factory BiometricAuthResult.failure(
    String errorMessage, {
    BiometricAuthErrorType? errorType,
  }) {
    return BiometricAuthResult(
      success: false,
      errorMessage: errorMessage,
      errorType: errorType,
    );
  }
}

/// Types of biometric authentication errors
enum BiometricAuthErrorType {
  notEnrolled,
  notAvailable,
  lockedOut,
  permanentlyLockedOut,
  canceled,
  timeout,
  unknown,
}

/// Service for handling biometric authentication using local_auth package
///
/// This service provides a clean abstraction layer for biometric authentication
/// (Face ID, Touch ID, fingerprint, etc.) without storing any biometric data.
/// All biometric data is handled exclusively by the OS.
class BiometricAuthService {
  BiometricAuthService._();
  static final BiometricAuthService _instance = BiometricAuthService._();
  static BiometricAuthService get instance => _instance;

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if biometric authentication is available on this device
  ///
  /// Returns true if:
  /// - Device has biometric hardware
  /// - Device is secured with at least a PIN/password
  /// - User has enrolled at least one biometric (fingerprint or face)
  Future<bool> canAuthenticateWithBiometrics() async {
    try {
      // Check if device supports biometrics
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) {
        debugPrint(
            '🔐 BiometricAuthService: Device does not support biometrics');
        return false;
      }

      // Check if biometrics can be checked (device is secured)
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        debugPrint(
            '🔐 BiometricAuthService: Device is not secured (no PIN/password set)');
        return false;
      }

      // Check if any biometrics are enrolled
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      if (availableBiometrics.isEmpty) {
        debugPrint('🔐 BiometricAuthService: No biometrics enrolled on device');
        return false;
      }

      debugPrint(
          '🔐 BiometricAuthService: Biometrics available: $availableBiometrics');
      return true;
    } on PlatformException catch (e) {
      debugPrint(
          '🔐 BiometricAuthService: Error checking biometric availability: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('🔐 BiometricAuthService: Unexpected error: $e');
      return false;
    }
  }

  /// Get list of available biometric types on this device
  ///
  /// Returns list of BiometricType enum values:
  /// - BiometricType.face (Face ID on iOS, Face unlock on Android)
  /// - BiometricType.fingerprint (Touch ID on iOS, Fingerprint on Android)
  /// - BiometricType.iris (Iris scanner on some Android devices)
  /// - BiometricType.strong (Strong biometrics on Android)
  /// - BiometricType.weak (Weak biometrics on Android)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final biometrics = await _localAuth.getAvailableBiometrics();
      debugPrint('🔐 BiometricAuthService: Available biometrics: $biometrics');
      return biometrics;
    } on PlatformException catch (e) {
      debugPrint(
          '🔐 BiometricAuthService: Error getting biometrics: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('🔐 BiometricAuthService: Unexpected error: $e');
      return [];
    }
  }

  /// Check if Face ID or Face unlock is available
  Future<bool> isFaceIdAvailable() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.face);
  }

  /// Check if Touch ID or Fingerprint is available
  Future<bool> isFingerprintAvailable() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.fingerprint) ||
        biometrics.contains(BiometricType.strong) ||
        biometrics.contains(BiometricType.weak);
  }

  /// Authenticate user with biometrics
  ///
  /// [reason] - User-facing message explaining why authentication is needed
  ///           This appears in the system authentication dialog
  ///
  /// [biometricOnly] - If true, only biometric authentication is allowed
  ///                   If false, device passcode is accepted as fallback
  ///
  /// [stickyAuth] - If true, plugin doesn't return until authentication succeeds,
  ///                fails, or is canceled. Survives app backgrounding.
  ///
  /// [useErrorDialogs] - If true, shows system error dialogs for failures
  ///
  /// Returns BiometricAuthResult with success status and error details if failed
  Future<BiometricAuthResult> authenticate({
    required String reason,
    bool biometricOnly = true,
    bool stickyAuth = true,
    bool useErrorDialogs = true,
  }) async {
    // Validate input
    if (reason.isEmpty) {
      debugPrint('🔐 BiometricAuthService: Error - empty reason provided');
      return BiometricAuthResult.failure(
        'Authentication reason cannot be empty',
        errorType: BiometricAuthErrorType.unknown,
      );
    }

    // Check if biometrics are available
    final bool canAuthenticate = await canAuthenticateWithBiometrics();
    if (!canAuthenticate) {
      debugPrint('🔐 BiometricAuthService: Biometrics not available');
      return BiometricAuthResult.failure(
        'Biometric authentication is not available on this device',
        errorType: BiometricAuthErrorType.notAvailable,
      );
    }

    try {
      debugPrint('🔐 BiometricAuthService: Starting authentication...');

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: stickyAuth,
          biometricOnly: biometricOnly,
          useErrorDialogs: useErrorDialogs,
        ),
      );

      if (didAuthenticate) {
        debugPrint('🔐 BiometricAuthService: ✅ Authentication successful');
        return BiometricAuthResult.success();
      } else {
        debugPrint('🔐 BiometricAuthService: ❌ Authentication failed');
        return BiometricAuthResult.failure(
          'Authentication failed',
          errorType: BiometricAuthErrorType.unknown,
        );
      }
    } on PlatformException catch (e) {
      debugPrint(
          '🔐 BiometricAuthService: Platform exception: ${e.code} - ${e.message}');
      return _handlePlatformException(e);
    } catch (e) {
      debugPrint('🔐 BiometricAuthService: Unexpected error: $e');
      return BiometricAuthResult.failure(
        'An unexpected error occurred during authentication',
        errorType: BiometricAuthErrorType.unknown,
      );
    }
  }

  /// Handle platform-specific exceptions and return appropriate result
  BiometricAuthResult _handlePlatformException(PlatformException e) {
    BiometricAuthErrorType errorType;
    String errorMessage;

    switch (e.code) {
      case auth_error.notEnrolled:
        errorType = BiometricAuthErrorType.notEnrolled;
        errorMessage = Platform.isIOS
            ? 'No biometrics enrolled. Please set up Face ID or Touch ID in Settings.'
            : 'No biometrics enrolled. Please set up fingerprint or face unlock in Settings.';
        break;

      case auth_error.lockedOut:
        errorType = BiometricAuthErrorType.lockedOut;
        errorMessage =
            'Too many failed attempts. Biometric authentication is temporarily disabled.';
        break;

      case auth_error.permanentlyLockedOut:
        errorType = BiometricAuthErrorType.permanentlyLockedOut;
        errorMessage =
            'Biometric authentication is permanently disabled. Please use device passcode.';
        break;

      case auth_error.notAvailable:
        errorType = BiometricAuthErrorType.notAvailable;
        errorMessage =
            'Biometric authentication is not available on this device.';
        break;

      case 'AuthenticationCanceled':
      case 'UserCanceled':
        errorType = BiometricAuthErrorType.canceled;
        errorMessage = 'Authentication was canceled';
        break;

      case 'AuthenticationTimeout':
      case 'Timeout':
        errorType = BiometricAuthErrorType.timeout;
        errorMessage = 'Authentication timed out. Please try again.';
        break;

      default:
        errorType = BiometricAuthErrorType.unknown;
        errorMessage = e.message ?? 'An error occurred during authentication';
        break;
    }

    return BiometricAuthResult.failure(errorMessage, errorType: errorType);
  }

  /// Get a user-friendly name for available biometric types
  /// Useful for displaying in UI
  Future<String> getBiometricTypeName() async {
    if (!await canAuthenticateWithBiometrics()) {
      return 'Biometric';
    }

    final biometrics = await getAvailableBiometrics();

    if (biometrics.isEmpty) {
      return 'Biometric';
    }

    // Prioritize face over fingerprint in naming
    if (biometrics.contains(BiometricType.face)) {
      return Platform.isIOS ? 'Face ID' : 'Face Unlock';
    }

    if (biometrics.contains(BiometricType.fingerprint)) {
      return Platform.isIOS ? 'Touch ID' : 'Fingerprint';
    }

    if (biometrics.contains(BiometricType.strong)) {
      return 'Biometric';
    }

    if (biometrics.contains(BiometricType.iris)) {
      return 'Iris Scanner';
    }

    return 'Biometric';
  }

  /// Stop any ongoing authentication
  /// Useful for cleanup when user navigates away
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
      debugPrint('🔐 BiometricAuthService: Authentication stopped');
    } catch (e) {
      debugPrint('🔐 BiometricAuthService: Error stopping authentication: $e');
    }
  }
}
