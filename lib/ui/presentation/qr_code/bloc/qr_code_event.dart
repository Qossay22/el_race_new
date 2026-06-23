part of 'qr_code_bloc.dart';

abstract class QrCodeEvent extends Equatable {
  const QrCodeEvent();

  @override
  List<Object> get props => [];
}

class LoadQrCode extends QrCodeEvent {
  const LoadQrCode();
}

class RefreshQrCode extends QrCodeEvent {
  const RefreshQrCode();
}
