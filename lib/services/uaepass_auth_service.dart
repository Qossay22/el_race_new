import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:el_race/chat/chat.dart';
import 'package:el_race/config/uaepass_config.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/hive_service.dart';
import 'package:el_race/firebase_service.dart';
import 'package:el_race/services/api_client.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/utils/string_utils.dart';
import 'package:el_race/utils/uaepass_logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

enum AuthFailureType { existingOnly, unverified, generic, cancelled }

class UaepassAuthResult {
  final bool isSuccess;
  final LoginResponseModel? loginResponse;
  final AuthFailureType? failureType;
  final String? backendErrorCode;

  const UaepassAuthResult.success(this.loginResponse)
      : isSuccess = true,
        failureType = null,
        backendErrorCode = null;

  const UaepassAuthResult.failure(this.failureType, {this.backendErrorCode})
      : isSuccess = false,
        loginResponse = null;
}

class UaepassAuthService {
  static const _stateKey = 'uaepass_state';
  static const _sessionKey = 'uaepass_session';
  static const _txKey = 'uaepass_tx';

  final UaepassConfig config;
  final ApiClient apiClient;
  final FlutterSecureStorage secureStorage;
  final Uuid _uuid;

  String? _pendingState;

  UaepassAuthService({
    required this.config,
    required this.apiClient,
    required this.secureStorage,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  Future<void> startLogin() async {
    UaepassLogger.logSection('UAE PASS LOGIN START');
    UaepassLogger.logKV('Environment', 'STAGING');
    UaepassLogger.logKV('Timestamp', DateTime.now().toIso8601String());
    UaepassLogger.logKV('client_id', config.clientId);
    UaepassLogger.logKV('redirect_uri (raw)', config.redirectUrl);
    UaepassLogger.logKV('redirect_uri (encoded)', Uri.encodeComponent(config.redirectUrl));
    UaepassLogger.logKV('scope (raw)', config.scope);
    UaepassLogger.logKV('scope (encoded)', Uri.encodeComponent(config.scope));
    UaepassLogger.logKV('response_type', config.responseType);
    UaepassLogger.logKV('acr_values (raw)', config.acrValues);
    UaepassLogger.logKV('acr_values (encoded)', Uri.encodeComponent(config.acrValues));

    final state = _uuid.v4();
    _pendingState = state;
    await secureStorage.write(key: _stateKey, value: state);
    UaepassLogger.logKV('state', state);
    UaepassLogger.logKV('state stored in', 'memory + secure_storage');

    final authUrl = config.buildAuthorizationUrl(state);
    UaepassLogger.log('Authorization URL (with acr_values):');
    UaepassLogger.logKV('Full URL', authUrl.toString());

    UaepassLogger.log('Opening system browser for UAE PASS');
    UaepassLogger.logKV('LaunchMode', 'externalApplication (Custom Tabs / Safari)');

    try {
      final launched = await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        UaepassLogger.logError('Failed to open browser - launchUrl returned false');
        throw Exception('Unable to open UAE PASS');
      }
      UaepassLogger.logSuccess('Browser opened successfully');
    } catch (e) {
      UaepassLogger.logError('Exception opening browser', e);
      rethrow;
    }
  }

  Future<UaepassAuthResult> handleCallbackOrResult(Uri uri) async {
    UaepassLogger.logSection('DEEPLINK RECEIVED');
    UaepassLogger.logUri('Incoming URI', uri);

    if (_isCancelled(uri)) {
      UaepassLogger.logWarning('User cancelled or declined');
      UaepassLogger.logError('UAEPASS LOGIN FAILED', 'User cancel');
      return const UaepassAuthResult.failure(AuthFailureType.cancelled);
    }

    final storedState = await secureStorage.read(key: _stateKey);
    final incomingState = uri.queryParameters['state'];
    UaepassLogger.logKV('Stored state', storedState);
    UaepassLogger.logKV('Incoming state', incomingState);

    if (incomingState != null && storedState != null) {
      if (incomingState != storedState) {
        UaepassLogger.logError('State mismatch - possible CSRF attack');
        UaepassLogger.logError('UAEPASS LOGIN FAILED', 'Invalid state');
        return const UaepassAuthResult.failure(AuthFailureType.generic);
      }
      UaepassLogger.logSuccess('State validation passed');
    }

    if (config.useBackendRedirectDeepLink) {
      final session = uri.queryParameters['session'];
      final tx = uri.queryParameters['tx'] ?? uri.queryParameters['transaction'];
      final errorParam = uri.queryParameters['error'];
      final errorCode = uri.queryParameters['error_code'] ?? uri.queryParameters['code'];

      UaepassLogger.logKV('session param', session ?? '<not present>');
      UaepassLogger.logKV('tx param', tx ?? '<not present>');
      UaepassLogger.logKV('error param', errorParam ?? '<not present>');
      UaepassLogger.logKV('error_code param', errorCode ?? '<not present>');

      // Handle error deep links first (e.g. elrace://uaepass/error?code=GENERIC)
      // Check before session/tx so error responses are properly caught.
      if (config.isErrorLink(uri)) {
        final deepLinkErrorCode = errorCode ?? errorParam ?? 'GENERIC';
        UaepassLogger.logWarning('Error deep link received: $deepLinkErrorCode');
        final failureType = mapBackendErrorToFailureType(
          errorCode: deepLinkErrorCode,
        );
        UaepassLogger.logError('UAEPASS LOGIN FAILED', 'Error deep link: $deepLinkErrorCode');
        UaepassLogger.logKV('Mapped failure type', _failureTypeToString(failureType));
        return UaepassAuthResult.failure(failureType, backendErrorCode: deepLinkErrorCode);
      }

      if (session != null && session.isNotEmpty) {
        await secureStorage.write(key: _sessionKey, value: session);
        UaepassLogger.log('Session stored, proceeding to exchange');
        return _exchangeSession(session);
      }

      if (tx != null && tx.isNotEmpty) {
        await secureStorage.write(key: _txKey, value: tx);
        UaepassLogger.log('Transaction stored, fetching result');
        return _fetchResultByTransaction(tx);
      }

      // Check for error codes in the deep link (e.g. NOT_ELIGIBLE, EXISTING_USERS_ONLY)
      final deepLinkErrorCode = errorCode ?? errorParam;
      if (deepLinkErrorCode != null && deepLinkErrorCode.isNotEmpty) {
        UaepassLogger.logWarning('Error code from deep link: $deepLinkErrorCode');
        final failureType = mapBackendErrorToFailureType(
          errorCode: deepLinkErrorCode,
        );
        UaepassLogger.logError('UAEPASS LOGIN FAILED', 'Deep link error: $deepLinkErrorCode');
        UaepassLogger.logKV('Mapped failure type', _failureTypeToString(failureType));
        return UaepassAuthResult.failure(failureType, backendErrorCode: deepLinkErrorCode);
      }

      UaepassLogger.logError('No session or tx in deeplink');
      UaepassLogger.logError('UAEPASS LOGIN FAILED', 'Missing session/tx');
      return const UaepassAuthResult.failure(AuthFailureType.generic);
    }

    UaepassLogger.log('Using polling fallback');
    return _pollForResult();
  }

  AuthFailureType mapBackendErrorToFailureType({
    int? statusCode,
    String? errorCode,
    String? message,
  }) {
    final normalized = (errorCode ?? message ?? '').toLowerCase();

    if (normalized.contains('existing') || normalized.contains('signup')) {
      return AuthFailureType.existingOnly;
    }

    if (normalized.contains('unverified') ||
        normalized.contains('not_eligible') ||
        normalized.contains('not eligible')) {
      return AuthFailureType.unverified;
    }

    if (normalized.contains('cancel') || normalized.contains('decline')) {
      return AuthFailureType.cancelled;
    }

    if (statusCode != null && statusCode >= 400) {
      return AuthFailureType.generic;
    }

    return AuthFailureType.generic;
  }

  /// Try to finalize login from stored session/tx data
  /// Called when user taps "I have approved in UAE PASS" button
  /// 
  /// Flow:
  /// 1. Check secure storage for session → exchange it
  /// 2. Check secure storage for tx → fetch result
  /// 3. If polling is enabled → poll for result
  /// 4. Otherwise → return generic failure
  Future<UaepassAuthResult> tryFinalizeFromStoredData() async {
    UaepassLogger.logSection('TRY FINALIZE FROM STORED DATA');

    // Check for stored session
    final session = await secureStorage.read(key: _sessionKey);
    if (session != null && session.isNotEmpty) {
      UaepassLogger.log('Found stored session, exchanging...');
      return _exchangeSession(session);
    }

    // Check for stored transaction
    final tx = await secureStorage.read(key: _txKey);
    if (tx != null && tx.isNotEmpty) {
      UaepassLogger.log('Found stored tx, fetching result...');
      return _fetchResultByTransaction(tx);
    }

    // Try polling if enabled
    if (config.enablePollingFallback) {
      UaepassLogger.log('No stored data, trying polling...');
      return _pollForResult();
    }

    // No data and polling disabled
    UaepassLogger.logWarning('No stored session/tx and polling disabled');
    UaepassLogger.log('User may need to wait for deep link callback');
    return const UaepassAuthResult.failure(AuthFailureType.generic);
  }

  Future<void> logout() async {
    UaepassLogger.logSection('LOGOUT');
    UaepassLogger.log('Clearing UAE PASS session data');

    _pendingState = null;
    await secureStorage.delete(key: _stateKey);
    await secureStorage.delete(key: _sessionKey);
    await secureStorage.delete(key: _txKey);
    UaepassLogger.logSuccess('Secure storage cleared (state, session, tx)');

    await SharedPref().setPreferencesBoolean('isRegistered', false);
    await SharedPref().removePreference('loginResponse');
    await HiveService.setUserLoggedIn(false);
    UaepassLogger.logSuccess('SharedPreferences cleared');
    UaepassLogger.log('Navigation should return to Login screen');
  }

  Future<UaepassAuthResult> _exchangeSession(String session) async {
    UaepassLogger.logSection('API: SESSION EXCHANGE');
    try {
      // Build device_id (same logic as regular login)
      String deviceId = '';
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceId = '${androidInfo.brand}_${androidInfo.device}_${androidInfo.id}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = '${iosInfo.name}_${iosInfo.model}_${iosInfo.utsname.machine}';
        }
      } catch (e) {
        UaepassLogger.logError('Failed to get device info', e);
      }

      // Ensure FCM token is available
      try {
        await FirebaseService.ensureFCMToken();
      } catch (e) {
        UaepassLogger.logError('Failed to ensure FCM token', e);
      }
      final String fcmTokenValue = SharedPref().getPreferenceString(fcm_token);

      final Map<String, dynamic> requestBody = {
        'jsonrpc': '2.0',
        'params': {
          'session': session,
          if (deviceId.isNotEmpty) 'device_id': deviceId,
          if (fcmTokenValue.isNotEmpty) 'fcm_token': fcmTokenValue,
        },
      };

      UaepassLogger.logKV('Endpoint', config.sessionExchangePath);
      UaepassLogger.logKV('Method', 'POST');
      UaepassLogger.logKV('device_id', deviceId.isNotEmpty ? deviceId : '(empty)');
      UaepassLogger.logKV('fcm_token', fcmTokenValue.isNotEmpty ? '${fcmTokenValue.substring(0, 20)}...' : '(empty)');
      UaepassLogger.logKV('Request body keys', requestBody.keys.join(', '));

      final response = await apiClient.post(
        config.sessionExchangePath,
        data: requestBody,
      );

      UaepassLogger.logKV('Response status', response.statusCode);
      UaepassLogger.log('Response body (masked):');
      if (response.data is Map) {
        UaepassLogger.log(UaepassLogger.safeJsonEncode(Map<String, dynamic>.from(response.data as Map)));
      } else {
        UaepassLogger.logKV('Response', response.data?.toString());
      }

      return _parseBackendResponse(response.data, response.statusCode);
    } catch (e) {
      UaepassLogger.logError('Session exchange error', e);
      UaepassLogger.logError('UAEPASS LOGIN FAILED', 'Session exchange exception');
      return const UaepassAuthResult.failure(AuthFailureType.generic);
    }
  }

  Future<UaepassAuthResult> _fetchResultByTransaction(String tx) async {
    UaepassLogger.logSection('API: FETCH RESULT BY TX');
    try {
      UaepassLogger.logKV('Endpoint', config.resultPollingPath);
      UaepassLogger.logKV('Method', 'GET');
      UaepassLogger.logKV('Query param tx', tx);

      final response = await apiClient.get(
        config.resultPollingPath,
        queryParameters: {'tx': tx},
      );

      UaepassLogger.logKV('Response status', response.statusCode);
      UaepassLogger.log('Response body (masked):');
      if (response.data is Map) {
        UaepassLogger.log(UaepassLogger.safeJsonEncode(Map<String, dynamic>.from(response.data as Map)));
      } else {
        UaepassLogger.logKV('Response', response.data?.toString());
      }

      return _parseBackendResponse(response.data, response.statusCode);
    } catch (e) {
      UaepassLogger.logError('Result fetch error', e);
      return const UaepassAuthResult.failure(AuthFailureType.generic);
    }
  }

  Future<UaepassAuthResult> _pollForResult() async {
    UaepassLogger.logSection('API: POLLING FOR RESULT');
    final started = DateTime.now();
    final tx = await secureStorage.read(key: _txKey) ?? _pendingState;

    UaepassLogger.logKV('Transaction/State for polling', tx);
    UaepassLogger.logKV('Polling timeout', config.pollingTimeout.toString());
    UaepassLogger.logKV('Polling interval', config.pollingInterval.toString());

    if (tx == null || tx.isEmpty) {
      UaepassLogger.logError('No tx or state available for polling');
      return const UaepassAuthResult.failure(AuthFailureType.generic);
    }

    int attempt = 0;
    while (DateTime.now().difference(started) <= config.pollingTimeout) {
      attempt++;
      UaepassLogger.log('Polling attempt #$attempt');
      final result = await _fetchResultByTransaction(tx);
      if (result.isSuccess || result.failureType != AuthFailureType.generic) {
        return result;
      }
      UaepassLogger.log('No result yet, waiting ${config.pollingInterval.inSeconds}s...');
      await Future.delayed(config.pollingInterval);
    }

    UaepassLogger.logError('Polling timeout reached');
    return const UaepassAuthResult.failure(AuthFailureType.generic);
  }

  UaepassAuthResult _parseBackendResponse(dynamic data, int? statusCode) {
    UaepassLogger.log('Parsing backend response');
    UaepassLogger.logKV('Status code', statusCode);

    if (data is! Map) {
      UaepassLogger.logError('Response is not a Map', 'Type: ${data.runtimeType}');
      UaepassLogger.logError('UAEPASS LOGIN FAILED', 'Invalid response format');
      return const UaepassAuthResult.failure(AuthFailureType.generic);
    }

    final map = Map<String, dynamic>.from(data as Map);
    final errorCode = map['error_code']?.toString() ?? map['code']?.toString();
    final errorMessage = map['message']?.toString() ?? map['error']?.toString();

    UaepassLogger.logKV('error_code', errorCode ?? '<none>');
    UaepassLogger.logKV('message', errorMessage ?? '<none>');

    final success = map['result']?['success'] == true ||
        map['success'] == true ||
        map['result']?['token'] != null;

    UaepassLogger.logKV('Success flag', success);

    if (!success) {
      final failureType = mapBackendErrorToFailureType(
        statusCode: statusCode,
        errorCode: errorCode,
        message: errorMessage,
      );
      UaepassLogger.logError('UAEPASS LOGIN FAILED');
      UaepassLogger.logKV('Error mapping result', _failureTypeToString(failureType));
      UaepassLogger.logKV('Backend error_code', errorCode ?? '<none>');
      return UaepassAuthResult.failure(
        failureType,
        backendErrorCode: errorCode,
      );
    }

    final loginResponse = _tryParseLoginResponse(map);
    if (loginResponse == null) {
      UaepassLogger.logError('Failed to parse LoginResponseModel');
      UaepassLogger.logError('UAEPASS LOGIN FAILED', 'Parse error');
      return const UaepassAuthResult.failure(AuthFailureType.generic);
    }

    _persistLogin(loginResponse);
    UaepassLogger.logSuccess('UAEPASS LOGIN SUCCESS');
    UaepassLogger.logKV('User ID', loginResponse.result?.data?.uid ?? loginResponse.result?.data?.emp_id);
    UaepassLogger.logKV('Name', loginResponse.result?.data?.name);
    return UaepassAuthResult.success(loginResponse);
  }

  String _failureTypeToString(AuthFailureType type) {
    switch (type) {
      case AuthFailureType.existingOnly:
        return 'EXISTING_USERS_ONLY';
      case AuthFailureType.unverified:
        return 'NOT_ELIGIBLE';
      case AuthFailureType.cancelled:
        return 'CANCELLED';
      case AuthFailureType.generic:
        return 'GENERIC';
    }
  }

  LoginResponseModel? _tryParseLoginResponse(Map<String, dynamic> map) {
    try {
      if (map.containsKey('result')) {
        return LoginResponseModel.fromJson(map);
      }
      if (map.containsKey('loginResponse')) {
        return LoginResponseModel.fromJson(
          Map<String, dynamic>.from(map['loginResponse'] as Map),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<void> _persistLogin(LoginResponseModel loginResponse) async {
    await SharedPref().setPreferencesString(
      'loginResponse',
      jsonEncode(loginResponse.toJson()),
    );
    await SharedPref().setPreferencesBoolean('isRegistered', true);
    await HiveService.setUserLoggedIn(true);

    // Initialize chat module immediately after login
    ChatModuleHelper.instance
        .initializeFromLoginResponse(loginResponse.toJson())
        .then((_) => print('✅ Chat initialized after UAE PASS login'))
        .catchError((e) => print('⚠️ Chat init after UAE PASS login failed: $e'));
  }

  bool _isCancelled(Uri uri) {
    final error = uri.queryParameters['error']?.toLowerCase();
    final status = uri.queryParameters['status']?.toLowerCase();
    final result = uri.queryParameters['result']?.toLowerCase();

    // Only treat explicit user cancellation signals as "cancelled".
    // Do NOT treat all error deep links as cancelled — they may carry
    // specific error codes (NOT_ELIGIBLE, EXISTING_USERS_ONLY, etc.)
    // that should flow through to handleCallbackOrResult for proper mapping.
    final isExplicitCancel = error == 'access_denied' ||
        status == 'cancel' ||
        status == 'cancelled' ||
        result == 'cancel' ||
        result == 'cancelled';

    // If it's an error deep link, only treat it as cancelled when there is
    // NO specific error code attached — i.e. a bare error link means the
    // user dismissed UAE PASS without completing.
    if (config.isErrorLink(uri) && !isExplicitCancel) {
      final errorCode = uri.queryParameters['code']?.toLowerCase() ??
          uri.queryParameters['error_code']?.toLowerCase();
      if (errorCode != null && errorCode.isNotEmpty) {
        // Has a specific error code → let handleCallbackOrResult map it
        UaepassLogger.logKV('Error link with code', 'code=$errorCode — not treating as cancel');
        return false;
      }
      // Bare error link with no code → treat as cancel
      UaepassLogger.logKV('Bare error link', 'no code — treating as cancel');
      return true;
    }

    if (isExplicitCancel) {
      UaepassLogger.logKV('Cancel detected', 'error=$error, status=$status, result=$result');
    }
    return isExplicitCancel;
  }
}
