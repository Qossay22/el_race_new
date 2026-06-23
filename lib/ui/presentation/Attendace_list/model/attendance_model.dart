import 'dart:convert';

AttendanceModel attendanceModelFromJson(String str) =>
    AttendanceModel.fromJson(json.decode(str));

String attendanceModelToJson(AttendanceModel data) =>
    json.encode(data.toJson());

class AttendanceModel {
  AttendanceModel({
    required this.result,
  });

  final Result result;

  factory AttendanceModel.fromJson(Map<String, dynamic> json) =>
      AttendanceModel(
        result: Result.fromJson(json["result"]),
      );

  Map<String, dynamic> toJson() => {
        "result": result.toJson(),
      };
}

class Result {
  Result({
    required this.status,
    required this.mode,
    this.userType,
    this.role,
    this.employeeId,
    this.employeeName,
    this.employeeImageUrl,
    this.month,
    this.year,
    this.totalWorkingDays,
    this.totalPresentDays,
    this.records,
    this.data,
    this.monthlyEmployees,
    this.total,
    this.limit,
    this.offset,
  });

  final String status;
  final String mode;

  /// "manager", "management", or "user"
  final String? userType;
  final String? role;

  // For grouped mode (employee view)
  final int? employeeId;
  final String? employeeName;
  final String? employeeImageUrl;
  final int? month;
  final int? year;
  final int? totalWorkingDays;
  final int? totalPresentDays;
  final List<AttendanceRecord>? records;

  // For flat mode (manager/x_attendance view)
  final List<FlatAttendanceData>? data;

  // For management list view (/api/attendance/list with employees array)
  final List<EmployeeMonthlyAttendance>? monthlyEmployees;

  final int? total;
  final int? limit;
  final int? offset;

  /// Returns true when the user is a manager or management role.
  bool get isManagerRole {
    final type = (userType ?? '').toLowerCase().trim();
    final r = (role ?? '').toLowerCase().trim();
    return type == 'manager' || type == 'management' ||
        r == 'manager' || r == 'management';
  }

  factory Result.fromJson(Map<String, dynamic> json) {
    final mode = json["mode"] ?? "grouped";
    final userType = json["user_type"]?.toString();
    final role = json["role"]?.toString();

    // Management list view: has employees array (from /api/attendance/list)
    if (json["employees"] is List) {
      return Result(
        status: json["status"] ?? "",
        mode: mode,
        userType: userType,
        role: role,
        total: json["total_employees"] is int
            ? json["total_employees"]
            : int.tryParse(json["total_employees"]?.toString() ?? ''),
        limit: json["limit"],
        offset: json["offset"],
        monthlyEmployees: List<EmployeeMonthlyAttendance>.from(
            json["employees"].map((x) => EmployeeMonthlyAttendance.fromJson(x))),
      );
    }

    if (mode == "flat") {
      // Manager view - flat list (legacy /api/x_attendance/list)
      return Result(
        status: json["status"] ?? "",
        mode: mode,
        userType: userType,
        role: role,
        total: json["total"],
        limit: json["limit"],
        offset: json["offset"],
        data: json["data"] == null
            ? []
            : List<FlatAttendanceData>.from(
                json["data"].map((x) => FlatAttendanceData.fromJson(x))),
      );
    } else {
      // Single employee grouped detail view
      return Result(
        status: json["status"] ?? "",
        mode: mode,
        userType: userType,
        role: role,
        employeeId: json["employee_id"] ?? 0,
        employeeName: json["employee_name"] ?? "",
        employeeImageUrl: json["employee_image_url"] ?? "",
        month: json["month"] ?? 0,
        year: json["year"] ?? 0,
        totalWorkingDays: json["total_working_days"] ?? 0,
        totalPresentDays: json["total_present_days"] ?? 0,
        records: json["records"] == null
            ? []
            : List<AttendanceRecord>.from(
                json["records"].map((x) => AttendanceRecord.fromJson(x))),
      );
    }
  }

  Map<String, dynamic> toJson() {
    if (mode == "flat") {
      return {
        "status": status,
        "mode": mode,
        "user_type": userType,
        "role": role,
        "total": total,
        "limit": limit,
        "offset": offset,
        "data": data == null
            ? []
            : List<dynamic>.from(data!.map((x) => x.toJson())),
      };
    } else {
      return {
        "status": status,
        "mode": mode,
        "user_type": userType,
        "role": role,
        "employee_id": employeeId,
        "employee_name": employeeName,
        "employee_image_url": employeeImageUrl,
        "month": month,
        "year": year,
        "total_working_days": totalWorkingDays,
        "total_present_days": totalPresentDays,
        "records": records == null
            ? []
            : List<dynamic>.from(records!.map((x) => x.toJson())),
      };
    }
  }
}

/// Monthly attendance summary for a single employee (from /api/attendance/list).
class EmployeeMonthlyAttendance {
  EmployeeMonthlyAttendance({
    required this.employeeId,
    required this.employeeName,
    required this.employeeImageUrl,
    required this.month,
    required this.year,
    required this.totalWorkingDays,
    required this.totalPresentDays,
    required this.totalAbsentDays,
  });

  final int employeeId;
  final String employeeName;
  final String? employeeImageUrl;
  final int month;
  final int year;
  final int totalWorkingDays;
  final int totalPresentDays;
  final int totalAbsentDays;

  factory EmployeeMonthlyAttendance.fromJson(Map<String, dynamic> json) =>
      EmployeeMonthlyAttendance(
        employeeId: json["employee_id"] ?? 0,
        employeeName: json["employee_name"] ?? "",
        employeeImageUrl: json["employee_image_url"]?.toString(),
        month: json["month"] ?? 0,
        year: json["year"] ?? 0,
        totalWorkingDays: json["total_working_days"] ?? 0,
        totalPresentDays: json["total_present_days"] ?? 0,
        totalAbsentDays: json["total_absent_days"] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        "employee_id": employeeId,
        "employee_name": employeeName,
        "employee_image_url": employeeImageUrl,
        "month": month,
        "year": year,
        "total_working_days": totalWorkingDays,
        "total_present_days": totalPresentDays,
        "total_absent_days": totalAbsentDays,
      };
}

// For flat mode (manager view)
class FlatAttendanceData {
  FlatAttendanceData({
    required this.employeeName,
    required this.empId,
    required this.employeeImageUrl,
    required this.checkIn,
    required this.checkOut,
    required this.workedHours,
    required this.isOpen,
    this.status,
    this.checkInStatus,
    this.checkOutStatus,
    this.attendanceType,
  });

  final String employeeName;
  final String empId;
  final String employeeImageUrl;
  final String checkIn;
  final dynamic checkOut;
  final double workedHours;
  final bool isOpen;
  final String? status;
  final String? checkInStatus;
  final String? checkOutStatus;
  final String? attendanceType;

  factory FlatAttendanceData.fromJson(Map<String, dynamic> json) =>
      FlatAttendanceData(
        employeeName: json["employee_name"] ?? "",
        empId: (json["emp_id"] ?? json["employee_id"]?.toString() ?? "").toString(),
        employeeImageUrl: json["employee_image_url"] ?? "",
        checkIn: json["check_in"] ?? "",
        checkOut: json["check_out"],
        workedHours: (json["worked_hours"] ?? 0.0).toDouble(),
        isOpen: json["is_open"] ?? false,
        status: _firstNonEmptyString(const [
          'status',
          'attendance_status',
          'state',
        ], json),
        checkInStatus: _firstNonEmptyString(const [
          'check_in_status',
          'checkin_status',
          'in_status',
        ], json),
        checkOutStatus: _firstNonEmptyString(const [
          'check_out_status',
          'checkout_status',
          'out_status',
        ], json),
        attendanceType: _firstNonEmptyString(const [
          'x_attendance_type',
          'attendance_type',
        ], json),
      );

  Map<String, dynamic> toJson() => {
        "employee_name": employeeName,
        "emp_id": empId,
        "employee_image_url": employeeImageUrl,
        "check_in": checkIn,
        "check_out": checkOut,
        "worked_hours": workedHours,
        "is_open": isOpen,
        "status": status,
        "check_in_status": checkInStatus,
        "check_out_status": checkOutStatus,
        "x_attendance_type": attendanceType,
      };
}

class AttendanceRecord {
  AttendanceRecord({
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.workedHours,
    this.status,
    this.checkInStatus,
    this.checkOutStatus,
    this.attendanceType,
  });

  final String date;
  final String checkIn;
  final dynamic checkOut;
  final double workedHours;
  final String? status;
  final String? checkInStatus;
  final String? checkOutStatus;
  final String? attendanceType;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        date: json["date"] ?? "",
        checkIn: json["check_in"] ?? "",
        checkOut: json["check_out"],
        workedHours: (json["worked_hours"] ?? 0.0).toDouble(),
        status: _firstNonEmptyString(const [
          'status',
          'attendance_status',
          'state',
        ], json),
        checkInStatus: _firstNonEmptyString(const [
          'check_in_status',
          'checkin_status',
          'in_status',
        ], json),
        checkOutStatus: _firstNonEmptyString(const [
          'check_out_status',
          'checkout_status',
          'out_status',
        ], json),
        attendanceType: _firstNonEmptyString(const [
          'x_attendance_type',
          'attendance_type',
        ], json),
      );

  Map<String, dynamic> toJson() => {
        "date": date,
        "check_in": checkIn,
        "check_out": checkOut,
        "worked_hours": workedHours,
        "status": status,
        "check_in_status": checkInStatus,
        "check_out_status": checkOutStatus,
        "x_attendance_type": attendanceType,
      };
}

String? _firstNonEmptyString(List<String> keys, Map<String, dynamic> source) {
  for (final key in keys) {
    final value = source[key];
    if (value == null || value == false) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}
