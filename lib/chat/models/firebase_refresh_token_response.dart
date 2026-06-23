/// Response model for POST /api/firebase/refresh_token
///
/// Example response:
/// ```json
/// {
///   "jsonrpc": "2.0",
///   "id": null,
///   "result": {
///     "success": true,
///     "firebase_custom_token": "eyJhbGci..."
///   }
/// }
/// ```
class FirebaseRefreshTokenResponse {
  final String jsonrpc;
  final dynamic id;
  final FirebaseRefreshTokenResult? result;

  /// Raw error from the JSON-RPC envelope (if any).
  final Map<String, dynamic>? error;

  FirebaseRefreshTokenResponse({
    required this.jsonrpc,
    this.id,
    this.result,
    this.error,
  });

  factory FirebaseRefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return FirebaseRefreshTokenResponse(
      jsonrpc: json['jsonrpc']?.toString() ?? '2.0',
      id: json['id'],
      result: json['result'] is Map<String, dynamic>
          ? FirebaseRefreshTokenResult.fromJson(
              json['result'] as Map<String, dynamic>)
          : null,
      error: json['error'] is Map<String, dynamic>
          ? json['error'] as Map<String, dynamic>
          : null,
    );
  }

  /// Whether the request succeeded and contains a valid token.
  bool get isSuccess =>
      result != null && result!.success && result!.firebaseCustomToken != null;

  /// Shortcut to extract the Firebase custom token.
  String? get firebaseCustomToken => result?.firebaseCustomToken;

  Map<String, dynamic> toJson() => {
        'jsonrpc': jsonrpc,
        'id': id,
        if (result != null) 'result': result!.toJson(),
        if (error != null) 'error': error,
      };

  @override
  String toString() =>
      'FirebaseRefreshTokenResponse(success=${result?.success}, '
      'hasToken=${result?.firebaseCustomToken != null})';
}

class FirebaseRefreshTokenResult {
  final bool success;
  final String? firebaseCustomToken;

  FirebaseRefreshTokenResult({
    required this.success,
    this.firebaseCustomToken,
  });

  factory FirebaseRefreshTokenResult.fromJson(Map<String, dynamic> json) {
    // Handle multiple possible locations for the token
    final token = json['firebase_custom_token']?.toString();
    final dataToken = json['data'] is Map<String, dynamic>
        ? (json['data'] as Map<String, dynamic>)['firebase_custom_token']
            ?.toString()
        : null;

    return FirebaseRefreshTokenResult(
      success: json['success'] == true,
      firebaseCustomToken: _validTokenOrNull(token) ??
          _validTokenOrNull(dataToken),
    );
  }

  /// Returns the token only if it looks like a real value.
  static String? _validTokenOrNull(String? token) {
    if (token == null || token.isEmpty || token == 'false' || token == 'null') {
      return null;
    }
    return token;
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        if (firebaseCustomToken != null)
          'firebase_custom_token': firebaseCustomToken,
      };
}
