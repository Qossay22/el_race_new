import 'dart:async';
import 'dart:typed_data';

import 'package:el_race/ui/presentation/qr_code/data/repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'qr_code_event.dart';
part 'qr_code_state.dart';

class QrCodeBloc extends Bloc<QrCodeEvent, QrCodeState> {
  final QrCodeRepository _qrCodeRepository;

  QrCodeBloc({QrCodeRepository? qrCodeRepository})
      : _qrCodeRepository = qrCodeRepository ?? QrCodeRepository(),
        super(QrCodeInitial()) {
    on<LoadQrCode>(_onLoadQrCode);
    on<RefreshQrCode>(_onRefreshQrCode);
  }

  FutureOr<void> _onLoadQrCode(
    LoadQrCode event,
    Emitter<QrCodeState> emit,
  ) async {
    emit(QrCodeLoading());

    try {
      Uint8List? qrCodeData = await _qrCodeRepository.getQrCodeImageDirect();

      if (qrCodeData != null) {
        emit(QrCodeLoaded(qrCodeData: qrCodeData));
      } else {
        qrCodeData = await _qrCodeRepository.getQrCodeImage();
        if (qrCodeData != null) {
          emit(QrCodeLoaded(qrCodeData: qrCodeData));
        } else {
          emit(const QrCodeError(message: 'Failed to load QR code'));
        }
      }
    } catch (e) {
      emit(QrCodeError(message: 'Error loading QR code: $e'));
    }
  }

  FutureOr<void> _onRefreshQrCode(
    RefreshQrCode event,
    Emitter<QrCodeState> emit,
  ) async {
    // Add a small delay to show refresh state
    await Future.delayed(const Duration(milliseconds: 500));
    add(const LoadQrCode());
  }
}
