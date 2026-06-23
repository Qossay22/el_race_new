import 'package:equatable/equatable.dart';

abstract class ApprovalEvent extends Equatable {
  const ApprovalEvent();
  @override
  List<Object?> get props => [];
}

class ApproveRequest extends ApprovalEvent {
  final String requestId;
  final String type;
  final String token;
  final List<String> userIds;
  final String? comment;
  const ApproveRequest(
      {required this.requestId,
      required this.type,
      required this.token,
      required this.userIds,
      this.comment});
  @override
  List<Object?> get props => [requestId, type, token, userIds, comment];
}

class RejectRequest extends ApprovalEvent {
  final String requestId;
  final String type;
  final String token;
  final List<String> userIds;
  final String? comment;
  const RejectRequest(
      {required this.requestId,
      required this.type,
      required this.token,
      required this.userIds,
      this.comment});
  @override
  List<Object?> get props => [requestId, type, token, userIds, comment];
}

class ToggleItemExpansion extends ApprovalEvent {
  final int index;
  const ToggleItemExpansion(this.index);
  @override
  List<Object?> get props => [index];
}

class CollapseItem extends ApprovalEvent {
  final int index;
  const CollapseItem(this.index);
  @override
  List<Object?> get props => [index];
}
