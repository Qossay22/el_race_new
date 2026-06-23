part of 'attendance_bloc.dart';

abstract class AttendanceState extends Equatable {
  const AttendanceState();

  @override
  List<Object?> get props => [];
}

class AttendanceInitial extends AttendanceState {}

class AttendanceLoadingState extends AttendanceState {
  final bool isLoading;

  const AttendanceLoadingState({required this.isLoading});

  @override
  List<Object?> get props => [isLoading];
}

class AttendanceDataLoaded extends AttendanceState {
  final Result attendanceData;

  const AttendanceDataLoaded({required this.attendanceData});

  @override
  List<Object?> get props => [attendanceData];
}

class AttendanceErrorState extends AttendanceState {
  final String message;

  const AttendanceErrorState({required this.message});

  @override
  List<Object?> get props => [message];
}
