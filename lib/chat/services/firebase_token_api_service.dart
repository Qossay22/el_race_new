import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/shared_pref.dart';
import '../../utils/urll_utils.dart';
import '../models/firebase_refresh_token_response.dart';

/// Dedicated API service for Firebase token operations.
///
/// Handles calling `POST /api/firebase/refresh_token` to obtain a fresh
/// Firebase custom token using the backend JWT.
class FirebaseTokenApiService {
  static FirebaseTokenApiService? _instance;
  static FirebaseTokenApiService get instance =>
      _instance ??= FirebaseTokenApiService._();

  FirebaseTokenApiService._();

  Dio? _dio;

  /// Lazily initialise a [Dio] instance with persistent cookie support.
  Future<Dio> _getDio() async {
    if (_dio != null) return _dio!;

    final appDocDir = await getApplicationDocumentsDirectory();
    final cookieJar = PersistCookieJar(
      ignoreExpires: true,
      storage: FileStorage('${appDocDir.path}/.cookies/'),
    );

    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ))
      ..interceptors.add(CookieManager(cookieJar));

    return _dio!;
  }

  /// Call the refresh-token endpoint and return a typed response.
  ///
  /// [backendToken] – the backend JWT (Bearer token) used for authorisation.
  /// Returns `null` when the request fails at the network level.
  Future<FirebaseRefreshTokenResponse?> refreshToken({
    String? backendToken,
  }) async {
    try {
      // Resolve token: explicit param → SharedPref
      final token = backendToken ??
          SharedPref.getLoginData().result?.token ??
          '';

      if (token.isEmpty) {
        print('⚠️ FirebaseTokenApi: No backend token available');
        return null;
      }

      final url = '${UrlUtil.baseUrl}${UrlUtil.firebaseRefreshToken}';
      print('🔄 FirebaseTokenApi: POST $url');

      final dio = await _getDio();
      final response = await dio.post(
        url,
        data: jsonEncode({"jsonrpc": "2.0", "params": {}}),
        options: Options(headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.data is Map<String, dynamic>) {
        final parsed =
            FirebaseRefreshTokenResponse.fromJson(response.data);
        print('✅ FirebaseTokenApi: $parsed');
        return parsed;
      }

      // If the response came back as a JSON string, decode it first.
      if (response.data is String) {
        final decoded = jsonDecode(response.data as String);
        if (decoded is Map<String, dynamic>) {
          final parsed = FirebaseRefreshTokenResponse.fromJson(decoded);
          print('✅ FirebaseTokenApi: $parsed');
          return parsed;
        }
      }

      print('⚠️ FirebaseTokenApi: Unexpected response type: '
          '${response.data.runtimeType}');
      return null;
    } on DioException catch (e) {
      print('⚠️ FirebaseTokenApi: DioException ${e.response?.statusCode} – '
          '${e.message}');
      return null;
    } catch (e) {
      print('⚠️ FirebaseTokenApi: Error – $e');
      return null;
    }
  }

  /// Convenience: calls [refreshToken] and returns only the
  /// `firebase_custom_token` string (or `null`).
  Future<String?> fetchFreshFirebaseToken({String? backendToken}) async {
    final response = await refreshToken(backendToken: backendToken);
    return response?.firebaseCustomToken;
  }

  /// Refresh and persist the new token into the stored `loginResponse`.
  ///
  /// Returns the fresh token if successful, otherwise `null`.
  Future<String?> refreshAndPersist({String? backendToken}) async {
    final freshToken = await fetchFreshFirebaseToken(
      backendToken: backendToken,
    );
    if (freshToken == null) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('loginResponse');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;

        // Inject at result.data level (primary location)
        if (decoded['result']?['data'] is Map<String, dynamic>) {
          (decoded['result']['data']
              as Map<String, dynamic>)['firebase_custom_token'] = freshToken;
        }

        // Also inject at result level for consumers that look there
        if (decoded['result'] is Map<String, dynamic>) {
          (decoded['result']
              as Map<String, dynamic>)['firebase_custom_token'] = freshToken;
        }

        await prefs.setString('loginResponse', jsonEncode(decoded));
        print('✅ FirebaseTokenApi: Persisted fresh token to loginResponse');
      }
    } catch (e) {
      print('⚠️ FirebaseTokenApi: Could not persist token: $e');
    }

    return freshToken;
  }

  /// Reset the cached Dio instance (e.g. on logout).
  void dispose() {
    _dio?.close();
    _dio = null;
  }
}
