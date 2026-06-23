import 'package:flutter/foundation.dart';

/// Feature flags controlling biometric behavior.
///
/// Local attendance biometrics are allowed in production with known
/// limitations; remote/centralized options remain optional.
class FeatureFlags {
  /// Enable the on-device attendance biometric flow (default false).
  static const bool enableLocalBiometrics = bool.fromEnvironment(
    'ENABLE_LOCAL_BIOMETRICS',
    defaultValue: false,
  );

  /// Optional remote / centralized attendance biometrics.
  static const bool useRemoteAttendanceBiometrics = bool.fromEnvironment(
    'ENABLE_REMOTE_ATTENDANCE_BIOMETRICS',
    defaultValue: bool.fromEnvironment(
      // Backwards-compatibility with earlier flag name
      'ENABLE_BANK_GRADE_BIOMETRICS',
      defaultValue: false,
    ),
  );

  /// Backwards-compatibility getter.
  static bool get useBankGradeBiometrics => useRemoteAttendanceBiometrics;

  /// Validate build-time flags; warn instead of throwing to allow
  /// on-device attendance in production.
  static void validateProductionConfig() {
    if (kReleaseMode &&
        enableLocalBiometrics &&
        !useRemoteAttendanceBiometrics) {
      debugPrint(
        'ℹ️ Local attendance biometrics enabled in release. Ensure stakeholders '
        'accept the casual-misuse limitations.',
      );
    }
  }
}
