part of 'error_bloc.dart';

sealed class ErrorState extends Equatable {
  const ErrorState();
  @override
  List<Object> get props => [];
}

final class ErrorInitial extends ErrorState {}

final class NormalErrorMessage extends ErrorState {
  final String errMsg;
  const NormalErrorMessage({required this.errMsg});

  @override
  List<Object> get props => [errMsg];
}
