import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:el_race/core/services/app_config_service.dart';
import 'package:el_race/core/services/biometric_auth_service.dart';

/// Enum representing available authentication methods
enum AuthMethod {
  faceRecognition,
  fingerprint,
  none,
}

/// Result of authentication attempt
class AuthResult {
  final bool success;
  final AuthMethod method;
  final String? message;

  AuthResult({
    required this.success,
    required this.method,
    this.message,
  });
}

/// LEGACY SERVICE - Used for project selection dialogs only.
///
/// For attendance (check-in/out), use UnifiedBiometricHelper instead.
/// This service uses platform-specific biometrics (Face ID/Fingerprint).
///
/// Service to handle multiple authentication methods with fallback
class AuthVerificationService {
  static final AuthVerificationService _instance =
      AuthVerificationService._internal();
  factory AuthVerificationService() => _instance;
  AuthVerificationService._internal();

  final BiometricAuthService _biometricService = BiometricAuthService.instance;

  // Keys for SharedPreferences
  static const String _preferredAuthMethodKey = 'preferred_auth_method';

  /// Check if device supports biometric authentication (fingerprint/face)
  Future<bool> isBiometricAvailable() async {
    if (AppConfigService.instance.isTestMode) {
      return false;
    }
    return await _biometricService.canAuthenticateWithBiometrics();
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (AppConfigService.instance.isTestMode) {
      return [];
    }
    return await _biometricService.getAvailableBiometrics();
  }

  /// Check if fingerprint is available
  Future<bool> isFingerprintAvailable() async {
    if (AppConfigService.instance.isTestMode) {
      return false;
    }
    return await _biometricService.isFingerprintAvailable();
  }

  /// Check if device face recognition (Face ID) is available
  Future<bool> isDeviceFaceIdAvailable() async {
    if (AppConfigService.instance.isTestMode) {
      return false;
    }
    return await _biometricService.isFaceIdAvailable();
  }

  /// Check if front camera is available for face recognition
  Future<bool> isFrontCameraAvailable() async {
    if (AppConfigService.instance.isTestMode) {
      return false;
    }
    try {
      final cameras = await availableCameras();
      return cameras
          .any((camera) => camera.lensDirection == CameraLensDirection.front);
    } catch (e) {
      debugPrint('Error checking front camera availability: $e');
      return false;
    }
  }

  /// Authenticate using device biometrics (fingerprint or Face ID)
  Future<AuthResult> authenticateWithBiometrics({
    String localizedReason = 'الرجاء التحقق من هويتك للمتابعة',
    bool biometricOnly = true,
  }) async {
    if (AppConfigService.instance.isTestMode) {
      return AuthResult(
        success: false,
        method: AuthMethod.none,
        message: 'تم تعطيل البصمات في وضع الاختبار',
      );
    }

    final result = await _biometricService.authenticate(
      reason: localizedReason,
      biometricOnly: biometricOnly,
      stickyAuth: true,
      useErrorDialogs: true,
    );

    if (result.success) {
      final biometrics = await getAvailableBiometrics();
      AuthMethod usedMethod = AuthMethod.fingerprint;
      if (biometrics.contains(BiometricType.face)) {
        usedMethod = AuthMethod.faceRecognition;
      }

      return AuthResult(
        success: true,
        method: usedMethod,
        message: 'تم التحقق بنجاح',
      );
    } else {
      return AuthResult(
        success: false,
        method: AuthMethod.none,
        message: result.errorMessage ?? 'فشل التحقق',
      );
    }
  }

  /// Authenticate using fingerprint only
  Future<AuthResult> authenticateWithFingerprint() async {
    final result = await _biometricService.authenticate(
      reason: 'ضع إصبعك على الماسح للتحقق',
      biometricOnly: true,
      stickyAuth: true,
      useErrorDialogs: true,
    );

    return AuthResult(
      success: result.success,
      method: AuthMethod.fingerprint,
      message: result.success
          ? 'تم التحقق بنجاح'
          : result.errorMessage ?? 'فشل التحقق بالبصمة',
    );
  }

  /// Get the best available authentication method for this device
  Future<AuthMethod> getBestAvailableMethod() async {
    // First priority: device biometrics (fingerprint/Face ID)
    if (await isBiometricAvailable()) {
      final biometrics = await getAvailableBiometrics();
      if (biometrics.contains(BiometricType.fingerprint) ||
          biometrics.contains(BiometricType.strong) ||
          biometrics.contains(BiometricType.weak)) {
        return AuthMethod.fingerprint;
      }
      if (biometrics.contains(BiometricType.face)) {
        return AuthMethod.faceRecognition;
      }
    }

    // No PIN/password fallback is allowed.
    return AuthMethod.none;
  }

  /// Get all available authentication methods based on device capabilities
  Future<List<AuthMethod>> getAvailableMethods() async {
    final methods = <AuthMethod>[];

    // Add face recognition only when not in test mode and front camera is available
    if (!AppConfigService.instance.isTestMode &&
        await isFrontCameraAvailable()) {
      methods.add(AuthMethod.faceRecognition);
    }

    // Check device biometrics
    if (!AppConfigService.instance.isTestMode && await isBiometricAvailable()) {
      final biometrics = await getAvailableBiometrics();

      // Check for fingerprint
      if (biometrics.contains(BiometricType.fingerprint) ||
          biometrics.contains(BiometricType.strong) ||
          biometrics.contains(BiometricType.weak)) {
        methods.add(AuthMethod.fingerprint);
      }
    }

    return methods;
  }

  /// Save preferred authentication method
  Future<void> setPreferredMethod(AuthMethod method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferredAuthMethodKey, method.name);
  }

  /// Get preferred authentication method
  Future<AuthMethod?> getPreferredMethod() async {
    final prefs = await SharedPreferences.getInstance();
    final methodName = prefs.getString(_preferredAuthMethodKey);
    if (methodName == null) return null;

    try {
      return AuthMethod.values.firstWhere((m) => m.name == methodName);
    } catch (_) {
      return null;
    }
  }

  /// Show authentication options dialog and return result
  Future<AuthResult?> showAuthOptionsDialog(BuildContext context) async {
    final availableMethods = await getAvailableMethods();
    if (!context.mounted) return null;

    return showDialog<AuthResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AuthOptionsDialog(
        availableMethods: availableMethods,
        authService: this,
      ),
    );
  }
}

/// Dialog to show available authentication options
class AuthOptionsDialog extends StatefulWidget {
  final List<AuthMethod> availableMethods;
  final AuthVerificationService authService;

  const AuthOptionsDialog({
    super.key,
    required this.availableMethods,
    required this.authService,
  });

  @override
  State<AuthOptionsDialog> createState() => _AuthOptionsDialogState();
}

class _AuthOptionsDialogState extends State<AuthOptionsDialog> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _authenticateWithFingerprint() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.authService.authenticateWithBiometrics(
      localizedReason: 'التحقق من الهوية للحضور',
      biometricOnly: true,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.of(context).pop(result);
    } else {
      setState(() => _errorMessage = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'اختر طريقة التحقق',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              )
            else
              _buildAuthOptions(),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }

  Widget _buildAuthOptions() {
    return Column(
      children: [
        // Face Recognition option (app-level camera face recognition)
        if (widget.availableMethods.contains(AuthMethod.faceRecognition))
          _buildAuthOption(
            icon: Icons.face,
            title: 'التعرف على الوجه',
            subtitle: 'استخدم الكاميرا للتحقق من الوجه',
            onTap: _selectCameraFaceRecognition,
            color: const Color(0xFF1A1A53),
          ),

        // Fingerprint option (device biometric)
        if (widget.availableMethods.contains(AuthMethod.fingerprint))
          _buildAuthOption(
            icon: Icons.fingerprint,
            title: 'بصمة الإصبع',
            subtitle: 'استخدم بصمة الإصبع للتحقق',
            onTap: _authenticateWithFingerprint,
            color: const Color(0xFF28A745),
          ),
      ],
    );
  }

  /// Select camera face recognition - returns to the original face verification flow
  void _selectCameraFaceRecognition() {
    Navigator.of(context).pop(AuthResult(
      success: false,
      method: AuthMethod.faceRecognition,
      message: 'use_face_recognition',
    ));
  }

  Widget _buildAuthOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
