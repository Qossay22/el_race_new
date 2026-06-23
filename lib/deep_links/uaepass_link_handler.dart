import 'package:el_race/config/uaepass_config.dart';
import 'package:el_race/auth/uaepass_auth_cubit.dart';
import 'package:el_race/utils/di.dart';
import 'package:el_race/utils/uaepass_logger.dart';

class UaepassLinkHandler {
  static bool canHandle(UaepassConfig config, Uri uri) {
    final canHandle = config.isSuccessLink(uri) ||
        config.isErrorLink(uri) ||
        uri.queryParameters.containsKey('session') ||
        uri.queryParameters.containsKey('tx') ||
        uri.queryParameters.containsKey('transaction') ||
        uri.queryParameters.containsKey('error');
    
    UaepassLogger.log('canHandle check: $canHandle for scheme=${uri.scheme} host=${uri.host} path=${uri.path}');
    return canHandle;
  }

  static Future<bool> handle(Uri uri) async {
    // Enhanced DEEPLINK RECEIVED logging
    UaepassLogger.logSection('DEEPLINK RECEIVED');
    UaepassLogger.log('Full URI: ${uri.toString()}');
    UaepassLogger.logKV('Scheme', uri.scheme);
    UaepassLogger.logKV('Host', uri.host);
    UaepassLogger.logKV('Path', uri.path);
    UaepassLogger.logKV('Query', uri.query);
    
    // Parse all query parameters
    if (uri.queryParameters.isNotEmpty) {
      UaepassLogger.log('Query Parameters:');
      for (final entry in uri.queryParameters.entries) {
        UaepassLogger.logKV('  ${entry.key}', entry.value);
      }
    }
    
    // Check if success or error link
    final cubit = sl<UaepassAuthCubit>();
    final config = cubit.config;
    
    final isSuccess = config.isSuccessLink(uri);
    final isError = config.isErrorLink(uri);
    UaepassLogger.logKV('Is Success Link', isSuccess);
    UaepassLogger.logKV('Is Error Link', isError);
    
    // Extract key params
    final session = uri.queryParameters['session'];
    final tx = uri.queryParameters['tx'] ?? uri.queryParameters['transaction'];
    final errorCode = uri.queryParameters['error_code'] ?? uri.queryParameters['error'] ?? uri.queryParameters['code'];
    
    UaepassLogger.logKV('Session param', session ?? '<not present>');
    UaepassLogger.logKV('TX param', tx ?? '<not present>');
    UaepassLogger.logKV('Error param', errorCode ?? '<not present>');
    
    if (!canHandle(config, uri)) {
      UaepassLogger.log('Link not handled by UAE PASS (not a UAE PASS callback)');
      return false;
    }

    // Store session/tx temporarily if present
    if (session != null && session.isNotEmpty) {
      UaepassLogger.logSuccess('Session found - storing temporarily');
    }
    if (tx != null && tx.isNotEmpty) {
      UaepassLogger.logSuccess('Transaction found - storing temporarily');
    }
    if (errorCode != null) {
      UaepassLogger.logWarning('Error code received: $errorCode');
    }

    UaepassLogger.log('Processing as UAE PASS callback...');
    await cubit.handleCallbackOrResult(uri);
    return true;
  }
}
