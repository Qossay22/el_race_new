part of 'location_bloc.dart';

sealed class LocationState extends Equatable {
  const LocationState();
  @override
  List<Object> get props => [];
}

final class LocationInitial extends LocationState {}

class LocationError extends LocationState {
  final String message;
  const LocationError(this.message);

  @override
  List<Object> get props => [message];
}
