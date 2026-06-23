import 'package:equatable/equatable.dart';

abstract class RequestsState extends Equatable {
  const RequestsState();
  @override
  List<Object> get props => [];
}

class RequestsInitial extends RequestsState {}
class RequestsError extends RequestsState {
  final String message;
  const RequestsError(this.message);
  @override
  List<Object> get props => [message];
} 