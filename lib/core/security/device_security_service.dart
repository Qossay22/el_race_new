import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:safe_device/safe_device.dart';
import 'package:vpn_connection_detector/vpn_connection_detector.dart';
import 'package:el_race/core/services/app_config_service.dart';

const _vpnChannel = MethodChannel('com.elrace/vpn_check');

/// Security check result containing all security statuses
class SecurityCheckResult {
  final bool isRooted;
  final bool isJailbroken;
  final bool isUsingVpn;
  final bool isMockLocation;
  final bool isEmulator;
  final bool isSecure;
  final String? errorMessage;

  SecurityCheckResult({
    required this.isRooted,
    required this.isJailbroken,
    required this.isUsingVpn,
    required this.isMockLocation,
    required this.isEmulator,
    this.errorMessage,
  }) : isSecure = !isRooted &&
            !isJailbroken &&
            !isUsingVpn &&
            !isMockLocation &&
            !isEmulator;

  /// Returns the reason why device is not secure
  String getSecurityViolationMessage() {
    List<String> violations = [];

    if (isRooted || isJailbroken) {
      violations.add(Platform.isIOS
          ? 'Jailbreak detected on device'
          : 'Root access detected on device');
    }
    if (isUsingVpn) {
      violations.add('Active VPN connection detected');
    }
    if (isMockLocation) {
      violations.add('Fake location (Mock Location) detected');
    }
    if (isEmulator) {
      violations.add('Emulator detected');
    }

    if (violations.isEmpty) {
      return '';
    }

    return violations.join('\n');
  }

  /// Returns a user-friendly message
  String getUserFriendlyMessage() {
    if (isSecure) {
      return 'Device is secure ✓';
    }

    return 'The application cannot be used for the following reasons:\n\n${getSecurityViolationMessage()}\n\nPlease disable these features and restart the application.';
  }
}

/// Service for checking device security status
class DeviceSecurityService {
  static final DeviceSecurityService _instance =
      DeviceSecurityService._internal();
  factory DeviceSecurityService() => _instance;
  DeviceSecurityService._internal();

  static DeviceSecurityService get instance => _instance;

  /// Performs all security checks and returns the result
  Future<SecurityCheckResult> performSecurityCheck() async {
    bool isRooted = false;
    bool isJailbroken = false;
    bool isUsingVpn = false;
    bool isMockLocation = false;
    bool isEmulator = false;
    String? errorMessage;

    try {
      // Check Root/Jailbreak
      try {
        if (Platform.isAndroid) {
          isRooted = await FlutterJailbreakDetection.jailbroken;
          print('🔒 Root check: $isRooted');
        } else if (Platform.isIOS) {
          isJailbroken = await FlutterJailbreakDetection.jailbroken;
          print('🔒 Jailbreak check: $isJailbroken');
        }
      } catch (e) {
        print('⚠️ Error checking root/jailbreak: $e');
      }

      // Check VPN
      // Skip VPN check if backend or test-mode says so
      if (AppConfigService.instance.shouldSkipVpnCheck) {
        print('🔒 VPN check: SKIPPED (shouldSkipVpnCheck=true)');
      } else {
        // iOS: use NEVPNManager via platform channel (accurate, no false positives)
        // Android: use vpn_connection_detector
        try {
          if (Platform.isIOS) {
            print('🔒 iOS: Calling VPN check via platform channel...');
            isUsingVpn =
                await _vpnChannel.invokeMethod<bool>('isVpnActive') ?? false;
            print('🔒 iOS: VPN check result: $isUsingVpn');
          } else {
            print('🔒 Android: Calling VPN detector...');
            isUsingVpn = await VpnConnectionDetector.isVpnActive();
            print('🔒 Android: VPN check result: $isUsingVpn');
          }
        } catch (e) {
          print('⚠️ Error checking VPN: $e');
          print('⚠️ VPN check failed, defaulting to: isUsingVpn=false');
          // Don't fail the security check if VPN detection fails
          isUsingVpn = false;
        }
      }

      // Check Mock Location (Android only, iOS doesn't allow mock locations easily)
      try {
        if (Platform.isAndroid) {
          isMockLocation = await SafeDevice.isMockLocation;
          print('🔒 Mock location check: $isMockLocation');
        }
      } catch (e) {
        print('⚠️ Error checking mock location: $e');
      }

      // Note: Emulator check disabled - SafeDevice.isRealDevice is unreliable
      // and gives false positives on some Samsung devices
      // If you need emulator detection, consider using a different approach
      print('🔒 Emulator check: skipped (unreliable)');
    } catch (e) {
      errorMessage = 'Security check error: $e';
      print('❌ Security check error: $e');
    }

    final result = SecurityCheckResult(
      isRooted: isRooted,
      isJailbroken: isJailbroken,
      isUsingVpn: isUsingVpn,
      isMockLocation: isMockLocation,
      isEmulator: isEmulator, // Always false now
      errorMessage: errorMessage,
    );

    print('═══════════════════════════════════════════════════════════');
    print('🔒 SECURITY CHECK RESULT:');
    print('   - Root/Jailbreak: ${isRooted || isJailbroken}');
    print('   - VPN Active: $isUsingVpn');
    print('   - Mock Location: $isMockLocation');
    print('   - Emulator: $isEmulator');
    print('   - Is Secure: ${result.isSecure}');
    print('═══════════════════════════════════════════════════════════');

    return result;
  }

  /// Quick check - returns true if device is secure
  Future<bool> isDeviceSecure() async {
    final result = await performSecurityCheck();
    return result.isSecure;
  }

  /// Shows a blocking dialog if the device is not secure
  static Future<void> showSecurityBlockDialog(
    BuildContext context,
    SecurityCheckResult result,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent back button
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.security, color: Colors.red, size: 32),
              SizedBox(width: 12),
              Text(
                'Security Warning',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.getUserFriendlyMessage(),
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'To protect your data security, the app cannot be used in this state.',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  // Retry button – re-run security check without killing the app
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop(); // dismiss dialog
                        final newResult = await DeviceSecurityService.instance
                            .performSecurityCheck();
                        if (!newResult.isSecure && context.mounted) {
                          showSecurityBlockDialog(context, newResult);
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        exit(0);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Close App',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Alternative: Shows a full-screen blocking page
  static Widget buildSecurityBlockScreen(SecurityCheckResult result) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.security,
                  size: 100,
                  color: Colors.red,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Security Warning',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    result.getUserFriendlyMessage(),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => exit(0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close App',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
