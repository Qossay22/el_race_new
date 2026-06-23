import 'dart:convert';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/Email%20Approval/delayed/models/delayed_approval_model.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DelayedAllPageResult {
  final DelayedApprovalsResponse data;
  final int currentPage;
  final int? nextPage;
  final bool hasMore;

  const DelayedAllPageResult({
    required this.data,
    required this.currentPage,
    required this.nextPage,
    required this.hasMore,
  });
}

class DelayedApprovalsRepository {
  static const String _baseUrl = 'https://erp.elrace.com/api';

  void _debugPrintRawResponse(String label, String raw) {
    if (!kDebugMode) return;
    debugPrint('🟣 [$label] Raw response start');
    const chunkSize = 800;
    for (var i = 0; i < raw.length; i += chunkSize) {
      final end = (i + chunkSize < raw.length) ? i + chunkSize : raw.length;
      debugPrint(raw.substring(i, end));
    }
    debugPrint('🟣 [$label] Raw response end');
  }

  Map<String, String> _buildHeaders(String token) => {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      };

  String _requireToken() {
    final token = SharedPref.getLoginData().result?.token;
    if (token == null || token.isEmpty)
      throw Exception('User not authenticated');
    return token;
  }

  // ─────────────────────────────────────────────────────────────
  // 1. COUNTERS  →  /api/my_delayed_approvals/counters
  //    Very fast – use for dashboard badge and tab counts.
  // ─────────────────────────────────────────────────────────────
  Future<DelayedCountersResponse> fetchCounters() async {
    final token = _requireToken();
    final url = Uri.parse('$_baseUrl/my_delayed_approvals/counters');

    final body = jsonEncode({"jsonrpc": "2.0", "params": {}});

    try {
      final request = http.Request('GET', url)
        ..headers.addAll(_buildHeaders(token))
        ..body = body;

      final response = await http.Response.fromStream(await request.send());

      if (kDebugMode) {
        debugPrint(
            'DELAYED COUNTERS status=${response.statusCode} bytes=${response.body.length}');
        _debugPrintRawResponse('DELAYED COUNTERS', response.body);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DelayedCountersResponse.fromJson(data);
      } else {
        throw Exception(
            'Failed to fetch delayed counters: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching delayed counters: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 2. DETAILS  →  /api/my_delayed_approvals/details?type=hr|rfq|invoice|petty_cash
  //    Load on user tap – returns records for the selected category only.
  // ─────────────────────────────────────────────────────────────
  Future<DelayedDetailsResponse> fetchDetails(String type) async {
    final token = _requireToken();
    final url = Uri.parse('$_baseUrl/my_delayed_approvals/details')
        .replace(queryParameters: {'type': type});

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": {"type": type},
    });

    try {
      final request = http.Request('GET', url)
        ..headers.addAll(_buildHeaders(token))
        ..body = body;

      final response = await http.Response.fromStream(await request.send());

      if (kDebugMode) {
        debugPrint(
            'DELAYED DETAILS($type) status=${response.statusCode} bytes=${response.body.length}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DelayedDetailsResponse.fromJson(data, type);
      } else {
        throw Exception(
            'Failed to fetch delayed details for $type: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching delayed details for $type: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 2.5 ROR  →  /api/my_delayed_approvals/ror
  //    Returns response-rate values used in the approval overview ROR card.
  // ─────────────────────────────────────────────────────────────
  Future<DelayedRorResponse> fetchRor() async {
    final token = _requireToken();
    final url = Uri.parse('$_baseUrl/my_delayed_approvals/ror');

    final body = jsonEncode({"jsonrpc": "2.0", "params": {}});

    try {
      http.Response response = await _sendRorRequest(
        method: 'GET',
        url: url,
        token: token,
        body: body,
      );

      if (response.statusCode == 405) {
        if (kDebugMode) {
          debugPrint('🟣 [DELAYED ROR] GET returned 405, retrying with POST');
        }
        response = await _sendRorRequest(
          method: 'POST',
          url: url,
          token: token,
          body: body,
        );
      }

      if (kDebugMode) {
        debugPrint(
            'DELAYED ROR status=${response.statusCode} bytes=${response.body.length}');
        debugPrint('🟣 [DELAYED ROR] Raw response start');
        const chunkSize = 800;
        final raw = response.body;
        for (var i = 0; i < raw.length; i += chunkSize) {
          final end = (i + chunkSize < raw.length) ? i + chunkSize : raw.length;
          debugPrint(raw.substring(i, end));
        }
        debugPrint('🟣 [DELAYED ROR] Raw response end');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final parsed = DelayedRorResponse.fromJson(data);
        final directRor = _extractDirectRorPercentage(data);
        final effectiveRor = directRor ?? parsed.rorPercentage;
        final normalized = DelayedRorResponse(
          hrCount: parsed.hrCount,
          rfqCount: parsed.rfqCount,
          invoiceCount: parsed.invoiceCount,
          pettyCashCount: parsed.pettyCashCount,
          rorPercentage: effectiveRor,
          hrRor: parsed.hrRor,
          rfqRor: parsed.rfqRor,
          invoiceRor: parsed.invoiceRor,
          pettyCashRor: parsed.pettyCashRor,
        );
        if (kDebugMode) {
          debugPrint(
            '🟣 [DELAYED ROR] Parsed => ror=${normalized.rorPercentage}% (direct=${directRor ?? 'n/a'})'
            ' | hrRor=${normalized.hrRor}%, rfqRor=${normalized.rfqRor}%, invoiceRor=${normalized.invoiceRor}%, pettyCashRor=${normalized.pettyCashRor}%'
            ' | hrCount=${normalized.hrCount}, rfqCount=${normalized.rfqCount}, invoiceCount=${normalized.invoiceCount}, pettyCashCount=${normalized.pettyCashCount}',
          );
        }
        return normalized;
      } else {
        throw Exception('Failed to fetch delayed ROR: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching delayed ROR: $e');
    }
  }

  Future<http.Response> _sendRorRequest({
    required String method,
    required Uri url,
    required String token,
    required String body,
  }) async {
    final request = http.Request(method, url)
      ..headers.addAll(_buildHeaders(token))
      ..body = body;

    final response = await http.Response.fromStream(await request.send());

    if (kDebugMode) {
      debugPrint(
          '🟣 [DELAYED ROR] method=$method status=${response.statusCode} bytes=${response.body.length}');
    }

    return response;
  }

  int? _extractDirectRorPercentage(dynamic decoded) {
    if (decoded is! Map) return null;
    final result = decoded['result'];
    if (result is! Map) return null;
    final data = result['data'];
    if (data is! Map) return null;

    final rorField = data['ror'] ??
        data['ror_percentage'] ??
        data['response_rate'] ??
        data['percentage'];

    if (rorField == null) return null;

    // New shape: data.ror is a map {overall, hr, rfq, invoice, petty_cash}
    if (rorField is Map) {
      final overall = rorField['overall'];
      return _decimalToPercent(overall);
    }

    return _decimalToPercent(rorField);
  }

  /// Converts a value to an integer percentage.
  /// Treats values <= 1.5 as decimals (0.26 → 26), otherwise as already-percent.
  int? _decimalToPercent(dynamic raw) {
    if (raw == null) return null;
    double? value;
    if (raw is num) {
      value = raw.toDouble();
    } else if (raw is String) {
      value = double.tryParse(raw.trim().replaceAll('%', ''));
    }
    if (value == null) return null;
    // If value looks like a decimal ratio (e.g. 0.26), multiply by 100
    if (value <= 1.5) value = value * 100;
    return value.round().clamp(0, 9999);
  }

  // ─────────────────────────────────────────────────────────────
  // 3. ALL  →  /api/my_delayed_approvals/all
  //    Supports pagination via limit/offset in params body.
  // ─────────────────────────────────────────────────────────────
  Future<DelayedApprovalsResponse> fetchAll({
    int? limit,
    int? offset,
  }) async {
    final token = _requireToken();

    final queryParams = <String, String>{};
    if (limit != null) queryParams['limit'] = '$limit';
    if (offset != null) queryParams['offset'] = '$offset';

    final url = Uri.parse('$_baseUrl/my_delayed_approvals/all')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final params = <String, dynamic>{};
    if (limit != null) params['limit'] = limit;
    if (offset != null) params['offset'] = offset;

    final body = jsonEncode({"jsonrpc": "2.0", "params": params});

    try {
      final request = http.Request('GET', url)
        ..headers.addAll(_buildHeaders(token))
        ..body = body;

      final response = await http.Response.fromStream(await request.send());

      if (kDebugMode) {
        debugPrint(
            'DELAYED ALL status=${response.statusCode} limit=$limit offset=$offset bytes=${response.body.length}');
        _debugPrintRawResponse('DELAYED ALL', response.body);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DelayedApprovalsResponse.fromJson(data);
      } else {
        throw Exception(
            'Failed to fetch all delayed approvals: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching all delayed approvals: $e');
    }
  }

  /// Paginated fetch from /api/my_delayed_approvals/all.
  ///
  /// Sends common pagination keys in both query params and request body to
  /// match backend variants without breaking existing behavior.
  Future<DelayedAllPageResult> fetchAllPage({
    required int page,
    int pageSize = 10,
  }) async {
    final token = _requireToken();
    final url = Uri.parse('$_baseUrl/my_delayed_approvals/all').replace(
      queryParameters: {
        'page': '$page',
        'limit': '$pageSize',
        'per_page': '$pageSize',
      },
    );

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": {
        "page": page,
        "limit": pageSize,
        "per_page": pageSize,
        "page_size": pageSize,
      }
    });

    try {
      final request = http.Request('GET', url)
        ..headers.addAll(_buildHeaders(token))
        ..body = body;

      final response = await http.Response.fromStream(await request.send());

      if (kDebugMode) {
        debugPrint(
            'DELAYED ALL PAGED status=${response.statusCode} page=$page pageSize=$pageSize bytes=${response.body.length}');
        _debugPrintRawResponse('DELAYED ALL PAGED', response.body);
      }

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to fetch delayed approvals page $page: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final parsed = DelayedApprovalsResponse.fromJson(json);

      final result = json['result'];
      final resultMap =
          result is Map<String, dynamic> ? result : <String, dynamic>{};
      final meta = _extractPaginationMeta(resultMap);

      final currentPage =
          _readInt(meta, const ['current_page', 'page'], fallback: page);
      final totalPages = _readInt(meta, const ['total_pages', 'last_page']);
      final explicitNextPage = _readNullableInt(meta, const ['next_page']);
      final explicitHasMore = _readBool(meta, const ['has_more', 'has_next']);

      final bool hasMore;
      if (explicitHasMore != null) {
        hasMore = explicitHasMore;
      } else if (explicitNextPage != null) {
        hasMore = explicitNextPage > currentPage;
      } else if (totalPages > 0) {
        hasMore = currentPage < totalPages;
      } else {
        // Fallback when metadata is missing.
        hasMore = parsed.totalCount >= pageSize;
      }

      final nextPage = explicitNextPage ?? (hasMore ? currentPage + 1 : null);

      return DelayedAllPageResult(
        data: parsed,
        currentPage: currentPage,
        nextPage: nextPage,
        hasMore: hasMore,
      );
    } catch (e) {
      throw Exception('Error fetching delayed approvals page $page: $e');
    }
  }

  Map<String, dynamic> _extractPaginationMeta(Map<String, dynamic> resultMap) {
    final directMeta = resultMap['pagination'];
    if (directMeta is Map<String, dynamic>) return directMeta;

    final directMeta2 = resultMap['meta'];
    if (directMeta2 is Map<String, dynamic>) return directMeta2;

    final data = resultMap['data'];
    if (data is Map<String, dynamic>) {
      final nestedPagination = data['pagination'];
      if (nestedPagination is Map<String, dynamic>) return nestedPagination;

      final nestedMeta = data['meta'];
      if (nestedMeta is Map<String, dynamic>) return nestedMeta;

      return data;
    }

    return resultMap;
  }

  int _readInt(Map<String, dynamic> source, List<String> keys,
      {int fallback = 0}) {
    final value = _readNullableInt(source, keys);
    return value ?? fallback;
  }

  int? _readNullableInt(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  bool? _readBool(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // Legacy method – kept for backward compatibility.
  // Calls the old single endpoint (now maps to /all).
  // ─────────────────────────────────────────────────────────────
  @Deprecated(
      'Use fetchCounters() for dashboard and fetchDetails(type) on tap.')
  Future<DelayedApprovalsResponse> fetchDelayedApprovals() => fetchAll();
}
