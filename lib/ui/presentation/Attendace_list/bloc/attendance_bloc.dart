import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:equatable/equatable.dart';

import 'package:el_race/ui/presentation/Attendace_list/repository/attendance_repository.dart';
import 'package:el_race/ui/presentation/Attendace_list/model/attendance_model.dart';
import '../../../../../../utils/di.dart';

part 'attendance_event.dart';
part 'attendance_state.dart';

final _attendanceRepo = sl.get<AttendanceRepo>();

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  int _latestRequestId = 0;

  AttendanceBloc() : super(AttendanceInitial()) {
    on<GetAttendanceListET>(_getAttendanceMethod);
    on<GetSelfAttendanceET>(_getSelfAttendanceMethod);
  }

  Future<void> _getAttendanceMethod(
      GetAttendanceListET event, Emitter<AttendanceState> emit) async {
    _latestRequestId = event.requestId;
    log(
      'AttendanceBloc request -> requestId=${event.requestId}, keyword=${event.keyword}, month=${event.month}',
    );
    emit(const AttendanceLoadingState(isLoading: true));

    try {
      http.Response response = await _attendanceRepo.getAttendanceList(
        keyword: event.keyword,
        month: event.month,
        year: event.year,
      );

      if (response.statusCode == 200 &&
          (event.keyword?.trim().isNotEmpty ?? false) &&
          event.month != null) {
        try {
          final decoded = jsonDecode(response.body);
          final result =
              decoded is Map<String, dynamic> ? decoded['result'] : null;
          final apiStatus = result is Map<String, dynamic>
              ? (result['status']?.toString().toLowerCase() ?? '')
              : '';
          final apiMessage = result is Map<String, dynamic>
              ? (result['message']?.toString().toLowerCase() ?? '')
              : '';

          final shouldRetryWithoutMonth =
              apiStatus == 'error' && apiMessage.contains('employee not found');

          if (shouldRetryWithoutMonth) {
            log(
              'AttendanceBloc fallback -> requestId=${event.requestId}, retry without month for keyword=${event.keyword}',
            );
            response = await _attendanceRepo.getAttendanceList(
              keyword: event.keyword,
              month: null,
              year: event.year,
            );
          }
        } catch (_) {}
      }

      if (response.statusCode == 200) {
        _logFirstRecordStatusFields(response.body);
        final attendanceModel = attendanceModelFromJson(response.body);
        log(
          'AttendanceBloc parsed -> requestId=${event.requestId}, status=${attendanceModel.result.status}, mode=${attendanceModel.result.mode}, flatCount=${attendanceModel.result.data?.length ?? 0}, recordCount=${attendanceModel.result.records?.length ?? 0}',
        );
        if (event.requestId != _latestRequestId) return;
        emit(AttendanceDataLoaded(attendanceData: attendanceModel.result));
      } else {
        if (event.requestId != _latestRequestId) return;
        emit(AttendanceErrorState(
            message: 'Failed to load attendance: ${response.statusCode}'));
      }
    } catch (e) {
      if (event.requestId != _latestRequestId) return;
      emit(AttendanceErrorState(message: 'Error: ${e.toString()}'));
    }
  }

  Future<void> _getSelfAttendanceMethod(
      GetSelfAttendanceET event, Emitter<AttendanceState> emit) async {
    _latestRequestId = event.requestId;
    log(
      'AttendanceBloc selfAttendance -> requestId=${event.requestId}, employeeId=${event.employeeId}, month=${event.month}, year=${event.year}',
    );
    emit(const AttendanceLoadingState(isLoading: true));

    try {
      final response = await _attendanceRepo.getAttendanceDetail(
        empId: event.employeeId,
        month: event.month,
        year: event.year,
      );

      if (response.statusCode == 200) {
        _logFirstRecordStatusFields(response.body);
        final attendanceModel = attendanceModelFromJson(response.body);
        log(
          'AttendanceBloc selfAttendance parsed -> requestId=${event.requestId}, status=${attendanceModel.result.status}, mode=${attendanceModel.result.mode}, recordCount=${attendanceModel.result.records?.length ?? 0}',
        );
        if (event.requestId != _latestRequestId) return;
        emit(AttendanceDataLoaded(attendanceData: attendanceModel.result));
      } else {
        if (event.requestId != _latestRequestId) return;
        emit(AttendanceErrorState(
            message: 'Failed to load attendance: ${response.statusCode}'));
      }
    } catch (e) {
      if (event.requestId != _latestRequestId) return;
      emit(AttendanceErrorState(message: 'Error: ${e.toString()}'));
    }
  }

  void _logFirstRecordStatusFields(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        log('🧪 [ATTENDANCE_STATUS_DEBUG] Unexpected root type');
        return;
      }

      final result = decoded['result'];
      if (result is! Map<String, dynamic>) {
        log('🧪 [ATTENDANCE_STATUS_DEBUG] Missing result map');
        return;
      }

      Map<String, dynamic>? firstRecord;

      final directRecords = result['records'];
      if (directRecords is List && directRecords.isNotEmpty) {
        final first = directRecords.first;
        if (first is Map) {
          firstRecord = Map<String, dynamic>.from(first);
        }
      }

      final data = result['data'];
      if (firstRecord == null && data is List && data.isNotEmpty) {
        final first = data.first;
        if (first is Map) {
          firstRecord = Map<String, dynamic>.from(first);
        }
      }

      if (firstRecord == null && data is Map<String, dynamic>) {
        for (final key in const ['records', 'data', 'items']) {
          final list = data[key];
          if (list is List && list.isNotEmpty) {
            final first = list.first;
            if (first is Map) {
              firstRecord = Map<String, dynamic>.from(first);
              break;
            }
          }
        }
      }

      if (firstRecord == null) {
        log('🧪 [ATTENDANCE_STATUS_DEBUG] No first record found');
        return;
      }

      final statusEntries = firstRecord.entries.where((entry) {
        final key = entry.key.toLowerCase();
        return key.contains('status') || key.contains('state');
      }).toList();

      log('🧪 [ATTENDANCE_STATUS_DEBUG] First record keys: ${firstRecord.keys.toList()}');

      if (statusEntries.isEmpty) {
        log('🧪 [ATTENDANCE_STATUS_DEBUG] No status-like keys in first record');
        return;
      }

      for (final entry in statusEntries) {
        log('🧪 [ATTENDANCE_STATUS_DEBUG] ${entry.key} = ${entry.value}');
      }
    } catch (e) {
      log('🧪 [ATTENDANCE_STATUS_DEBUG] Parse error: $e');
    }
  }
}
