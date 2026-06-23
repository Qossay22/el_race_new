import 'package:flutter/material.dart';
import 'package:el_race/core/services/biometric_auth_service.dart';

/// Example widget demonstrating how to use BiometricAuthService
///
/// This example shows proper usage from a UI layer:
/// - Checking biometric availability
/// - Handling authentication results
/// - Displaying user-friendly error messages
/// - Graceful fallback behavior
class BiometricAuthExample extends StatefulWidget {
  const BiometricAuthExample({super.key});

  @override
  State<BiometricAuthExample> createState() => _BiometricAuthExampleState();
}

class _BiometricAuthExampleState extends State<BiometricAuthExample> {
  final BiometricAuthService _biometricService = BiometricAuthService.instance;

  bool _isBiometricAvailable = false;
  String _biometricTypeName = '';
  String _statusMessage = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  /// Check if biometrics are available on device
  Future<void> _checkBiometricAvailability() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking biometric availability...';
    });

    try {
      final isAvailable =
          await _biometricService.canAuthenticateWithBiometrics();
      final typeName = await _biometricService.getBiometricTypeName();

      setState(() {
        _isBiometricAvailable = isAvailable;
        _biometricTypeName = typeName;
        _statusMessage = isAvailable
            ? '$typeName is available on this device'
            : 'Biometric authentication is not available';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isBiometricAvailable = false;
        _statusMessage = 'Error checking biometrics: $e';
        _isLoading = false;
      });
    }
  }

  /// Perform biometric authentication
  Future<void> _authenticateWithBiometrics() async {
    if (!_isBiometricAvailable) {
      _showMessage('Biometric authentication is not available', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Authenticating...';
    });

    try {
      final result = await _biometricService.authenticate(
        reason: 'Please authenticate to continue',
        biometricOnly: true,
        stickyAuth: true,
      );

      setState(() {
        _isLoading = false;
      });

      if (result.success) {
        _showMessage('✅ Authentication successful!', isError: false);
        _onAuthenticationSuccess();
      } else {
        _handleAuthenticationError(result);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Unexpected error: $e';
      });
      _showMessage('An unexpected error occurred', isError: true);
    }
  }

  /// Handle authentication errors with appropriate UI feedback
  void _handleAuthenticationError(BiometricAuthResult result) {
    String userMessage;
    bool shouldRetry = true;

    switch (result.errorType) {
      case BiometricAuthErrorType.notEnrolled:
        userMessage =
            'No biometrics enrolled. Please set up $_biometricTypeName in Settings.';
        shouldRetry = false;
        break;

      case BiometricAuthErrorType.lockedOut:
        userMessage = 'Too many attempts. Please try again later.';
        shouldRetry = false;
        break;

      case BiometricAuthErrorType.permanentlyLockedOut:
        userMessage = 'Biometrics locked. Please use device passcode.';
        shouldRetry = false;
        break;

      case BiometricAuthErrorType.canceled:
        userMessage = 'Authentication canceled';
        shouldRetry = true;
        break;

      case BiometricAuthErrorType.timeout:
        userMessage = 'Authentication timed out. Please try again.';
        shouldRetry = true;
        break;

      case BiometricAuthErrorType.notAvailable:
        userMessage = 'Biometric authentication is not available';
        shouldRetry = false;
        break;

      default:
        userMessage = result.errorMessage ?? 'Authentication failed';
        shouldRetry = true;
    }

    setState(() {
      _statusMessage = userMessage;
    });

    _showMessage(userMessage, isError: true, canRetry: shouldRetry);
  }

  /// Called when authentication succeeds
  void _onAuthenticationSuccess() {
    setState(() {
      _statusMessage = 'Authentication successful!';
    });

    // Proceed with your app logic here
    // For example:
    // - Navigate to secure screen
    // - Unlock sensitive features
    // - Perform authorized action
    debugPrint('🔓 User authenticated successfully');
  }

  /// Show a message to the user
  void _showMessage(String message,
      {required bool isError, bool canRetry = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
        action: canRetry
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _authenticateWithBiometrics,
              )
            : null,
      ),
    );
  }

  @override
  void dispose() {
    // Clean up authentication if needed
    _biometricService.stopAuthentication();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Authentication Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isBiometricAvailable
                              ? Icons.check_circle
                              : Icons.error,
                          color:
                              _isBiometricAvailable ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_statusMessage),
                        ),
                      ],
                    ),
                    if (_isBiometricAvailable &&
                        _biometricTypeName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Available: $_biometricTypeName',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Authenticate Button
            ElevatedButton.icon(
              onPressed: _isLoading || !_isBiometricAvailable
                  ? null
                  : _authenticateWithBiometrics,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fingerprint),
              label: Text(
                _isLoading
                    ? 'Authenticating...'
                    : 'Authenticate with $_biometricTypeName',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 16),

            // Refresh Button
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _checkBiometricAvailability,
              icon: const Icon(Icons.refresh),
              label: const Text('Check Availability'),
            ),

            const Spacer(),

            // Info Text
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'About Biometric Authentication',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• No biometric data is stored\n'
                      '• All authentication is handled by the OS\n'
                      '• App only receives success/failure results\n'
                      '• Supports Face ID, Touch ID, Fingerprint, etc.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// Example: Using BiometricAuthService in a ViewModel/Controller (e.g., with GetX)
// ==============================================================================

/// Example ViewModel showing how to use BiometricAuthService
/// This follows clean architecture principles
class ExampleBiometricViewModel {
  final BiometricAuthService _biometricService = BiometricAuthService.instance;

  /// Check if biometrics can be used
  Future<bool> isBiometricAuthAvailable() async {
    return await _biometricService.canAuthenticateWithBiometrics();
  }

  /// Authenticate user with biometrics
  /// Returns true if successful, false otherwise
  Future<bool> authenticateUser({String? customReason}) async {
    // First check if available
    final canAuthenticate = await isBiometricAuthAvailable();
    if (!canAuthenticate) {
      debugPrint('⚠️ Biometrics not available');
      return false;
    }

    // Perform authentication
    final result = await _biometricService.authenticate(
      reason: customReason ?? 'Please authenticate to continue',
      biometricOnly: true,
      stickyAuth: true,
    );

    if (result.success) {
      debugPrint('✅ User authenticated');
      return true;
    } else {
      debugPrint('❌ Authentication failed: ${result.errorMessage}');
      return false;
    }
  }

  /// Get friendly name for UI display
  Future<String> getBiometricName() async {
    return await _biometricService.getBiometricTypeName();
  }
}
