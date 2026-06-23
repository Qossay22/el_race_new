part of 'sign_in_bloc.dart';

sealed class SignInEvent extends Equatable {
  const SignInEvent();
  @override
  List<Object> get props => [];
}

final class CheckSignedIn extends SignInEvent {}

class SignInET extends SignInEvent {
  final String email, password, deviceId;
  const SignInET(
      {required this.email, required this.password, required this.deviceId});
  @override
  List<Object> get props => [email, password, deviceId];
}
