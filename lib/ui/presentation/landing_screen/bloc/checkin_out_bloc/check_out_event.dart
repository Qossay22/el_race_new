part of 'check_out_bloc.dart';

sealed class CheckOutEvent extends Equatable {
  const CheckOutEvent();

  @override
  List<Object> get props => [];
}

final class CheckOutET extends CheckOutEvent {
  final int checkInRecordId;
  final bool
      isAutoCheckout; // true = auto checkout (no Face ID), false = manual (requires Face ID)

  const CheckOutET(this.checkInRecordId, {this.isAutoCheckout = false});

  @override
  List<Object> get props => [checkInRecordId, isAutoCheckout];
}
