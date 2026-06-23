import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/utils/api_query.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MyActionsRepository {
  static const int defaultPerPage = 10;

  static const List<String> _backendDateKeys = [
    'last_updated_on',
    'updated_at',
    'write_date',
    'create_date',
    'accounting_date',
    'date',
    'request_date',
    'invoice_date',
  ];

  final ApiQuery _apiQuery;

  MyActionsRepository({ApiQuery? apiQuery})
      : _apiQuery = apiQuery ?? ApiQuery();

  void _debugPrintBackendDates({
    required String source,
    String? typeLabel,
    int? page,
    required List<Map<String, dynamic>> items,
  }) {
    final typePart = typeLabel == null ? '' : ' type=$typeLabel';
    final pagePart = page == null ? '' : ' page=$page';
    debugPrint(
      '📅 [MyActions][$source]$typePart$pagePart items=${items.length}',
    );

    for (var i = 0; i < items.length; i++) {
      final raw = items[i];
      final id = raw['id'] ?? raw['parent_id'] ?? '?';
      final dateParts = <String>[];

      for (final key in _backendDateKeys) {
        if (!raw.containsKey(key)) continue;
        final value = raw[key];
        if (value == null || value == false) continue;
        dateParts.add('$key=$value');
      }

      for (final key in raw.keys) {
        final keyText = key.toString().toLowerCase();
        if (!keyText.contains('date') && !keyText.contains('updated')) continue;
        if (_backendDateKeys.contains(key.toString())) continue;
        final value = raw[key];
        if (value == null || value == false) continue;
        dateParts.add('$key=$value');
      }

      if (dateParts.isEmpty) {
        debugPrint('   [$i] id=$id backend_dates: (none)');
      } else {
        debugPrint('   [$i] id=$id backend_dates: ${dateParts.join(' | ')}');
      }
    }
  }

  void _printLongDebugString(String text) {
    const chunkSize = 800;
    for (var i = 0; i < text.length; i += chunkSize) {
      final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      debugPrint(text.substring(i, end));
    }
  }

  void _debugPrintFullInvoiceResponse({
    required int page,
    required Map<String, dynamic> json,
  }) {
    if (!kDebugMode) return;

    try {
      final encoded = const JsonEncoder.withIndent('  ').convert(json);
      debugPrint('📦 [MyActions][invoice] FULL RESPONSE page=$page');
      _printLongDebugString(encoded);
      debugPrint('📦 [MyActions][invoice] END FULL RESPONSE page=$page');
    } catch (e) {
      debugPrint(
        '📦 [MyActions][invoice] FULL RESPONSE page=$page (encode failed: $e)',
      );
      _printLongDebugString(json.toString());
      debugPrint('📦 [MyActions][invoice] END FULL RESPONSE page=$page');
    }
  }

  void _debugPrintParsedDates({
    String? typeLabel,
    required List<MyActionItem> items,
  }) {
    final typePart = typeLabel == null ? '' : ' type=$typeLabel';
    debugPrint('📅 [MyActions][parsed]$typePart items=${items.length}');
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      debugPrint(
        '   [$i] id=${item.id} '
        'date="${item.date}" '
        'originalDate="${item.originalDate}"',
      );
    }
  }

  List<MyActionItem> _toActionItems(
    List<dynamic> rawList, {
    required String source,
    MyActionsType? type,
    int? page,
  }) {
    final maps = rawList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);

    _debugPrintBackendDates(
      source: source,
      typeLabel: type?.apiValue,
      page: page,
      items: maps,
    );

    final items = maps.map(MyActionItem.fromJson).toList(growable: false);
    _debugPrintParsedDates(typeLabel: type?.apiValue, items: items);
    return items;
  }

  Future<List<MyActionItem>> fetchByType(
    MyActionsType type, {
    int page = 1,
    int perPage = defaultPerPage,
    String keyword = '',
  }) async {
    final token = SharedPref.getLoginDataOrNull()?.result?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Invalid token');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final Map<String, dynamic> params = {
      'type': type.apiValue,
      'page': page,
      'per_page': perPage,
    };
    if (keyword.trim().isNotEmpty) {
      params['keyword'] = keyword.trim();
    }

    final body = {
      'jsonrpc': '2.0',
      'params': params,
    };

    final Response? response = await _apiQuery.postQuery(
      UrlUtil.myActionsApi,
      headers,
      body,
      'my_actions_${type.apiValue}',
      true,
    );

    if (response == null) {
      throw Exception('No response from server');
    }

    if (response.statusCode != 200) {
      throw Exception('My actions HTTP ${response.statusCode}');
    }

    final dynamic payload = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;

    if (payload is! Map) {
      throw Exception(
          'Unexpected my_actions payload type: ${payload.runtimeType}');
    }

    final Map<String, dynamic> json = Map<String, dynamic>.from(payload);

    if (type.apiValue == MyActionsType.invoice.apiValue) {
      _debugPrintFullInvoiceResponse(page: page, json: json);
    }

    // Handle JSON-RPC error envelope from Odoo
    if (json.containsKey('error') && json['error'] is Map) {
      final err = Map<String, dynamic>.from(json['error'] as Map);
      // Odoo nests the real message inside error.data.message
      final errData = err['data'];
      String message;
      if (errData is Map) {
        message = errData['message']?.toString() ??
            errData['name']?.toString() ??
            err['message']?.toString() ??
            'Odoo Server Error';
      } else {
        message = err['message']?.toString() ?? 'Odoo Server Error';
      }
      throw Exception(message);
    }

    final result = json['result'];

    // result might be the list/data directly (no wrapping map)
    if (result is List) {
      return _toActionItems(
        result,
        source: 'my_actions',
        type: type,
        page: page,
      );
    }

    if (result is! Map) {
      return const <MyActionItem>[];
    }

    final status = result['status']?.toString();
    if (status != null && status != 'success') {
      final message = result['message']?.toString() ?? 'Unknown error';
      throw Exception(message);
    }

    // Try the expected nested structure first: result.data.<key>
    final data = result['data'];
    if (data is Map) {
      final list = data[type.responseKey];
      if (list is List) {
        return _toActionItems(
          list,
          source: 'my_actions',
          type: type,
          page: page,
        );
      }
    }

    // Fallback: result.<key> directly (flat response)
    final directList = result[type.responseKey];
    if (directList is List) {
      return _toActionItems(
        directList,
        source: 'my_actions',
        type: type,
        page: page,
      );
    }

    // Fallback: result.data is a list
    if (data is List) {
      return _toActionItems(
        data,
        source: 'my_actions',
        type: type,
        page: page,
      );
    }

    // Fallback: result.records (some Odoo endpoints)
    final records = result['records'];
    if (records is List) {
      return _toActionItems(
        records,
        source: 'my_actions',
        type: type,
        page: page,
      );
    }

    return const <MyActionItem>[];
  }

  Future<List<MyActionItem>> fetchMyRequests({String keyword = ''}) async {
    final login = SharedPref.getLoginDataOrNull();
    final token = login?.result?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Invalid token');
    }

    final loginData = login?.result?.data;
    final loginEmployeeName = (loginData?.emp_name?.trim().isNotEmpty == true)
        ? loginData!.emp_name!.trim()
        : (loginData?.name?.trim().isNotEmpty == true)
            ? loginData!.name!.trim()
            : (loginData?.username ?? '').trim();
    final loginEmployeeImage = loginData?.image_url ?? '';
    final loginFileId = (loginData?.emp_profile_id?.trim().isNotEmpty == true)
        ? loginData!.emp_profile_id!.trim()
        : (loginData?.employee_id?.toString() ?? loginData?.emp_id ?? '');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {
        'keyword': keyword,
      },
    });

    final url = Uri.parse('${UrlUtil.baseUrl}my_requests');
    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('My requests HTTP ${response.statusCode}');
    }

    final dynamic payload =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);

    if (payload is! Map) {
      throw Exception(
          'Unexpected my_requests payload type: ${payload.runtimeType}');
    }

    final json = Map<String, dynamic>.from(payload);
    final result = json['result'];

    List<dynamic> items = const [];
    if (result is Map && result['data'] is List) {
      items = List<dynamic>.from(result['data'] as List);
    } else if (result is List) {
      items = List<dynamic>.from(result);
    }

    final maps = items.whereType<Map>().map((rawItem) {
      final map = Map<String, dynamic>.from(rawItem);
      map['employee_name'] =
          (map['employee_name']?.toString().trim().isNotEmpty == true)
              ? map['employee_name']
              : loginEmployeeName;
      map['employee_image'] =
          (map['employee_image']?.toString().trim().isNotEmpty == true)
              ? map['employee_image']
              : loginEmployeeImage;
      map['file_id'] = (map['file_id']?.toString().trim().isNotEmpty == true)
          ? map['file_id']
          : loginFileId;
      return map;
    }).toList(growable: false);

    _debugPrintBackendDates(
      source: 'my_requests',
      items: maps,
    );

    return maps.map(MyActionItem.fromJson).toList(growable: false);
  }
}
