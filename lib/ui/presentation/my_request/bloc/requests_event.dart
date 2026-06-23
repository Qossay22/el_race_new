import 'package:equatable/equatable.dart';

abstract class RequestsEvent extends Equatable {
  const RequestsEvent();
  @override
  List<Object> get props => [];
}

class FetchRequestsCount extends RequestsEvent {
  const FetchRequestsCount();
} 