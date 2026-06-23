import 'package:dio/dio.dart';
import 'package:el_race/utils/uaepass_logger.dart';
import 'package:flutter/foundation.dart';

class _UaepassLoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      UaepassLogger.log('────────────────────────────────────────');
      UaepassLogger.log('API REQUEST');
      UaepassLogger.logKV('Method', options.method);
      UaepassLogger.logKV('URL', '${options.baseUrl}${options.path}');
      if (options.queryParameters.isNotEmpty) {
        UaepassLogger.log('Query Params (masked):');
        UaepassLogger.log(UaepassLogger.safeJsonEncode(options.queryParameters));
      }
      if (options.data != null && options.data is Map) {
        UaepassLogger.log('Request Body (masked):');
        UaepassLogger.log(UaepassLogger.safeJsonEncode(Map<String, dynamic>.from(options.data as Map)));
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      UaepassLogger.log('API RESPONSE');
      UaepassLogger.logKV('Status', response.statusCode);
      UaepassLogger.logKV('URL', response.requestOptions.uri.toString());
      if (response.data is Map) {
        UaepassLogger.log('Response Body (masked):');
        UaepassLogger.log(UaepassLogger.safeJsonEncode(Map<String, dynamic>.from(response.data as Map)));
      } else {
        UaepassLogger.logKV('Response', response.data?.toString()?.substring(0, 200));
      }
      UaepassLogger.log('────────────────────────────────────────');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      UaepassLogger.logError('API ERROR');
      UaepassLogger.logKV('URL', err.requestOptions.uri.toString());
      UaepassLogger.logKV('Status', err.response?.statusCode);
      UaepassLogger.logKV('Message', err.message);
      if (err.response?.data is Map) {
        UaepassLogger.log('Error Body (masked):');
        UaepassLogger.log(UaepassLogger.safeJsonEncode(Map<String, dynamic>.from(err.response!.data as Map)));
      }
      UaepassLogger.log('────────────────────────────────────────');
    }
    handler.next(err);
  }
}

class ApiClient {
  final Dio _dio;

  ApiClient({required String baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
          ),
        ) {
    if (kDebugMode) {
      _dio.interceptors.add(_UaepassLoggingInterceptor());
    }
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) {
    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: Options(headers: headers),
    );
  }

  Future<Response<dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? headers,
  }) {
    return _dio.post(
      path,
      data: data,
      options: Options(headers: headers),
    );
  }
}
