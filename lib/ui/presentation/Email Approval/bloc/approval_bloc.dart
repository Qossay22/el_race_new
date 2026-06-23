import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'approval_event.dart';
import 'approval_state.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApprovalBloc extends Bloc<ApprovalEvent, ApprovalState> {
  ApprovalBloc() : super(const ApprovalInitial()) {
    on<ApproveRequest>(_onApproveRequest);
    on<RejectRequest>(_onRejectRequest);
    on<ToggleItemExpansion>(_onToggleItemExpansion);
    on<CollapseItem>(_onCollapseItem);
  }

  bool _statusLooksSuccessful(dynamic status) {
    if (status == null) return false;
    if (status is bool) return status;
    if (status is num) return status > 0;
    final normalized = status.toString().trim().toLowerCase();
    return normalized == 'success' ||
        normalized == 'ok' ||
        normalized == 'approved' ||
        normalized == 'approve' ||
        normalized == 'accepted' ||
        normalized == 'accept' ||
        normalized == 'done' ||
        normalized == 'true' ||
        normalized == '1';
  }

  bool _messageLooksSuccessful(String message) {
    final normalized = message.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    const failureHints = [
      'error',
      'failed',
      'failure',
      'invalid',
      'not allowed',
      'permission',
      'denied',
      'no pending',
      'cannot',
    ];
    if (failureHints.any(normalized.contains)) {
      return false;
    }

    const successHints = [
      'success',
      'approved',
      'accepted',
      'done',
      'completed',
      'updated',
    ];
    return successHints.any(normalized.contains);
  }

  String _extractMessage(dynamic payload) {
    if (payload == null) return '';

    if (payload is String) {
      return payload.trim();
    }

    if (payload is List) {
      final joined = payload
          .map((e) => _extractMessage(e))
          .where((s) => s.isNotEmpty)
          .join(' | ');
      return joined.trim();
    }

    if (payload is Map) {
      final map = payload.cast<dynamic, dynamic>();

      final directKeys = [
        'message',
        'msg',
        'detail',
        'error',
        'error_message',
        'warning',
      ];

      for (final key in directKeys) {
        if (map.containsKey(key)) {
          final nested = _extractMessage(map[key]);
          if (nested.isNotEmpty) return nested;
        }
      }

      if (map.containsKey('data')) {
        final nested = _extractMessage(map['data']);
        if (nested.isNotEmpty) return nested;
      }
    }

    return payload.toString().trim();
  }

  _ApprovalApiResult _parseApprovalResponse(dynamic decodedBody) {
    if (decodedBody is! Map) {
      return const _ApprovalApiResult(
        isSuccess: false,
        message: 'Invalid server response format.',
      );
    }

    final body = decodedBody.cast<dynamic, dynamic>();

    if (body['error'] != null) {
      final msg = _extractMessage(body['error']);
      return _ApprovalApiResult(
        isSuccess: false,
        message: msg.isNotEmpty ? msg : 'Server returned an error.',
      );
    }

    final result = body['result'];
    if (result == null) {
      return const _ApprovalApiResult(
        isSuccess: false,
        message: 'Empty server result.',
      );
    }

    if (result is bool) {
      return _ApprovalApiResult(
        isSuccess: result,
        message: result ? 'Request processed successfully.' : 'Request failed.',
      );
    }

    if (result is Map) {
      final resultMap = result.cast<dynamic, dynamic>();

      if (resultMap['error'] != null) {
        final msg = _extractMessage(resultMap['error']);
        return _ApprovalApiResult(
          isSuccess: false,
          message: msg.isNotEmpty ? msg : 'Server returned an error.',
        );
      }

      final status =
          resultMap['status'] ?? resultMap['success'] ?? resultMap['ok'];
      final message = _extractMessage(resultMap);

      if (_statusLooksSuccessful(status)) {
        return _ApprovalApiResult(
          isSuccess: true,
          message:
              message.isNotEmpty ? message : 'Request processed successfully.',
        );
      }

      if (status == null && _messageLooksSuccessful(message)) {
        return _ApprovalApiResult(
          isSuccess: true,
          message: message,
        );
      }

      return _ApprovalApiResult(
        isSuccess: false,
        message: message.isNotEmpty
            ? message
            : 'Request was not accepted by server.',
      );
    }

    final message = _extractMessage(result);
    if (_messageLooksSuccessful(message)) {
      return _ApprovalApiResult(
        isSuccess: true,
        message: message,
      );
    }

    return _ApprovalApiResult(
      isSuccess: false,
      message: message.isNotEmpty ? message : 'Request failed.',
    );
  }

  String _normalizeTypeToken(String type) {
    return type.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String _resolveModelName(String type) {
    final normalized = _normalizeTypeToken(type);
    switch (normalized) {
      case 'PETTYCASH':
      case 'PETTYCASHSHEET':
      case 'EXPENSE':
        return 'hr.expense.sheet';
      case 'RFQ':
      case 'PO':
      case 'LPO':
      case 'PURCHASEORDER':
      case 'PURCHASE':
        return 'purchase.order';
      case 'INVOICE':
      case 'BILL':
      case 'ACCOUNTMOVE':
        return 'account.move';
      default:
        return type.toLowerCase().replaceAll(' ', '.');
    }
  }

  List<String> _resolveApproveActions(String type) {
    final normalized = _normalizeTypeToken(type);
    if (normalized == 'HR') {
      return const ['accept'];
    }
    // Different models/endpoints may expect one of these values.
    return const ['approve', 'accept'];
  }

  Future<http.Response> _sendApprovalRequest({
    required String userId,
    required String requestId,
    required String action,
    required String? comment,
    required String type,
  }) async {
    final token = SharedPref.getLoginData().result?.token;

    // Determine the correct API endpoint based on type
    String apiUrl;
    Map<String, dynamic> params;
    final parsedRequestId = int.tryParse(requestId);
    final parsedUserId = int.tryParse(userId);
    final normalizedType = _normalizeTypeToken(type);

    if (parsedRequestId == null) {
      throw Exception('Invalid request id: $requestId');
    }

    if (normalizedType == 'HR') {
      // HR requests use the existing endpoint
      apiUrl = 'https://erp.elrace.com/api/approve_reject_hr_request';
      params = {
        "user_id": parsedUserId ?? userId,
        "emp_request_id": parsedRequestId,
        "action": action,
        "comment": comment,
      };
    } else {
      // RFQ, Invoice, Petty Cash, LPO use tier review endpoint
      apiUrl = 'https://erp.elrace.com/api/record/tier_review';

      final modelName = _resolveModelName(type);

      params = {
        "model_name": modelName,
        "record_id": parsedRequestId,
        "action": action,
        "user_id": parsedUserId ?? userId,
        "comment": comment ?? "",
      };
    }

    final url = Uri.parse(apiUrl);
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };
    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": params,
    });

    debugPrint(
      '🚀 [ApprovalBloc] Request -> type=$type, userId=$userId, requestId=$requestId, action=$action, api=$apiUrl',
    );
    debugPrint('🧾 [ApprovalBloc] Payload: $body');

    return await http.post(url, headers: headers, body: body);
  }

  Future<void> _onApproveRequest(
      ApproveRequest event, Emitter<ApprovalState> emit) async {
    final currentExpandedItems = state.expandedItems;
    emit(ApprovalLoading(expandedItems: currentExpandedItems));
    try {
      debugPrint(
        '🟢 [ApprovalBloc] Approve started -> type=${event.type}, requestId=${event.requestId}, users=${event.userIds}',
      );
      final List<String> userIds = event.userIds;
      List<String> successMessages = [];
      List<String> failureMessages = [];
      final actionCandidates = _resolveApproveActions(event.type);

      for (final userId in userIds) {
        try {
          bool userApproved = false;
          String failureReason = 'Unknown response from server';

          for (var i = 0; i < actionCandidates.length; i++) {
            final action = actionCandidates[i];
            final isLastAttempt = i == actionCandidates.length - 1;

            final response = await _sendApprovalRequest(
              userId: userId,
              requestId: event.requestId,
              action: action,
              comment: event.comment ?? "Request approved.",
              type: event.type,
            );

            // Check HTTP status code first
            if (response.statusCode != 200) {
              failureReason =
                  'Server error (${response.statusCode}) [action=$action]';
              debugPrint('❌ [ApprovalBloc] HTTP Error: $failureReason');
              debugPrint('❌ [ApprovalBloc] Body: ${response.body}');

              if (!isLastAttempt) {
                debugPrint(
                  '↩️ [ApprovalBloc] Retrying approve with next action for user=$userId',
                );
                continue;
              }
              break;
            }

            // Try to parse JSON, catch FormatException if HTML is returned
            dynamic data;
            try {
              data = jsonDecode(response.body);
            } on FormatException {
              failureReason = 'Invalid server response [action=$action]';
              debugPrint(
                '❌ [ApprovalBloc] FormatException: body is not JSON for action=$action',
              );
              debugPrint(
                '❌ [ApprovalBloc] Raw: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}',
              );

              if (!isLastAttempt) {
                debugPrint(
                  '↩️ [ApprovalBloc] Retrying approve with next action for user=$userId',
                );
                continue;
              }
              break;
            }

            final parsed = _parseApprovalResponse(data);
            debugPrint(
              '🧪 [ApprovalBloc] Approve parse -> user=$userId, action=$action, success=${parsed.isSuccess}, message=${parsed.message}',
            );

            if (parsed.isSuccess) {
              userApproved = true;
              successMessages.add(parsed.message);
              break;
            }

            failureReason = '${parsed.message} [action=$action]';
            if (!isLastAttempt) {
              debugPrint(
                '↩️ [ApprovalBloc] Retrying approve with next action for user=$userId',
              );
            }
          }

          if (!userApproved) {
            failureMessages.add('User $userId: $failureReason');
          }
        } catch (e) {
          debugPrint('❌ [ApprovalBloc] Approve error for user $userId: $e');
          failureMessages.add("User $userId: ${e.toString()}");
        }
      }

      // Determine final state based on results
      if (successMessages.isNotEmpty && failureMessages.isEmpty) {
        // All succeeded
        debugPrint('✅ [ApprovalBloc] Approve success for all users');
        emit(ApprovalSuccess(successMessages.join("\n"),
            expandedItems: currentExpandedItems));
      } else if (successMessages.isEmpty && failureMessages.isNotEmpty) {
        // All failed
        debugPrint('❌ [ApprovalBloc] Approve failed for all users');
        emit(ApprovalFailure(failureMessages.join("\n"),
            expandedItems: currentExpandedItems));
      } else if (successMessages.isNotEmpty && failureMessages.isNotEmpty) {
        // Partial success - treat as success but show warning
        final message =
            "Partial Success:\n${successMessages.join("\n")}\n\nWarnings:\n${failureMessages.join("\n")}";
        debugPrint('⚠️ [ApprovalBloc] Approve partial success');
        emit(ApprovalSuccess(message, expandedItems: currentExpandedItems));
      } else {
        // No users processed (shouldn't happen)
        debugPrint('❌ [ApprovalBloc] Approve no users processed');
        emit(ApprovalFailure("No users to process.",
            expandedItems: currentExpandedItems));
      }
    } catch (e) {
      debugPrint('❌ Approval Error: $e');
      // Provide user-friendly error message
      String errorMessage;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection')) {
        errorMessage = "Network error. Please check your internet connection.";
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = "Request timeout. Please try again.";
      } else {
        errorMessage = "An error occurred: ${e.toString()}";
      }
      emit(ApprovalFailure(errorMessage, expandedItems: currentExpandedItems));
    }
  }

  Future<void> _onRejectRequest(
      RejectRequest event, Emitter<ApprovalState> emit) async {
    final currentExpandedItems = state.expandedItems;
    emit(ApprovalLoading(expandedItems: currentExpandedItems));
    try {
      debugPrint(
        '🔴 [ApprovalBloc] Reject started -> type=${event.type}, requestId=${event.requestId}, users=${event.userIds}',
      );
      final List<String> userIds = event.userIds;
      List<String> successMessages = [];
      List<String> failureMessages = [];

      for (final userId in userIds) {
        try {
          final response = await _sendApprovalRequest(
            userId: userId,
            requestId: event.requestId,
            action: "reject",
            comment: event.comment ?? "Request rejected.",
            type: event.type,
          );

          // Check HTTP status code first
          if (response.statusCode != 200) {
            debugPrint(
                '❌ HTTP Error: ${response.statusCode}\n${response.body}');
            failureMessages
                .add("User $userId: Server error (${response.statusCode})");
            continue; // Continue to next user instead of returning
          }

          // Try to parse JSON, catch FormatException if HTML is returned
          dynamic data;
          try {
            data = jsonDecode(response.body);
          } on FormatException {
            debugPrint(
                '❌ FormatException: Server returned HTML instead of JSON\n${response.body.substring(0, 200)}...');
            failureMessages.add("User $userId: Invalid server response");
            continue; // Continue to next user
          }

          debugPrint('🧾 [ApprovalBloc] Reject raw: ${response.body}');
          final parsed = _parseApprovalResponse(data);
          debugPrint(
            '🧪 [ApprovalBloc] Reject parse -> user=$userId, success=${parsed.isSuccess}, message=${parsed.message}',
          );
          if (parsed.isSuccess) {
            successMessages.add(parsed.message);
          } else {
            failureMessages.add("User $userId: ${parsed.message}");
          }
        } catch (e) {
          debugPrint('❌ Error for user $userId: $e');
          failureMessages.add("User $userId: ${e.toString()}");
        }
      }

      // Determine final state based on results
      if (successMessages.isNotEmpty && failureMessages.isEmpty) {
        // All succeeded
        debugPrint('✅ [ApprovalBloc] Reject success for all users');
        emit(ApprovalSuccess(successMessages.join("\n"),
            expandedItems: currentExpandedItems));
      } else if (successMessages.isEmpty && failureMessages.isNotEmpty) {
        // All failed
        debugPrint('❌ [ApprovalBloc] Reject failed for all users');
        emit(ApprovalFailure(failureMessages.join("\n"),
            expandedItems: currentExpandedItems));
      } else if (successMessages.isNotEmpty && failureMessages.isNotEmpty) {
        // Partial success - treat as success but show warning
        final message =
            "Partial Success:\n${successMessages.join("\n")}\n\nWarnings:\n${failureMessages.join("\n")}";
        debugPrint('⚠️ [ApprovalBloc] Reject partial success');
        emit(ApprovalSuccess(message, expandedItems: currentExpandedItems));
      } else {
        // No users processed (shouldn't happen)
        debugPrint('❌ [ApprovalBloc] Reject no users processed');
        emit(ApprovalFailure("No users to process.",
            expandedItems: currentExpandedItems));
      }
    } catch (e) {
      debugPrint('❌ Rejection Error: $e');
      // Provide user-friendly error message
      String errorMessage;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection')) {
        errorMessage = "Network error. Please check your internet connection.";
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = "Request timeout. Please try again.";
      } else {
        errorMessage = "An error occurred: ${e.toString()}";
      }
      emit(ApprovalFailure(errorMessage, expandedItems: currentExpandedItems));
    }
  }

  void _onToggleItemExpansion(
      ToggleItemExpansion event, Emitter<ApprovalState> emit) {
    final currentExpandedItems = Set<int>.from(state.expandedItems);

    if (currentExpandedItems.contains(event.index)) {
      currentExpandedItems.remove(event.index);
    } else {
      currentExpandedItems.add(event.index);
      // Auto-collapse after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        add(CollapseItem(event.index));
      });
    }

    emit(ApprovalItemsExpanded(expandedItems: currentExpandedItems));
  }

  void _onCollapseItem(CollapseItem event, Emitter<ApprovalState> emit) {
    final currentExpandedItems = Set<int>.from(state.expandedItems);
    currentExpandedItems.remove(event.index);
    emit(ApprovalItemsExpanded(expandedItems: currentExpandedItems));
  }
}

class _ApprovalApiResult {
  final bool isSuccess;
  final String message;

  const _ApprovalApiResult({
    required this.isSuccess,
    required this.message,
  });
}
