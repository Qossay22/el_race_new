import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:el_race/utils/urll_utils.dart';

/// Result of a version check
class UpdateCheckResult {
  /// True if the user MUST update (current < minVersion)
  final bool forceUpdate;

  /// True if an optional update is available (currentVersion < latestVersion)
  final bool optionalUpdate;

  /// The latest version string from backend  (e.g. "1.2.0")
  final String? latestVersion;

  /// Minimum required version string (e.g. "1.0.5")
  final String? minVersion;

  /// Deep-link / store URL to open for update
  final String? updateUrl;

  /// Optional custom message to show the user (English)
  final String? updateMessageEn;

  /// Optional custom message to show the user (Arabic)
  final String? updateMessageAr;

  const UpdateCheckResult({
    required this.forceUpdate,
    required this.optionalUpdate,
    this.latestVersion,
    this.minVersion,
    this.updateUrl,
    this.updateMessageEn,
    this.updateMessageAr,
  });

  /// No update needed
  const UpdateCheckResult.noUpdate()
      : forceUpdate = false,
        optionalUpdate = false,
        latestVersion = null,
        minVersion = null,
        updateUrl = null,
        updateMessageEn = null,
        updateMessageAr = null;
}

/// Service responsible for checking if a newer / mandatory version is available.
///
/// The backend endpoint `app/config` (POST JSON-RPC) is expected to include
/// the following optional fields in the `result` payload:
///
/// ```json
/// {
///   "minVersion":      "1.0.5",
///   "latestVersion":   "1.2.0",
///   "updateUrl":       "https://play.google.com/store/apps/details?id=com.el_race.app",
///   "updateMessageEn": "A new version is available. Please update.",
///   "updateMessageAr": "يتوفر إصدار جديد. يرجى التحديث."
/// }
/// ```
///
/// If any field is missing the check is skipped gracefully.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// Check the backend for version requirements.
  ///
  /// [currentVersion] should be the semver string from pubspec, e.g. "1.0.10".
  Future<UpdateCheckResult> checkForUpdate(String currentVersion) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'Content-Type': 'application/json'},
      ));

      const String url = '${UrlUtil.baseUrl}app/config';
      final resp = await dio.get(
        url,
        data: {'jsonrpc': '2.0', 'params': {}},
      );

      Map<String, dynamic>? payload;
      final data = resp.data;
      if (data is Map<String, dynamic>) {
        payload = data['result'] is Map<String, dynamic>
            ? data['result'] as Map<String, dynamic>
            : data;
      } else if (data is String) {
        try {
          final parsed = jsonDecode(data);
          if (parsed is Map<String, dynamic>) {
            payload = parsed['result'] is Map<String, dynamic>
                ? parsed['result'] as Map<String, dynamic>
                : parsed;
          }
        } catch (_) {}
      }

      if (payload == null) return const UpdateCheckResult.noUpdate();

      final minVersionStr = payload['minVersion'] as String?;
      final latestVersionStr = payload['latestVersion'] as String?;
      final updateUrl = payload['updateUrl'] as String?;
      final updateMessageEn = payload['updateMessageEn'] as String?;
      final updateMessageAr = payload['updateMessageAr'] as String?;

      // If backend sends nothing, no update needed
      if (minVersionStr == null && latestVersionStr == null) {
        return const UpdateCheckResult.noUpdate();
      }

      final current = _parseVersion(currentVersion);

      bool forceUpdate = false;
      bool optionalUpdate = false;

      if (minVersionStr != null) {
        final min = _parseVersion(minVersionStr);
        if (_compareVersions(current, min) < 0) {
          forceUpdate = true;
        }
      }

      if (!forceUpdate && latestVersionStr != null) {
        final latest = _parseVersion(latestVersionStr);
        if (_compareVersions(current, latest) < 0) {
          optionalUpdate = true;
        }
      }

      return UpdateCheckResult(
        forceUpdate: forceUpdate,
        optionalUpdate: optionalUpdate,
        latestVersion: latestVersionStr,
        minVersion: minVersionStr,
        updateUrl: updateUrl,
        updateMessageEn: updateMessageEn,
        updateMessageAr: updateMessageAr,
      );
    } catch (e) {
      // Network or parse error – fail open (don't block the user)
      return const UpdateCheckResult.noUpdate();
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  /// Parse a version string like "1.2.3" into a list of ints [1, 2, 3].
  List<int> _parseVersion(String version) {
    // Strip build metadata / pre-release (e.g. "1.0.10+62" → "1.0.10")
    final clean = version.split('+').first.split('-').first.trim();
    return clean.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  }

  /// Compare two version lists.
  /// Returns negative if a < b, 0 if equal, positive if a > b.
  int _compareVersions(List<int> a, List<int> b) {
    final length = a.length > b.length ? a.length : b.length;
    for (int i = 0; i < length; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av - bv;
    }
    return 0;
  }
}
