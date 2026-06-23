import 'package:flutter/material.dart';
import 'package:el_race/core/biometric/device_auth_service.dart';

/// Unified authentication helper.
///
/// **Strategy:**
/// Require enrolled biometrics (Face ID / fingerprint / iris) only.
/// PIN, passcode, password, and pattern fallback are intentionally disabled.
class UnifiedBiometricHelper {
  UnifiedBiometricHelper._();

  static final _deviceAuth = DeviceAuthService.instance;

  // ─────────────────────── public API ───────────────────────

  /// Authenticate for check-in / check-out.
  static Future<bool> authenticateForAttendance(BuildContext context) async {
    return _authenticate(context, reason: 'تحقق من هويتك لتسجيل الحضور');
  }

  /// Authenticate for sensitive data access.
  static Future<bool> authenticateForSensitiveData(BuildContext context) async {
    return _authenticate(context, reason: 'تحقق من هويتك لعرض البيانات');
  }

  /// Authenticate for payments.
  static Future<bool> authenticateForPayment(BuildContext context) async {
    return _authenticate(context, reason: 'تحقق من هويتك لإتمام الدفع');
  }

  /// Authenticate for profile changes.
  static Future<bool> authenticateForProfileChange(BuildContext context) async {
    return _authenticate(context, reason: 'تحقق من هويتك لتعديل الملف الشخصي');
  }

  /// Generic authentication with a custom [reason].
  static Future<bool> authenticate({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String reason,
  }) async {
    return _authenticate(context, reason: reason);
  }

  /// Returns `true` only when a real biometric is enrolled on the device.
  static Future<bool> isBiometricAvailable() async =>
      _deviceAuth.isBiometricAvailable();

  // ─────────────────────── internals ───────────────────────

  static Future<bool> _authenticate(
    BuildContext context, {
    required String reason,
  }) async {
    final hasBio = await _deviceAuth.isBiometricAvailable();

    if (hasBio) {
      // ── Device biometrics only (Face ID / fingerprint / iris) ──
      return await _deviceAuth.authenticate(
        reason: reason,
        biometricOnly: true,
      );
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يجب تفعيل بصمة الوجه أو الإصبع على الجهاز. رمز PIN غير مسموح.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
    return false;
  }
}
