part of 'qr_code_bloc.dart';

abstract class QrCodeState extends Equatable {
  const QrCodeState();

  @override
  List<Object?> get props => [];
}

class QrCodeInitial extends QrCodeState {}

class QrCodeLoading extends QrCodeState {}

class QrCodeLoaded extends QrCodeState {
  final Uint8List qrCodeData;

  const QrCodeLoaded({required this.qrCodeData});

  @override
  List<Object> get props => [qrCodeData];
}

class QrCodeError extends QrCodeState {
  final String message;

  const QrCodeError({required this.message});

  @override
  List<Object> get props => [message];
}
