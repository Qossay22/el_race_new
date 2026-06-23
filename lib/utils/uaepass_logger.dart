import 'dart:convert';
import 'package:flutter/foundation.dart';

/// UAE PASS Debug Logger - Active only in debug/profile builds
class UaepassLogger {
  static const String _tag = '🔐 UAE PASS';
  static const List<String> _sensitiveKeys = [
    'token',
    'access_token',
    'id_token',
    'refresh_token',
    'secret',
    'client_secret',
    'password',
    'code',
    'authorization_code',
  ];

  /// Log only in debug mode
  static void log(String message, {String? tag}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final prefix = tag ?? _tag;
      // ignore: avoid_print
      print('[$timestamp] $prefix: $message');
    }
  }

  /// Log a section header
  static void logSection(String title) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('\n${'=' * 60}');
      // ignore: avoid_print
      print('$_tag $title');
      // ignore: avoid_print
      print('${'=' * 60}');
    }
  }

  /// Log key-value pair
  static void logKV(String key, dynamic value) {
    if (kDebugMode) {
      final safeValue = _isSensitiveKey(key) ? maskSensitive(value?.toString()) : value;
      // ignore: avoid_print
      print('$_tag   $key: $safeValue');
    }
  }

  /// Mask sensitive strings (first 6 + *** + last 4)
  static String maskSensitive(String? value) {
    if (value == null || value.isEmpty) return '<empty>';
    if (value.length <= 10) return '***MASKED***';
    return '${value.substring(0, 6)}***${value.substring(value.length - 4)}';
  }

  /// Check if a key is sensitive
  static bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    return _sensitiveKeys.any((k) => lower.contains(k));
  }

  /// Safe JSON print with masking
  static String safeJsonEncode(Map<String, dynamic>? map) {
    if (map == null) return '<null>';
    final masked = _maskMap(map);
    try {
      return const JsonEncoder.withIndent('  ').convert(masked);
    } catch (_) {
      return masked.toString();
    }
  }

  static Map<String, dynamic> _maskMap(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      if (_isSensitiveKey(entry.key)) {
        result[entry.key] = maskSensitive(entry.value?.toString());
      } else if (entry.value is Map) {
        result[entry.key] = _maskMap(Map<String, dynamic>.from(entry.value as Map));
      } else if (entry.value is List) {
        result[entry.key] = (entry.value as List).map((e) {
          if (e is Map) return _maskMap(Map<String, dynamic>.from(e));
          return e;
        }).toList();
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  /// Log URI parts
  static void logUri(String label, Uri uri) {
    if (kDebugMode) {
      log('$label:');
      logKV('Full URI', uri.toString());
      logKV('Scheme', uri.scheme);
      logKV('Host', uri.host);
      logKV('Path', uri.path);
      logKV('Query', uri.query);
      if (uri.queryParameters.isNotEmpty) {
        log('  Query Parameters:');
        for (final entry in uri.queryParameters.entries) {
          logKV('    ${entry.key}', entry.value);
        }
      }
    }
  }

  /// Log success
  static void logSuccess(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('$_tag ✅ $message');
    }
  }

  /// Log failure
  static void logError(String message, [Object? error]) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('$_tag ❌ $message');
      if (error != null) {
        // ignore: avoid_print
        print('$_tag   Error: $error');
      }
    }
  }

  /// Log warning
  static void logWarning(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('$_tag ⚠️ $message');
    }
  }
}
