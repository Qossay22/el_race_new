part of 'check_in_bloc.dart';

abstract class CheckInState extends Equatable {
  const CheckInState();

  @override
  List<Object?> get props => [];
}

class CheckInInitial extends CheckInState {}

class CheckedInST extends CheckInState {
  final String message;
  final int checkInRecordId;

  const CheckedInST(this.message, this.checkInRecordId);

  @override
  List<Object> get props => [message, checkInRecordId];
}

class CheckInErrorST extends CheckInState {
  final String errorMessage;

  const CheckInErrorST(this.errorMessage);

  @override
  List<Object> get props => [errorMessage];
}

class CheckInWarningST extends CheckInState {
  final String warningMessage;
  final int checkInRecordId;

  const CheckInWarningST(this.warningMessage, this.checkInRecordId);

  @override
  List<Object> get props => [warningMessage, checkInRecordId];
}

final class CheckInLoadingST extends CheckInState {
  final bool isLoading;
  const CheckInLoadingST({required this.isLoading});
  @override
  List<Object> get props => [isLoading];
}

/// State when check-in is blocked due to time restriction
/// Check-in is only allowed before 11:59 AM Dubai time
class CheckInBlockedST extends CheckInState {
  final String message;
  final DateTime currentDubaiTime;
  final DateTime cutoffTime;

  const CheckInBlockedST({
    required this.message,
    required this.currentDubaiTime,
    required this.cutoffTime,
  });

  @override
  List<Object?> get props => [message, currentDubaiTime, cutoffTime];
}
