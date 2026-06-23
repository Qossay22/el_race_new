/// UAE PASS API Response Models
/// 
/// These models handle the session exchange response from the backend.
/// Backend endpoint: POST {baseApiUrl}/uaepass/mobile/session
/// 
/// Success Response (LoginSuccess):
/// {
///   "result": {
///     "success": true,
///     "token": "eyJhbG...",
///     "data": {
///       "uid": 123,
///       "emp_id": "E123",
///       "name": "Ahmed",
///       "email": "ahmed@example.com",
///       ...
///     }
///   }
/// }
/// 
/// Error Response (LoginFailure):
/// {
///   "result": {
///     "success": false
///   },
///   "error_code": "EXISTING_USERS_ONLY",
///   "message": "This service is only for existing users"
/// }

/// Represents a successful UAE PASS login response
class UaepassLoginSuccess {
  final String token;
  final UaepassUserData user;

  const UaepassLoginSuccess({
    required this.token,
    required this.user,
  });

  factory UaepassLoginSuccess.fromJson(Map<String, dynamic> json) {
    // Handle nested result structure
    final result = json['result'] as Map<String, dynamic>?;
    final data = result?['data'] as Map<String, dynamic>? ?? json['data'] as Map<String, dynamic>?;
    final token = result?['token']?.toString() ?? json['token']?.toString() ?? '';

    return UaepassLoginSuccess(
      token: token,
      user: UaepassUserData.fromJson(data ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'user': user.toJson(),
  };

  @override
  String toString() => 'UaepassLoginSuccess(token: ${token.isNotEmpty ? "***" : "<empty>"}, user: $user)';
}

/// User data from UAE PASS profile
class UaepassUserData {
  final String? uid;
  final String? empId;
  final String? name;
  final String? email;
  final String? mobile;
  final String? nationalId;
  
  const UaepassUserData({
    this.uid,
    this.empId,
    this.name,
    this.email,
    this.mobile,
    this.nationalId,
  });

  factory UaepassUserData.fromJson(Map<String, dynamic> json) {
    return UaepassUserData(
      uid: json['uid']?.toString(),
      empId: json['emp_id']?.toString(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      mobile: json['mobile']?.toString(),
      nationalId: json['national_id']?.toString() ?? json['nationalId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'emp_id': empId,
    'name': name,
    'email': email,
    'mobile': mobile,
    'national_id': nationalId,
  };

  @override
  String toString() => 'UaepassUserData(uid: $uid, name: $name)';
}

/// Represents a failed UAE PASS login response
class UaepassLoginFailure {
  final String errorCode;
  final String message;
  final int? statusCode;

  const UaepassLoginFailure({
    required this.errorCode,
    required this.message,
    this.statusCode,
  });

  factory UaepassLoginFailure.fromJson(Map<String, dynamic> json, {int? statusCode}) {
    return UaepassLoginFailure(
      errorCode: json['error_code']?.toString() ?? 
                 json['code']?.toString() ?? 
                 'UNKNOWN',
      message: json['message']?.toString() ?? 
               json['error']?.toString() ?? 
               'An unknown error occurred',
      statusCode: statusCode,
    );
  }

  Map<String, dynamic> toJson() => {
    'error_code': errorCode,
    'message': message,
    'status_code': statusCode,
  };

  /// Maps error codes to the 4 UI error buckets
  /// 
  /// Error Mapping:
  /// - EXISTING_USERS_ONLY, SIGNUP_NOT_ALLOWED → existingOnly
  /// - NOT_ELIGIBLE, UNVERIFIED, NOT_VERIFIED → unverified
  /// - CANCELLED, ACCESS_DENIED, USER_CANCEL → cancelled
  /// - All others → generic
  UaepassErrorType get errorType {
    final normalized = errorCode.toLowerCase();
    
    // Existing users only
    if (normalized.contains('existing') || normalized.contains('signup')) {
      return UaepassErrorType.existingOnly;
    }
    
    // Not eligible / Unverified
    if (normalized.contains('unverified') || 
        normalized.contains('not_eligible') ||
        normalized.contains('eligible') ||
        normalized.contains('verified')) {
      return UaepassErrorType.unverified;
    }
    
    // User cancelled
    if (normalized.contains('cancel') || 
        normalized.contains('denied') ||
        normalized.contains('decline')) {
      return UaepassErrorType.cancelled;
    }
    
    return UaepassErrorType.generic;
  }

  @override
  String toString() => 'UaepassLoginFailure(code: $errorCode, message: $message)';
}

/// The 4 error buckets for UI display
enum UaepassErrorType {
  /// Service is only for existing users (no signup)
  existingOnly,
  
  /// User account is unverified or not eligible
  unverified,
  
  /// User cancelled the authentication
  cancelled,
  
  /// Generic error / Something went wrong
  generic,
}

/// Extension for error type display messages
extension UaepassErrorTypeX on UaepassErrorType {
  String get defaultMessage {
    switch (this) {
      case UaepassErrorType.existingOnly:
        return 'Existing users only';
      case UaepassErrorType.unverified:
        return 'Unverified / Not eligible';
      case UaepassErrorType.cancelled:
        return 'User cancel';
      case UaepassErrorType.generic:
        return 'Something went wrong';
    }
  }
}
