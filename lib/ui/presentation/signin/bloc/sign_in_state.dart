part of 'sign_in_bloc.dart';

sealed class SignInState extends Equatable {
  const SignInState();
  @override
  List<Object> get props => [];
}

final class InitialSignedInST extends SignInState {
  final LoginResponseModel loginResponse;
  const InitialSignedInST({required this.loginResponse});
  @override
  List<Object> get props => [loginResponse];
}

final class NotSignedInST extends SignInState {}

final class SignInInitial extends SignInState {}

final class LoadingST extends SignInState {
  final bool isLoading;
  const LoadingST({required this.isLoading});
  @override
  List<Object> get props => [isLoading];
}

final class ErrMsg extends SignInState {
  final String msg;
  const ErrMsg({required this.msg});

  @override
  List<Object> get props => [msg];
}
