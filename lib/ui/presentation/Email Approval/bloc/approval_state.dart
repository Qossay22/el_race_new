import 'package:equatable/equatable.dart';

abstract class ApprovalState extends Equatable {
  final Set<int> expandedItems;
  const ApprovalState({this.expandedItems = const {}});
  @override
  List<Object?> get props => [expandedItems];
}

class ApprovalInitial extends ApprovalState {
  const ApprovalInitial({super.expandedItems});
}

class ApprovalLoading extends ApprovalState {
  const ApprovalLoading({super.expandedItems});
}

class ApprovalSuccess extends ApprovalState {
  final String message;
  const ApprovalSuccess(this.message, {super.expandedItems});
  @override
  List<Object?> get props => [message, expandedItems];
}

class ApprovalFailure extends ApprovalState {
  final String error;
  const ApprovalFailure(this.error, {super.expandedItems});
  @override
  List<Object?> get props => [error, expandedItems];
}

class ApprovalItemsExpanded extends ApprovalState {
  const ApprovalItemsExpanded({required super.expandedItems});
} 