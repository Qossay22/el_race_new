import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../bloc/approval_bloc.dart';
import '../bloc/approval_event.dart';
import '../bloc/approval_state.dart';
import 'package:el_race/core/utils/shared_pref.dart';

class ApprovalActionButtons extends StatelessWidget {
  final String requestId;
  final String type;
  final void Function(String result)? onResult;
  final bool disabled;
  final String? selectedAction;
  final List<String> userIds;
  final ApprovalActionButtonsVariant variant;
  final double? pillWidth;
  final double? pillHeight;
  final BorderRadius? pillBorderRadius;
  final TextStyle? pillTextStyle;
  final double? pillSpacing;
  final bool showHrApproveConfirmation;
  final bool enableFakeApproveDemo;
  final bool useProvidedComment;
  final String? Function()? commentProvider;

  const ApprovalActionButtons({
    super.key,
    required this.requestId,
    required this.type,
    this.onResult,
    this.disabled = false,
    this.selectedAction,
    required this.userIds,
    this.variant = ApprovalActionButtonsVariant.holdCircle,
    this.pillWidth,
    this.pillHeight,
    this.pillBorderRadius,
    this.pillTextStyle,
    this.pillSpacing,
    this.showHrApproveConfirmation = false,
    this.enableFakeApproveDemo = false,
    this.useProvidedComment = false,
    this.commentProvider,
  });

  String _resolveProvidedComment() {
    final raw = commentProvider?.call() ?? '';
    final trimmed = raw.trim();
    return trimmed.isEmpty ? '..' : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController commentController = TextEditingController();
    if (variant == ApprovalActionButtonsVariant.rectangle) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: _buildRectangleActionButton(
              context,
              label: 'REJECT',
              color: const Color(0xFFBA1719),
              commentController: commentController,
              isSelected: selectedAction == 'reject',
              listenToBloc: true,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildRectangleActionButton(
              context,
              label: 'APPROVE',
              color: const Color(0xFF009859),
              commentController: commentController,
              isSelected: selectedAction == 'approve',
              listenToBloc: false,
            ),
          ),
        ],
      );
    }
    if (variant == ApprovalActionButtonsVariant.pill) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPillActionButton(
            context,
            label: 'REJECT',
            color: const Color(0xFFBA1719),
            commentController: commentController,
            isSelected: selectedAction == 'reject',
            listenToBloc: true,
          ),
          SizedBox(width: pillSpacing ?? 16.w),
          _buildPillActionButton(
            context,
            label: 'APPROVE',
            color: const Color(0xFF009859),
            commentController: commentController,
            isSelected: selectedAction == 'approve',
            listenToBloc: false,
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCircleActionButton(context, "REJECT", const Color(0xFFBA1719),
            Icons.close, commentController,
            isSelected: selectedAction == 'reject', listenToBloc: true),
        SizedBox(width: 40.w),
        _buildCircleActionButton(context, "APPROVE", const Color(0xFF009859),
            Icons.check, commentController,
            isSelected: selectedAction == 'approve', listenToBloc: false),
      ],
    );
  }

  Widget _buildRectangleActionButton(
    BuildContext context, {
    required String label,
    required Color color,
    required TextEditingController commentController,
    bool isSelected = false,
    bool listenToBloc = true,
  }) {
    return BlocConsumer<ApprovalBloc, ApprovalState>(
      listenWhen: (previous, current) {
        if (!listenToBloc) return false;
        if (current is ApprovalSuccess && previous is! ApprovalSuccess) {
          return true;
        }
        if (current is ApprovalFailure && previous is! ApprovalFailure) {
          return true;
        }
        return false;
      },
      listener: (ctx, state) {
        if (state is ApprovalSuccess) {
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          if (onResult != null) {
            onResult!(state.message);
          }

          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context, true);
            Future.delayed(const Duration(milliseconds: 100), () {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            });
          }
        } else if (state is ApprovalFailure) {
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                duration: const Duration(seconds: 4),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      builder: (context, state) {
        final isLoading = state is ApprovalLoading;
        final isButtonDisabled = disabled || isLoading;

        return SizedBox(
          width: double.infinity,
          height: 52.w,
          child: ElevatedButton(
            onPressed: isButtonDisabled
                ? null
                : () async {
                    final token = SharedPref.getLoginData().result?.token ?? '';
                    String finalComment = '..';
                    if (useProvidedComment) {
                      finalComment = _resolveProvidedComment();
                    } else {
                      final String? comment =
                          await _showCommentDialog(context, label);

                      if (!context.mounted) return;
                      if (comment == null) {
                        return;
                      }
                      finalComment = comment;
                    }

                    if (context.mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        barrierColor: Colors.black54,
                        builder: (BuildContext dialogContext) {
                          return PopScope(
                            canPop: false,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text(
                                      'Processing...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }

                    if (label == 'APPROVE') {
                      context.read<ApprovalBloc>().add(
                            ApproveRequest(
                              requestId: requestId,
                              type: type,
                              token: token,
                              userIds: userIds,
                              comment: finalComment,
                            ),
                          );
                    } else {
                      context.read<ApprovalBloc>().add(
                            RejectRequest(
                              requestId: requestId,
                              type: type,
                              token: token,
                              userIds: userIds,
                              comment: finalComment,
                            ),
                          );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              disabledBackgroundColor: color.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              elevation: isSelected ? 6 : 2,
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPillActionButton(
    BuildContext context, {
    required String label,
    required Color color,
    required TextEditingController commentController,
    bool isSelected = false,
    bool listenToBloc = true,
  }) {
    return BlocConsumer<ApprovalBloc, ApprovalState>(
      listenWhen: (previous, current) {
        if (!listenToBloc) return false;
        if (current is ApprovalSuccess && previous is! ApprovalSuccess) {
          return true;
        }
        if (current is ApprovalFailure && previous is! ApprovalFailure) {
          return true;
        }
        return false;
      },
      listener: (ctx, state) {
        if (state is ApprovalSuccess) {
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          if (onResult != null) {
            onResult!(state.message);
          }

          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context, true);
            Future.delayed(const Duration(milliseconds: 100), () {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            });
          }
        } else if (state is ApprovalFailure) {
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                duration: const Duration(seconds: 4),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      builder: (context, state) {
        final isLoading = state is ApprovalLoading;
        final isButtonDisabled = disabled || isLoading;

        return SizedBox(
          width: pillWidth ?? 150.w,
          height: pillHeight ?? 52.w,
          child: ElevatedButton(
            onPressed: isButtonDisabled
                ? null
                : () async {
                    final token = SharedPref.getLoginData().result?.token ?? '';
                    String finalComment = '..';

                    if (useProvidedComment) {
                      finalComment = _resolveProvidedComment();
                    } else if (showHrApproveConfirmation) {
                      final decision =
                          await _showHrActionSliderDialog(context, label);
                      if (!context.mounted ||
                          decision == null ||
                          !decision.isConfirmed) {
                        return;
                      }

                      finalComment = decision.comment.trim().isEmpty
                          ? '..'
                          : decision.comment.trim();

                      if (enableFakeApproveDemo) {
                        await _simulateFakeActionSuccess(
                          context,
                          actionLabel: label,
                        );
                        return;
                      }
                    } else {
                      final String? comment =
                          await _showCommentDialog(context, label);

                      if (!context.mounted) return;
                      if (comment == null) {
                        return;
                      }
                      finalComment = comment;
                    }

                    if (context.mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        barrierColor: Colors.black54,
                        builder: (BuildContext dialogContext) {
                          return PopScope(
                            canPop: false,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text(
                                      'Processing...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }

                    if (label == 'APPROVE') {
                      context.read<ApprovalBloc>().add(
                            ApproveRequest(
                              requestId: requestId,
                              type: type,
                              token: token,
                              userIds: userIds,
                              comment: finalComment,
                            ),
                          );
                    } else {
                      context.read<ApprovalBloc>().add(
                            RejectRequest(
                              requestId: requestId,
                              type: type,
                              token: token,
                              userIds: userIds,
                              comment: finalComment,
                            ),
                          );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              disabledBackgroundColor: color.withValues(alpha: 0.4),
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: pillBorderRadius ?? BorderRadius.circular(30),
              ),
            ),
            child: Text(
              '${label.substring(0, 1)}${label.substring(1).toLowerCase()}',
              style: pillTextStyle ??
                  GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _simulateFakeActionSuccess(
    BuildContext context, {
    required String actionLabel,
  }) async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Processing...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 900));

    if (!context.mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    final isApprove = actionLabel == 'APPROVE';
    final fakeMessage = isApprove
        ? 'Approved successfully (demo mode)'
        : 'Rejected successfully (demo mode)';

    if (!context.mounted) return;
    if (onResult != null) {
      onResult!(fakeMessage);
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(fakeMessage),
        duration: const Duration(seconds: 2),
        backgroundColor: isApprove ? Colors.green : Colors.red,
      ),
    );

    if (context.mounted && Navigator.canPop(context)) {
      Navigator.pop(context, true);
    }
  }

  Future<_ApprovalDialogDecision?> _showHrActionSliderDialog(
    BuildContext context,
    String actionLabel,
  ) async {
    final actionText = actionLabel.toLowerCase();
    final demoComment = actionLabel == 'APPROVE'
        ? 'Fake approval comment'
        : 'Fake rejection comment';

    final TextEditingController commentController = TextEditingController(
      text: enableFakeApproveDemo ? demoComment : '',
    );

    return showDialog<_ApprovalDialogDecision>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        double sliderProgress = 0.5;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Are you sure you want to $actionText ?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F1F1F),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      children: [
                        Text(
                          'Comments',
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF555555),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${commentController.text.length}/50',
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: commentController,
                      maxLength: 50,
                      onChanged: (_) => setModalState(() {}),
                      minLines: 2,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Write your comment...',
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 10.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide:
                              const BorderSide(color: Color(0xFFD8D8D8)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide:
                              const BorderSide(color: Color(0xFFD8D8D8)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide:
                              const BorderSide(color: Color(0xFFBDBDBD)),
                        ),
                      ),
                    ),
                    SizedBox(height: 14.h),
                    SizedBox(
                      height: 52.h,
                      width: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final knobSize = 42.w;
                          final maxLeft = constraints.maxWidth - knobSize;
                          final knobLeft =
                              (maxLeft * sliderProgress).clamp(0.0, maxLeft);

                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 40.h,
                                padding: EdgeInsets.symmetric(horizontal: 22.w),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22.r),
                                  border: Border.all(
                                    color: const Color(0xFFD6D6D6),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.of(dialogContext).pop(
                                          _ApprovalDialogDecision(
                                            isConfirmed: false,
                                            comment: commentController.text,
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'No',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFBA1719),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.of(dialogContext).pop(
                                          _ApprovalDialogDecision(
                                            isConfirmed: true,
                                            comment: commentController.text,
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Yes',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF009859),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: knobLeft,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onHorizontalDragUpdate: (details) {
                                    final delta = details.primaryDelta ?? 0;
                                    final next = sliderProgress +
                                        (delta /
                                            constraints.maxWidth
                                                .clamp(1.0, double.infinity));
                                    setModalState(() {
                                      sliderProgress = next.clamp(0.0, 1.0);
                                    });
                                  },
                                  onHorizontalDragEnd: (_) {
                                    if (sliderProgress >= 0.82) {
                                      Navigator.of(dialogContext).pop(
                                        _ApprovalDialogDecision(
                                          isConfirmed: true,
                                          comment: commentController.text,
                                        ),
                                      );
                                      return;
                                    }

                                    if (sliderProgress <= 0.18) {
                                      Navigator.of(dialogContext).pop(
                                        _ApprovalDialogDecision(
                                          isConfirmed: false,
                                          comment: commentController.text,
                                        ),
                                      );
                                      return;
                                    }

                                    setModalState(() {
                                      sliderProgress = 0.5;
                                    });
                                  },
                                  child: Container(
                                    width: knobSize,
                                    height: knobSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFE0E0E0),
                                      border: Border.all(
                                        color: const Color(0xFFCACACA),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        commentController.dispose();
      });
    });
  }

  Widget _buildCircleActionButton(BuildContext context, String label,
      Color color, IconData icon, TextEditingController commentController,
      {bool isSelected = false, bool listenToBloc = true}) {
    return BlocConsumer<ApprovalBloc, ApprovalState>(
      // Only listen when the state actually changes to prevent duplicate calls
      listenWhen: (previous, current) {
        if (!listenToBloc) return false;
        // Only trigger listener when transitioning to a new success/failure state
        if (current is ApprovalSuccess && previous is! ApprovalSuccess) {
          return true;
        }
        if (current is ApprovalFailure && previous is! ApprovalFailure) {
          return true;
        }
        return false;
      },
      listener: (ctx, state) {
        if (state is ApprovalSuccess) {
          // Close loading overlay first
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context); // Close loading overlay
          }

          // Call the onResult callback if provided
          if (onResult != null) {
            onResult!(state.message);
          }

          // Close main dialog - parent screen will handle refresh and count update
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context, true);

            // Show success message after dialog closes
            Future.delayed(const Duration(milliseconds: 100), () {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            });
          }
        } else if (state is ApprovalFailure) {
          // Close loading overlay first
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context); // Close loading overlay
          }

          // For failures, show error but don't close main dialog
          // User needs to see the error and decide what to do
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                duration: const Duration(seconds: 4),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      builder: (context, state) {
        final isLoading = state is ApprovalLoading;
        final isButtonDisabled = disabled || isLoading;

        return AnimatedCircleButton(
          onPressed: isButtonDisabled
              ? null
              : () async {
                  final token = SharedPref.getLoginData().result?.token ?? '';
                  String finalComment = '..';
                  if (useProvidedComment) {
                    finalComment = _resolveProvidedComment();
                  } else {
                    final String? comment =
                        await _showCommentDialog(context, label);

                    // If user cancelled the dialog or context is no longer valid, don't proceed
                    if (!context.mounted) return;
                    if (comment == null) return;

                    finalComment = comment;
                  }

                  // Show loading immediately after comment is submitted
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      barrierColor: Colors.black54,
                      builder: (BuildContext dialogContext) {
                        return PopScope(
                          canPop: false,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text(
                                    'Processing...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }

                  if (label == "APPROVE") {
                    context.read<ApprovalBloc>().add(
                          ApproveRequest(
                            requestId: requestId,
                            type: type,
                            token: token,
                            userIds: userIds,
                            comment: finalComment,
                          ),
                        );
                  } else if (label == "REJECT") {
                    context.read<ApprovalBloc>().add(
                          RejectRequest(
                            requestId: requestId,
                            type: type,
                            token: token,
                            userIds: userIds,
                            comment: finalComment,
                          ),
                        );
                  }
                },
          color: color,
          icon: icon,
          label: label,
          isLoading: isLoading,
          isDisabled: isButtonDisabled,
        );
      },
    );
  }

  Future<String?> _showCommentDialog(
      BuildContext context, String action) async {
    final TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible:
          false, // Prevent accidental dismissal by tapping outside
      builder: (ctx) {
        return AlertDialog(
          title: Text('$action Comment'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter your comment...',
              border: OutlineInputBorder(),
            ),
            minLines: 1,
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(), // Return null on cancel
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.of(ctx).pop(text.isEmpty ? '..' : text);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      // Dispose controller after a frame to ensure Flutter is done with it
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    });
  }
}

class _ApprovalDialogDecision {
  final bool isConfirmed;
  final String comment;

  const _ApprovalDialogDecision({
    required this.isConfirmed,
    required this.comment,
  });
}

enum ApprovalActionButtonsVariant {
  holdCircle,
  pill,
  rectangle,
}

class AnimatedCircleButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Color color;
  final IconData icon;
  final String label;
  final bool isLoading;
  final bool isDisabled;

  const AnimatedCircleButton({
    super.key,
    required this.onPressed,
    required this.color,
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.isDisabled,
  });

  @override
  State<AnimatedCircleButton> createState() => _AnimatedCircleButtonState();
}

class _AnimatedCircleButtonState extends State<AnimatedCircleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // how long to hold
    );

    // when animation completes → trigger action
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_hasTriggered) {
        if (widget.onPressed != null && !widget.isDisabled) {
          _hasTriggered = true;
          widget.onPressed!();
        }
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedCircleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset trigger flag when widget becomes enabled (e.g., after loading completes)
    if (oldWidget.isDisabled && !widget.isDisabled) {
      _hasTriggered = false;
    }
    // If widget becomes disabled while animation is running, stop it
    if (!oldWidget.isDisabled && widget.isDisabled) {
      if (_controller.isAnimating) {
        _controller.reverse();
        _hasTriggered = false;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.isDisabled && widget.onPressed != null && !_hasTriggered) {
      _controller.forward(from: 0); // restart animation
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_controller.status != AnimationStatus.completed) {
      _controller.reverse(); // released early → cancel
      _hasTriggered = false; // Reset flag if cancelled
    }
  }

  void _onTapCancel() {
    _controller.reverse();
    _hasTriggered = false; // Reset flag if cancelled
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: 80.w,
                height: 80.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color,
                    width: 3.w,
                  ),
                  color:
                      widget.color.withValues(alpha: _controller.value * 0.8),
                ),
                child: Center(
                    child: widget.isLoading
                        ? SizedBox(
                            width: 24.w,
                            height: 24.w,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const SizedBox.shrink()),
              );
            },
          ),
        ),
        SizedBox(height: 8.w),
        Text(
          "HOLD TO ${widget.label}",
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
            color: widget.isDisabled
                ? widget.color.withValues(alpha: 0.5)
                : widget.color,
          ),
        ),
      ],
    );
  }
}

class CircleFillPainter extends CustomPainter {
  final double fillProgress;
  final Color fillColor;

  CircleFillPainter({
    required this.fillProgress,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fillProgress <= 0) return;

    final paint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    final fillHeight = size.height * fillProgress;
    final startY = size.height - fillHeight;

    final rect = Rect.fromLTWH(0, startY, size.width, fillHeight);

    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    canvas.clipPath(path);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is CircleFillPainter &&
        (oldDelegate.fillProgress != fillProgress ||
            oldDelegate.fillColor != fillColor);
  }
}
