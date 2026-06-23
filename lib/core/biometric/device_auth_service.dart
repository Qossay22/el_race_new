import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Unified device authentication service.
///
/// Uses the OS-level biometrics (Face ID, Touch ID, fingerprint, iris)
/// provided by the `local_auth` package.  No biometric data is stored
/// in the app — everything is handled by the operating system.
class DeviceAuthService {
  DeviceAuthService._();
  static final DeviceAuthService instance = DeviceAuthService._();

  final LocalAuthentication _auth = LocalAuthentication();

  // ───────────────────────── capability checks ─────────────────────────

  /// `true` when the device has biometric hardware AND the user has
  /// enrolled at least one biometric (face / fingerprint / iris).
  Future<bool> isBiometricAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;

      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;

      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Returns the human-readable name of the strongest available biometric.
  Future<String> biometricLabel() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      if (biometrics.contains(BiometricType.face)) {
        return Platform.isIOS ? 'Face ID' : 'التعرف على الوجه';
      }
      if (biometrics.contains(BiometricType.fingerprint) ||
          biometrics.contains(BiometricType.strong)) {
        return Platform.isIOS ? 'Touch ID' : 'بصمة الإصبع';
      }
      if (biometrics.contains(BiometricType.iris)) {
        return 'ماسح القزحية';
      }
      return 'المصادقة البيومترية';
    } catch (_) {
      return 'المصادقة البيومترية';
    }
  }

  // ────────────────────────── authentication ──────────────────────────

  /// Prompt the system biometric dialog.
  ///
  /// * [reason] – localised string shown to the user.
  /// * [biometricOnly] – `true` → only biometrics; `false` → allow device
  ///   passcode as an OS-level fallback. Keep `true` for attendance security.
  ///
  /// Returns `true` on success.
  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = true,
  }) async {
    try {
      final result = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
        ),
      );
      return result;
    } on PlatformException catch (e) {
      debugPrint('🔐 DeviceAuthService: ${e.code} – ${e.message}');
      return false;
    } catch (e) {
      debugPrint('🔐 DeviceAuthService: unexpected error – $e');
      return false;
    }
  }

  /// Cancel any on-going authentication prompt.
  Future<void> cancelAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
