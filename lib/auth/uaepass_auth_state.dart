part of 'uaepass_auth_cubit.dart';

enum UaepassAuthStatus { idle, loading, waiting, success, failure }

class UaepassAuthState extends Equatable {
  final UaepassAuthStatus status;
  final AuthFailureType? failureType;

  const UaepassAuthState._(this.status, this.failureType);

  const UaepassAuthState.idle() : this._(UaepassAuthStatus.idle, null);

  const UaepassAuthState.loading() : this._(UaepassAuthStatus.loading, null);

  const UaepassAuthState.waiting() : this._(UaepassAuthStatus.waiting, null);

  const UaepassAuthState.success() : this._(UaepassAuthStatus.success, null);

  const UaepassAuthState.failure(AuthFailureType? failure)
      : this._(UaepassAuthStatus.failure, failure);

  @override
  List<Object?> get props => [status, failureType];
}
