import 'package:flutter/foundation.dart';

/// UI Messages for UAE PASS authentication errors
/// Maps to the 4 error buckets:
/// - existingOnly: Service is only available for existing users
/// - unverified: User is unverified or not eligible
/// - generic: Something went wrong
/// - cancelled: User cancelled the authentication
class UaepassUiMessages {
  final String existingUsersOnly;
  final String unverified;
  final String generic;
  final String cancelled;

  const UaepassUiMessages({
    required this.existingUsersOnly,
    required this.unverified,
    required this.generic,
    required this.cancelled,
  });
}

/// UAE PASS Configuration
/// 
/// Contains all configuration values for UAE PASS integration.
/// Use [UaepassConfig.forCurrentEnvironment()] to select the active UAE PASS
/// environment.
/// - All build modes currently use [UaepassConfig.staging()]
/// - Switch release back to [UaepassConfig.production()] after UAE PASS provides
///   the production client_id.
/// 
/// ## Feature Flags
/// 
/// ### useBackendRedirectDeepLink (default: true)
/// When true, the flow is:
/// 1. App opens UAE PASS in browser
/// 2. UAE PASS redirects to backend callback URL
/// 3. Backend exchanges code for tokens
/// 4. Backend redirects to app deep link with session/tx
/// 5. App exchanges session for login data
/// 
/// When false, app would need to handle the authorization code directly
/// (NOT recommended - requires client_secret in app)
/// 
/// ### enablePollingFallback (default: false)
/// When true, if deep link callback doesn't arrive:
/// - User can tap "I have approved" button
/// - App polls backend for result using stored state
/// 
/// When false, app relies entirely on deep link callback.
class UaepassConfig {
  /// OAuth client_id (public, safe to embed in app)
  final String clientId;

  /// Backend redirect URL (NOT the app deep link)
  /// UAE PASS redirects here first, then backend redirects to app
  final String redirectUrl;

  /// UAE PASS authorization server base URL
  /// Staging: https://stg-id.uaepass.ae
  /// Production: https://id.uaepass.ae
  final String authorizationBaseUrl;

  /// Path to authorization endpoint
  final String authorizationPath;

  /// OAuth scope - what profile data to request
  final String scope;

  /// OAuth response type (always "code" for authorization code flow)
  final String responseType;

  /// ACR values for authentication level
  /// urn:safelayer:tws:policies:authentication:level:low
  final String acrValues;

  /// Backend API base URL for session exchange
  final String baseApiUrl;

  /// Backend endpoint for session exchange
  /// POST {baseApiUrl}/{sessionExchangePath}
  /// Body: { "session": "<value>" } or { "tx": "<value>" }
  final String sessionExchangePath;

  /// Backend endpoint for polling result (optional)
  /// GET {baseApiUrl}/{resultPollingPath}?tx=<value>
  final String resultPollingPath;

  /// Feature flag: Use backend redirect → deep link flow
  /// When true: backend handles code exchange and redirects to app
  /// When false: app would handle code directly (not recommended)
  final bool useBackendRedirectDeepLink;

  /// Feature flag: Enable polling fallback
  /// When true: "I have approved" button polls backend
  /// When false: relies entirely on deep link callback
  final bool enablePollingFallback;

  /// Deep link scheme (e.g., "elrace")
  final String deepLinkScheme;

  /// Deep link host (e.g., "uaepass")
  final String deepLinkHost;

  /// Deep link success path (e.g., "/success")
  final String deepLinkSuccessPath;

  /// Deep link error path (e.g., "/error")
  final String deepLinkErrorPath;

  /// Extra auth params (e.g., ui_locales)
  final Map<String, String> extraAuthParams;

  /// UI messages for error dialogs
  final UaepassUiMessages uiMessages;

  /// Path to UAE PASS button asset
  final String buttonAssetPath;

  /// Loading screen message
  final String loadingMessage;

  /// Polling interval (when enablePollingFallback is true)
  final Duration pollingInterval;

  /// Polling timeout (when enablePollingFallback is true)
  final Duration pollingTimeout;

  /// Enable debug logging (should be kDebugMode)
  final bool enableDebugLog;

  const UaepassConfig({
    required this.clientId,
    required this.redirectUrl,
    required this.authorizationBaseUrl,
    required this.authorizationPath,
    required this.scope,
    required this.responseType,
    required this.acrValues,
    required this.baseApiUrl,
    required this.sessionExchangePath,
    required this.resultPollingPath,
    required this.useBackendRedirectDeepLink,
    required this.enablePollingFallback,
    required this.deepLinkScheme,
    required this.deepLinkHost,
    required this.deepLinkSuccessPath,
    required this.deepLinkErrorPath,
    required this.extraAuthParams,
    required this.uiMessages,
    required this.buttonAssetPath,
    required this.loadingMessage,
    required this.pollingInterval,
    required this.pollingTimeout,
    required this.enableDebugLog,
  });

  Uri get authorizationEndpoint => Uri.parse(
        '${authorizationBaseUrl.replaceAll(RegExp(r"/+\$"), "")}$authorizationPath',
      );

  Uri buildAuthorizationUrl(String state) {
    // Build params map - Uri.replace handles encoding automatically
    final params = <String, String>{
      'response_type': responseType,
      'client_id': clientId,
      'redirect_uri': redirectUrl,
      'scope': scope,
      'state': state,
      'acr_values': acrValues,
      ...extraAuthParams,
    };

    // Use Uri.https for proper encoding of all parameters
    return Uri.https(
      authorizationEndpoint.host,
      authorizationEndpoint.path,
      params,
    );
  }

  bool isSuccessLink(Uri uri) {
    return uri.scheme == deepLinkScheme &&
        uri.host == deepLinkHost &&
        uri.path == deepLinkSuccessPath;
  }

  bool isErrorLink(Uri uri) {
    return uri.scheme == deepLinkScheme &&
        uri.host == deepLinkHost &&
        uri.path == deepLinkErrorPath;
  }

  /// Returns the active UAE PASS config.
  ///
  /// Temporary behavior: release also uses staging until the production
  /// client_id is configured.
  static UaepassConfig forCurrentEnvironment() {
    return staging();
  }

  /// Staging configuration (stg-id.uaepass.ae)
  static UaepassConfig staging() {
    return UaepassConfig(
      clientId: 'auh_elrace_mob_stage',
      redirectUrl: 'https://erp.elrace.com/uaepass/callback',
      authorizationBaseUrl: 'https://stg-id.uaepass.ae',
      authorizationPath: '/idshub/authorize',
      scope: 'urn:uae:digitalid:profile:general',
      responseType: 'code',
      acrValues: 'urn:safelayer:tws:policies:authentication:level:low',
      baseApiUrl: 'https://erp.elrace.com/api/',
      sessionExchangePath: 'uaepass/mobile/session',
      resultPollingPath: 'uaepass/result',
      useBackendRedirectDeepLink: true,
      enablePollingFallback: true,
      deepLinkScheme: 'elrace',
      deepLinkHost: 'uaepass',
      deepLinkSuccessPath: '/success',
      deepLinkErrorPath: '/error',
      extraAuthParams: const {
        'ui_locales': 'en',
      },
      uiMessages: const UaepassUiMessages(
        existingUsersOnly: 'Existing users only',
        unverified: 'Unverified / Not eligible',
        generic: 'Something went wrong',
        cancelled: 'User cancel',
      ),
      buttonAssetPath: 'assets/png/uaepass_button.png',
      loadingMessage: 'Signing in with UAE PASS...',
      pollingInterval: const Duration(seconds: 3),
      pollingTimeout: const Duration(seconds: 30),
      enableDebugLog: kDebugMode,
    );
  }

  /// Production configuration (id.uaepass.ae)
  ///
  /// TODO: Replace the placeholder [clientId] with the production client_id
  ///       once it is provided by UAE PASS.
  static UaepassConfig production() {
    return UaepassConfig(
      // ⚠️  PLACEHOLDER — update with the real production client_id from UAE PASS
      clientId: 'PRODUCTION_CLIENT_ID_PENDING',
      redirectUrl: 'https://erp.elrace.com/uaepass/callback',
      authorizationBaseUrl: 'https://id.uaepass.ae',
      authorizationPath: '/idshub/authorize',
      scope: 'urn:uae:digitalid:profile:general',
      responseType: 'code',
      acrValues: 'urn:safelayer:tws:policies:authentication:level:low',
      baseApiUrl: 'https://erp.elrace.com/api/',
      sessionExchangePath: 'uaepass/mobile/session',
      resultPollingPath: 'uaepass/result',
      useBackendRedirectDeepLink: true,
      enablePollingFallback: true,
      deepLinkScheme: 'elrace',
      deepLinkHost: 'uaepass',
      deepLinkSuccessPath: '/success',
      deepLinkErrorPath: '/error',
      extraAuthParams: const {
        'ui_locales': 'en',
      },
      uiMessages: const UaepassUiMessages(
        existingUsersOnly: 'Existing users only',
        unverified: 'Unverified / Not eligible',
        generic: 'Something went wrong',
        cancelled: 'User cancel',
      ),
      buttonAssetPath: 'assets/png/uaepass_button.png',
      loadingMessage: 'Signing in with UAE PASS...',
      pollingInterval: const Duration(seconds: 3),
      pollingTimeout: const Duration(seconds: 30),
      enableDebugLog: false, // no debug logs in production
    );
  }
}
