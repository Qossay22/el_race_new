import 'package:dio/dio.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/models/announcement_model.dart';
import 'package:el_race/data/models/announcement_details_model.dart';

/// Category enum for announcements
enum AnnouncementCategory {
  news(1),
  announcements(2),
  circulars(3);

  final int id;
  const AnnouncementCategory(this.id);
}

/// Exception for announcement API errors
class AnnouncementApiException implements Exception {
  final String message;
  final int? statusCode;

  AnnouncementApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      'AnnouncementApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Service for fetching announcements, news, and circulars
class AnnouncementsApiService {
  final Dio _dio;
  final String baseUrl;

  AnnouncementsApiService({
    Dio? dio,
    this.baseUrl = 'https://erp.elrace.com/api',
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              contentType: 'application/json',
              headers: {'Accept': 'application/json'},
            ));

  /// Fetch announcements by category
  ///
  /// [category]: The announcement category (news, announcements, or circulars)
  /// Returns list of [AnnouncementModel]
  Future<List<AnnouncementModel>> fetchAnnouncements({
    required AnnouncementCategory category,
  }) async {
    try {
      // Get authentication token
      final token = SharedPref.getLoginData().result?.token;
      if (token == null || token.isEmpty) {
        throw AnnouncementApiException('Authentication token not found');
      }

      // Prepare request
      final url = '$baseUrl/announcements';
      final requestBody = {
        "jsonrpc": "2.0",
        "params": {
          "announcement_category_id": category.id,
        }
      };

      // print('📤 API Request to $url');
      // print('📋 Request body: $requestBody');
      // print('🔑 Token: ${token.substring(0, 20)}...');

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

      // print('📥 Response status: ${response.statusCode}');
      // print('📦 Response data: ${response.data}');

      // Handle response
      if (response.statusCode == 200) {
        return _parseResponse(response.data);
      } else {
        throw AnnouncementApiException(
          'Failed to fetch announcements',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw AnnouncementApiException('Connection timeout. Please try again.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw AnnouncementApiException(
          'Network error. Please check your connection.',
        );
      } else if (e.response != null) {
        final errorMessage = _extractErrorMessage(e.response?.data);
        throw AnnouncementApiException(
          errorMessage,
          statusCode: e.response?.statusCode,
        );
      } else {
        throw AnnouncementApiException(
            'An unexpected error occurred: ${e.message}');
      }
    } catch (e) {
      if (e is AnnouncementApiException) rethrow;
      throw AnnouncementApiException('Failed to fetch announcements: $e');
    }
  }

  /// Parse the API response into a list of AnnouncementModel
  List<AnnouncementModel> _parseResponse(dynamic responseData) {
    try {
      // Handle JSON-RPC response structure
      if (responseData is Map<String, dynamic>) {
        // Check for JSON-RPC error
        if (responseData.containsKey('error')) {
          final error = responseData['error'];
          final errorMessage = error is Map
              ? (error['message'] ??
                  error['data']?.toString() ??
                  'Unknown error')
              : error.toString();
          throw AnnouncementApiException(errorMessage);
        }

        // Extract result.data
        final result = responseData['result'];
        if (result == null) {
          return [];
        }

        final data = result is Map<String, dynamic> ? result['data'] : result;

        if (data == null) {
          return [];
        }

        // Parse array of announcements
        if (data is List) {
          return data
              .where((item) => item != null && item is Map<String, dynamic>)
              .map((item) =>
                  AnnouncementModel.fromJson(item as Map<String, dynamic>))
              .toList();
        } else if (data is Map<String, dynamic>) {
          // Single item
          return [AnnouncementModel.fromJson(data)];
        }
      }

      return [];
    } catch (e) {
      if (e is AnnouncementApiException) rethrow;
      throw AnnouncementApiException('Failed to parse response: $e');
    }
  }

  /// Extract error message from response data
  String _extractErrorMessage(dynamic data) {
    if (data == null) return 'Unknown error occurred';

    if (data is Map<String, dynamic>) {
      // Check for JSON-RPC error format
      if (data.containsKey('error')) {
        final error = data['error'];
        if (error is Map<String, dynamic>) {
          return error['message']?.toString() ??
              error['data']?.toString() ??
              'Unknown error';
        }
        return error.toString();
      }

      // Check for standard error fields
      if (data.containsKey('message')) {
        return data['message'].toString();
      }

      // Check for result.error
      if (data.containsKey('result') && data['result'] is Map) {
        final result = data['result'] as Map;
        if (result.containsKey('error')) {
          return result['error'].toString();
        }
      }
    }

    return 'Failed to fetch announcements';
  }

  /// Fetch announcement details by ID
  ///
  /// [announcementId]: The ID of the announcement to fetch
  /// Returns [AnnouncementDetailsModel]
  Future<AnnouncementDetailsModel> fetchAnnouncementDetails({
    required int announcementId,
  }) async {
    try {
      // Get authentication token
      final token = SharedPref.getLoginData().result?.token;
      if (token == null || token.isEmpty) {
        throw AnnouncementApiException('Authentication token not found');
      }

      // Prepare request
      final url = '$baseUrl/announcement_details';
      final requestBody = {
        "jsonrpc": "2.0",
        "params": {
          "announcement_id": announcementId,
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
        return _parseDetailsResponse(response.data);
      } else {
        throw AnnouncementApiException(
          'Failed to fetch announcement details',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw AnnouncementApiException('Connection timeout. Please try again.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw AnnouncementApiException(
          'Network error. Please check your connection.',
        );
      } else if (e.response != null) {
        final errorMessage = _extractErrorMessage(e.response?.data);
        throw AnnouncementApiException(
          errorMessage,
          statusCode: e.response?.statusCode,
        );
      } else {
        throw AnnouncementApiException(
            'An unexpected error occurred: ${e.message}');
      }
    } catch (e) {
      if (e is AnnouncementApiException) rethrow;
      throw AnnouncementApiException(
          'Failed to fetch announcement details: $e');
    }
  }

  /// Parse the API response into AnnouncementDetailsModel
  AnnouncementDetailsModel _parseDetailsResponse(dynamic responseData) {
    try {
      // Handle JSON-RPC response structure
      if (responseData is Map<String, dynamic>) {
        // Check for JSON-RPC error
        if (responseData.containsKey('error')) {
          final error = responseData['error'];
          final errorMessage = error is Map
              ? (error['message'] ??
                  error['data']?.toString() ??
                  'Unknown error')
              : error.toString();
          throw AnnouncementApiException(errorMessage);
        }

        // Extract result.data
        final result = responseData['result'];
        if (result == null) {
          throw AnnouncementApiException('No result in response');
        }

        final data = result is Map<String, dynamic> ? result['data'] : result;

        if (data == null) {
          throw AnnouncementApiException('No data in response');
        }

        // Parse announcement details
        if (data is Map<String, dynamic>) {
          return AnnouncementDetailsModel.fromJson(data);
        }
      }

      throw AnnouncementApiException('Invalid response format');
    } catch (e) {
      if (e is AnnouncementApiException) rethrow;
      throw AnnouncementApiException('Failed to parse details response: $e');
    }
  }
}
