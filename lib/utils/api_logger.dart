import 'dart:convert';
import 'dart:developer' as developer;

/// Utility class for logging API requests and responses
class ApiLogger {
  static const bool _isEnabled = true;

  /// Log API Request
  static void logRequest({
    required String endpoint,
    required String method,
    Map<String, dynamic>? headers,
    dynamic body,
  }) {
    if (!_isEnabled) return;

    final log = StringBuffer();
    log.writeln('');
    log.writeln('╔═══════════════════════════════════════════════════════════');
    log.writeln('║ 📤 API REQUEST');
    log.writeln('╠═══════════════════════════════════════════════════════════');
    log.writeln('║ Method: $method');
    log.writeln('║ Endpoint: $endpoint');

    if (headers != null && headers.isNotEmpty) {
      log.writeln(
          '╠───────────────────────────────────────────────────────────');
      log.writeln('║ Headers:');
      headers.forEach((key, value) {
        // Print full authorization token
        log.writeln('║   $key: $value');
      });
    }

    if (body != null) {
      log.writeln(
          '╠───────────────────────────────────────────────────────────');
      log.writeln('║ Body:');
      try {
        final bodyStr = body is String ? body : jsonEncode(body);
        final prettyJson = _formatJson(bodyStr);
        prettyJson.split('\n').forEach((line) {
          log.writeln('║   $line');
        });
      } catch (e) {
        log.writeln('║   $body');
      }
    }

    log.writeln('╚═══════════════════════════════════════════════════════════');

    developer.log(log.toString(), name: 'API');
    print(log.toString());
  }

  /// Log API Response
  static void logResponse({
    required String endpoint,
    required int statusCode,
    dynamic responseBody,
    Duration? duration,
  }) {
    if (!_isEnabled) return;

    final log = StringBuffer();
    log.writeln('');
    log.writeln('╔═══════════════════════════════════════════════════════════');
    log.writeln('║ 📥 API RESPONSE');
    log.writeln('╠═══════════════════════════════════════════════════════════');
    log.writeln('║ Endpoint: $endpoint');
    log.writeln('║ Status Code: $statusCode ${_getStatusEmoji(statusCode)}');

    if (duration != null) {
      log.writeln('║ Duration: ${duration.inMilliseconds}ms');
    }

    log.writeln('╠───────────────────────────────────────────────────────────');
    log.writeln('║ Response Body:');

    try {
      final bodyStr =
          responseBody is String ? responseBody : jsonEncode(responseBody);
      final prettyJson = _formatJson(bodyStr);
      prettyJson.split('\n').forEach((line) {
        log.writeln('║   $line');
      });
    } catch (e) {
      log.writeln('║   $responseBody');
    }

    log.writeln('╚═══════════════════════════════════════════════════════════');

    developer.log(log.toString(), name: 'API');
    print(log.toString());
  }

  /// Log API Error
  static void logError({
    required String endpoint,
    required dynamic error,
    StackTrace? stackTrace,
  }) {
    if (!_isEnabled) return;

    final log = StringBuffer();
    log.writeln('');
    log.writeln('╔═══════════════════════════════════════════════════════════');
    log.writeln('║ ❌ API ERROR');
    log.writeln('╠═══════════════════════════════════════════════════════════');
    log.writeln('║ Endpoint: $endpoint');
    log.writeln('║ Error: $error');

    if (stackTrace != null) {
      log.writeln(
          '╠───────────────────────────────────────────────────────────');
      log.writeln('║ Stack Trace:');
      stackTrace.toString().split('\n').take(5).forEach((line) {
        log.writeln('║   $line');
      });
    }

    log.writeln('╚═══════════════════════════════════════════════════════════');

    developer.log(log.toString(),
        name: 'API', error: error, stackTrace: stackTrace);
    print(log.toString());
  }

  /// Format JSON string with indentation
  static String _formatJson(String jsonString) {
    try {
      final dynamic jsonObj = jsonDecode(jsonString);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(jsonObj);
    } catch (e) {
      return jsonString;
    }
  }

  /// Get emoji for status code
  static String _getStatusEmoji(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return '✅';
    } else if (statusCode >= 300 && statusCode < 400) {
      return '↪️';
    } else if (statusCode >= 400 && statusCode < 500) {
      return '⚠️';
    } else if (statusCode >= 500) {
      return '🔥';
    }
    return '❓';
  }

  /// Log simple message
  static void log(String message) {
    if (!_isEnabled) return;
    developer.log(message, name: 'API');
    print('🔹 $message');
  }
}
