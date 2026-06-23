part of 'attendance_bloc.dart';

abstract class AttendanceEvent extends Equatable {
  const AttendanceEvent();

  @override
  List<Object?> get props => [];
}

class GetAttendanceListET extends AttendanceEvent {
  final String? keyword;
  final int? month;
  final int? year;
  final int requestId;

  const GetAttendanceListET({
    this.keyword,
    this.month,
    this.year,
    this.requestId = 0,
  });

  @override
  List<Object?> get props => [keyword, month, year, requestId];
}

/// Event for non-manager: fetch own attendance via /api/attendance/detail
class GetSelfAttendanceET extends AttendanceEvent {
  final int employeeId;
  final int month;
  final int year;
  final int requestId;

  const GetSelfAttendanceET({
    required this.employeeId,
    required this.month,
    required this.year,
    this.requestId = 0,
  });

  @override
  List<Object?> get props => [employeeId, month, year, requestId];
}
