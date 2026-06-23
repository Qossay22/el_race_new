import 'package:dio/dio.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/models/global_search_item.dart';
import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/data/my_actions_repository.dart';
import 'package:flutter/foundation.dart';

/// Exception for global search API errors
class GlobalSearchApiException implements Exception {
  final String message;
  final int? statusCode;

  GlobalSearchApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      'GlobalSearchApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Service for global search across multiple categories
class GlobalSearchApiService {
  final Dio _dio;
  final String baseUrl;

  GlobalSearchApiService({
    Dio? dio,
    this.baseUrl = 'https://erp.elrace.com/api',
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              contentType: 'application/json',
              headers: {'Accept': 'application/json'},
            ));

  /// Perform global search
  ///
  /// [category]: One of petty_cash, projects, lpo, notes, documents, tasks
  /// [keyword]: Search keyword (minimum 2 characters recommended)
  /// [limit]: Maximum number of results (default: 10)
  Future<List<GlobalSearchItem>> globalSearch({
    required String category,
    required String keyword,
    int limit = 10,
  }) async {
    // Validate category
    const validCategories = [
      'petty_cash',
      'projects',
      'lpo',
      'notes',
      'documents',
      'tasks',
      'my_actions',
    ];

    if (!validCategories.contains(category)) {
      throw GlobalSearchApiException(
        'Invalid category: $category. Must be one of ${validCategories.join(", ")}',
      );
    }

    // Validate keyword
    if (keyword.trim().isEmpty) {
      return [];
    }

    // my_actions uses its own endpoint with keyword param
    if (category == 'my_actions') {
      return _searchMyActions(keyword: keyword.trim());
    }

    // LPO search works best through the dedicated endpoint (same as LPO screen).
    if (category == 'lpo') {
      return _searchLpos(keyword: keyword.trim(), limit: limit);
    }

    try {
      // Get authentication token
      final token = SharedPref.getLoginData().result?.token;
      if (token == null || token.isEmpty) {
        throw GlobalSearchApiException('Authentication token not found');
      }

      // Prepare request
      final url = '$baseUrl/global/search';
      final requestBody = {
        "jsonrpc": "2.0",
        "params": {
          "category": category,
          "keyword": keyword.trim(),
          "limit": limit,
        }
      };

      // Make API call
      final response = await _dio.post(
        url,
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      // Handle response
      if (response.statusCode == 200) {
        if (category == 'projects') {
          print('🔍 [GlobalSearch] Projects API response: ${response.data}');
        }
        return _parseResponse(response.data, category);
      } else {
        throw GlobalSearchApiException(
          'Search failed',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is GlobalSearchApiException) rethrow;
      throw GlobalSearchApiException('Unexpected error: ${e.toString()}');
    }
  }

  String _pickLpoVendor(Map<String, dynamic> item) {
    final partner = item['partner_id'];
    if (partner is List && partner.length > 1) {
      final value = partner[1]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    final direct = (item['partner_name'] ??
            item['vendor_name'] ??
            item['vendor'] ??
            item['supplier_name'] ??
            '')
        .toString()
        .trim();
    return direct;
  }

  Future<List<GlobalSearchItem>> _searchLpos({
    required String keyword,
    required int limit,
  }) async {
    try {
      final token = SharedPref.getLoginData().result?.token;
      if (token == null || token.isEmpty) {
        throw GlobalSearchApiException('Authentication token not found');
      }

      if (kDebugMode) {
        print(
          '🔍 [GlobalSearch][LPO] request keyword="$keyword" limit=$limit',
        );
      }

      final response = await _dio.post(
        '$baseUrl/get_lpos',
        data: {
          'jsonrpc': '2.0',
          'params': {
            'keyword': keyword,
            'page': 1,
            'limit': limit,
          }
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw GlobalSearchApiException(
          'LPO search failed',
          statusCode: response.statusCode,
        );
      }

      final payload = response.data;
      if (kDebugMode) {
        print(
          '🔍 [GlobalSearch][LPO] response status=${response.statusCode} payloadType=${payload.runtimeType}',
        );
        final raw = payload.toString();
        const chunkSize = 700;
        for (var i = 0; i < raw.length; i += chunkSize) {
          final end = (i + chunkSize < raw.length) ? i + chunkSize : raw.length;
          print('🔍 [GlobalSearch][LPO] raw[${i ~/ chunkSize}] ${raw.substring(i, end)}');
        }
      }
      if (payload is! Map<String, dynamic>) return const <GlobalSearchItem>[];

      final result = payload['result'];
      if (kDebugMode) {
        if (result is Map<String, dynamic>) {
          print('🔍 [GlobalSearch][LPO] result keys: ${result.keys.toList()}');
        } else {
          print('🔍 [GlobalSearch][LPO] result is not map: ${result.runtimeType}');
        }
      }
      if (result is! Map<String, dynamic>) return const <GlobalSearchItem>[];

      final rawItems = result['data'];
      if (kDebugMode) {
        print(
          '🔍 [GlobalSearch][LPO] data type=${rawItems.runtimeType} length=${rawItems is List ? rawItems.length : 'n/a'}',
        );
      }
      if (rawItems is! List) return const <GlobalSearchItem>[];

      final parsedItems = rawItems.whereType<Map>().map((raw) {
        final item = Map<String, dynamic>.from(raw);
        return GlobalSearchItem(
          id: int.tryParse(item['id']?.toString() ?? '') ?? 0,
          title: (item['name'] ?? item['lpo_name'] ?? 'LPO').toString(),
          subtitle: _pickLpoVendor(item),
          category: 'lpo',
          additionalData: item,
        );
      }).toList(growable: false);

      if (kDebugMode) {
        print('🔍 [GlobalSearch][LPO] parsed items count=${parsedItems.length}');
      }

      return parsedItems;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is GlobalSearchApiException) rethrow;
      throw GlobalSearchApiException('LPO search error: ${e.toString()}');
    }
  }

  /// Search my_actions via its own API with keyword
  Future<List<GlobalSearchItem>> _searchMyActions({required String keyword}) async {
    final repo = MyActionsRepository();
    final allResults = <GlobalSearchItem>[];

    // Search across all action types
    final types = [
      MyActionsType.hr,
      MyActionsType.rfq,
      MyActionsType.invoice,
      MyActionsType.ptsh,
    ];

    final futures = types.map((type) => repo.fetchByType(type, keyword: keyword).catchError((_) => <MyActionItem>[]));
    final results = await Future.wait(futures);

    for (final items in results) {
      for (final item in items) {
        allResults.add(GlobalSearchItem(
          id: item.id,
          title: item.name,
          subtitle: [
            if (item.employeeName.isNotEmpty) item.employeeName,
            if (item.status.isNotEmpty) item.status.toUpperCase(),
            if (item.vendor != null && item.vendor!.isNotEmpty) item.vendor!,
          ].join(' • '),
          category: 'my_actions',
          additionalData: {
            'reference': item.reference,
            'date': item.date,
            'project': item.project,
            'vendor': item.vendor,
            'amount_total': item.amountTotal,
            'request_type': item.requestType,
            'status': item.status,
            'employee_name': item.employeeName,
            'employee_image': item.employeeImage,
          },
        ));
      }
    }

    return allResults;
  }

  /// Parse API response
  List<GlobalSearchItem> _parseResponse(dynamic data, String category) {
    try {
      // Handle different response formats
      dynamic result;

      if (data is Map<String, dynamic>) {
        // Standard JSON-RPC response
        if (data.containsKey('result')) {
          result = data['result'];
        } else if (data.containsKey('data')) {
          result = data['data'];
        } else {
          result = data;
        }
      } else {
        result = data;
      }

      // Extract items list
      List<dynamic> items = [];
      if (result is List) {
        items = result;
      } else if (result is Map<String, dynamic>) {
        if (result.containsKey('data') && result['data'] is List) {
          items = result['data'] as List;
        } else if (result.containsKey('items') && result['items'] is List) {
          items = result['items'] as List;
        } else if (result.containsKey('results') && result['results'] is List) {
          items = result['results'] as List;
        }
      }

      // Parse items
      return items
          .where((item) => item is Map<String, dynamic>)
          .map((item) {
            try {
              return GlobalSearchItem.fromJson(
                item as Map<String, dynamic>,
                category,
              );
            } catch (e) {
              print('Error parsing search item: $e');
              return null;
            }
          })
          .whereType<GlobalSearchItem>()
          .toList();
    } catch (e) {
      print('Error parsing search response: $e');
      throw GlobalSearchApiException('Failed to parse search results');
    }
  }

  /// Handle Dio errors
  GlobalSearchApiException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return GlobalSearchApiException(
          'Connection timeout. Please check your internet connection.',
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final message = _extractErrorMessage(error.response?.data);

        if (statusCode == 401) {
          return GlobalSearchApiException(
            'Unauthorized. Please login again.',
            statusCode: statusCode,
          );
        } else if (statusCode == 404) {
          return GlobalSearchApiException(
            'Search endpoint not found.',
            statusCode: statusCode,
          );
        } else if (statusCode != null && statusCode >= 500) {
          return GlobalSearchApiException(
            'Server error. Please try again later.',
            statusCode: statusCode,
          );
        }

        return GlobalSearchApiException(
          message ?? 'Search failed',
          statusCode: statusCode,
        );

      case DioExceptionType.cancel:
        return GlobalSearchApiException('Search cancelled');

      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
      default:
        return GlobalSearchApiException(
          'Network error. Please check your internet connection.',
        );
    }
  }

  /// Extract error message from response
  String? _extractErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('error')) {
        final error = data['error'];
        if (error is Map<String, dynamic>) {
          return error['message'] ?? error['data']?['message'];
        } else if (error is String) {
          return error;
        }
      }
      if (data.containsKey('message')) {
        return data['message'];
      }
    }
    return null;
  }

  /// Cancel ongoing search requests
  void cancelRequests() {
    // Note: For proper cancellation, consider using CancelToken per request
    // This is a placeholder for basic cancellation logic
  }
}
