import 'package:el_race/ui/presentation/qr_code/bloc/qr_code_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QrCodeDisplayWidget extends StatelessWidget {
  final double? width;
  final double? height;
  final bool showRefreshButton;
  final VoidCallback? onTap;

  const QrCodeDisplayWidget({
    super.key,
    this.width,
    this.height,
    this.showRefreshButton = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => QrCodeBloc()..add(const LoadQrCode()),
      child: BlocBuilder<QrCodeBloc, QrCodeState>(
        builder: (context, state) {
          return Container(
            width: width ?? 200.w,
            height: height ?? 200.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: _buildContent(context, state),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, QrCodeState state) {
    if (state is QrCodeLoading) {
      return _buildLoadingState();
    } else if (state is QrCodeLoaded) {
      return _buildLoadedState(context, state);
    } else if (state is QrCodeError) {
      return _buildErrorState(context, state);
    } else {
      return _buildInitialState();
    }
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.grey.shade50,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text(
              'Loading QR Code...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, QrCodeLoaded state) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // QR Code Image
          Center(
            child: Image.memory(
              state.qrCodeData,
              fit: BoxFit.contain,
              width: (width ?? 200.w) - 16,
              height: (height ?? 200.w) - 16,
            ),
          ),
          // Refresh Button
          if (showRefreshButton)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  context.read<QrCodeBloc>().add(const RefreshQrCode());
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.refresh,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, QrCodeError state) {
    return Container(
      color: Colors.red.shade50,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade400,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Failed to load QR Code',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              state.message,
              style: TextStyle(
                fontSize: 10,
                color: Colors.red.shade500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                context.read<QrCodeBloc>().add(const LoadQrCode());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return Container(
      color: Colors.grey.shade50,
      child: const Center(
        child: Text(
          'QR Code will appear here',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}

/// A compact QR code widget for use in smaller spaces
class CompactQrCodeWidget extends StatelessWidget {
  final VoidCallback? onTap;

  const CompactQrCodeWidget({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return QrCodeDisplayWidget(
      width: 120.w,
      height: 120.w,
      showRefreshButton: false,
      onTap: onTap,
    );
  }
}

/// A full-screen QR code display
class FullScreenQrCodeWidget extends StatelessWidget {
  const FullScreenQrCodeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My QR Code'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              QrCodeDisplayWidget(
                width: 300.w,
                height: 300.w,
                showRefreshButton: true,
              ),
              const SizedBox(height: 24),
              const Text(
                'Scan this QR code to access your profile',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
