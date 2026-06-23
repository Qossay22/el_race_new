part of 'check_out_bloc.dart';

abstract class CheckOutState extends Equatable {
  const CheckOutState();

  @override
  List<Object?> get props => [];
}

class CheckOutInitial extends CheckOutState {}

class CheckedOutST extends CheckOutState {
  final String message;

  const CheckedOutST(this.message);

  @override
  List<Object> get props => [message];
}

class CheckOutErrorST extends CheckOutState {
  final String errorMessage;

  const CheckOutErrorST(this.errorMessage);

  @override
  List<Object> get props => [errorMessage];
}

class CheckOutWarningST extends CheckOutState {
  final String warningMessage;

  const CheckOutWarningST(this.warningMessage);

  @override
  List<Object> get props => [warningMessage];
}
final class CheckOutLoadingST extends CheckOutState {
  final bool isLoading;
  const CheckOutLoadingST({required this.isLoading});
  @override
  List<Object> get props => [isLoading];
}