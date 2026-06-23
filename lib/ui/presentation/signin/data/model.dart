// To parse this JSON data, do
//
//     final loginResponseModel = loginResponseModelFromJson(jsonString);

import 'dart:convert';

LoginResponseModel loginResponseModelFromJson(String str) =>
    LoginResponseModel.fromJson(json.decode(str));

String loginResponseModelToJson(LoginResponseModel data) =>
    json.encode(data.toJson());

class LoginResponseModel {
  final String? jsonrpc;
  final dynamic id;
  final Result? result;

  LoginResponseModel({
    this.jsonrpc,
    this.id,
    this.result,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) =>
      LoginResponseModel(
        jsonrpc: json["jsonrpc"],
        id: json["id"],
        result: json["result"] == null ? null : Result.fromJson(json["result"]),
      );

  Map<String, dynamic> toJson() => {
        "jsonrpc": jsonrpc,
        "id": id,
        "result": result?.toJson(),
      };
}

class Result {
  final String? message;
  final bool? success;
  final Data? data;
  final String? token;

  Result({
    this.message,
    this.success,
    this.data,
    this.token,
  });

  factory Result.fromJson(Map<String, dynamic> json) => Result(
        message: json["message"],
        success: json["success"],
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
        token: json["token"],
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "success": success,
        "data": data?.toJson(),
        "token": token,
      };
}

class Data {
  final int? uid;
  final bool? isSystem;
  final bool? isAdmin;
  final bool? isAttendanceManager;
  final UserContext? userContext;
  final String? db;
  final String? serverVersion;
  final List<dynamic>? serverVersionInfo;
  final String? name;
  final String? image_url;
  final String? username;
  final String? job_id;
  final String? emp_id;
  final String? emp_profile_id;
  final String? emp_name;
  final int? role_id;
  final int? odoo_user_id;
  final int? employee_id;
  final int? holder_id;
  final String? firebase_uid;
  final String? firebase_custom_token;
  final String? partnerDisplayName;
  final int? companyId;
  final int? branchId;
  final int? partnerId;
  final String? leaveBalance;
  final String? webBaseUrl;
  final UserCompanies? userCompanies;
  final UserBranches? userBranches;
  final Map<String, Currency>? currencies;
  final bool? showEffect;
  final bool? displaySwitchCompanyMenu;
  final bool? displaySwitchBranchMenu;
  final CacheHashes? cacheHashes;
  final List<dynamic>? allowedBranchIds;
  final List<String>? roles;
  final bool? qr_status;
  final Map<String, dynamic>? certificate;
  final DefaultWidgets? defaultWidgets;
  final int? default_operating_unit_id;

  Data({
    this.uid,
    this.isSystem,
    this.isAdmin,
    this.isAttendanceManager,
    this.userContext,
    this.db,
    this.serverVersion,
    this.serverVersionInfo,
    this.name,
    this.image_url,
    this.username,
    this.job_id,
    this.emp_id,
    this.emp_profile_id,
    this.emp_name,
    this.role_id,
    this.odoo_user_id,
    this.employee_id,
    this.holder_id,
    this.firebase_uid,
    this.firebase_custom_token,
    this.partnerDisplayName,
    this.companyId,
    this.branchId,
    this.partnerId,
    this.leaveBalance,
    this.webBaseUrl,
    this.userCompanies,
    this.userBranches,
    this.currencies,
    this.showEffect,
    this.displaySwitchCompanyMenu,
    this.displaySwitchBranchMenu,
    this.cacheHashes,
    this.allowedBranchIds,
    this.roles,
    this.qr_status,
    this.certificate,
    this.defaultWidgets,
    this.default_operating_unit_id,
  });

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        uid: json["uid"],
        isSystem: json["is_system"],
        isAdmin: json["is_admin"],
        isAttendanceManager: json["is_attendance_manager"],
        userContext: json["user_context"] == null
            ? null
            : UserContext.fromJson(json["user_context"]),
        db: json["db"],
        serverVersion: json["server_version"],
        serverVersionInfo: json["server_version_info"] == null
            ? []
            : List<dynamic>.from(json["server_version_info"]!.map((x) => x)),
        name: (json["emp_name"] is String &&
                json["emp_name"].toString().isNotEmpty)
            ? json["emp_name"]
            : (json["name"] is String
                ? json["name"]
                : (json["partner_display_name"] is String
                    ? json["partner_display_name"]
                    : json["username"])),
        image_url: (json["image_url"] != null && json["image_url"] != false)
            ? json["image_url"].toString()
            : '',
        username: (json["username"] != null && json["username"] != false)
            ? json["username"].toString()
            : '',
        job_id: (json["job_id"] != null && json["job_id"] != false)
            ? json["job_id"].toString()
            : null,
        emp_id: (json["emp_id"] != null && json["emp_id"] != false)
            ? json["emp_id"].toString()
            : null,
        emp_profile_id:
            (json["emp_profile_id"] != null && json["emp_profile_id"] != false)
                ? json["emp_profile_id"].toString()
                : null,
        emp_name: (json["emp_name"] != null && json["emp_name"] != false)
            ? json["emp_name"].toString()
            : null,
        role_id: json["role_id"] is int
            ? json["role_id"]
            : int.tryParse(json["role_id"]?.toString() ?? ''),
        odoo_user_id: json["odoo_user_id"] is int
            ? json["odoo_user_id"]
            : (json["uid"] is int ? json["uid"] : null),
        employee_id: json["employee_id"] is int
            ? json["employee_id"]
            : (json["emp_id"] != null && json["emp_id"] != false
                ? int.tryParse(json["emp_id"].toString())
                : null),
        holder_id: json["holder_id"] is int
            ? json["holder_id"]
            : (json["holder_id"] is List &&
                    (json["holder_id"] as List).isNotEmpty &&
                    (json["holder_id"] as List).first is int)
                ? (json["holder_id"] as List).first as int
                : int.tryParse(json["holder_id"]?.toString() ?? ''),
        firebase_uid:
            (json["firebase_uid"] != null && json["firebase_uid"] != false)
                ? json["firebase_uid"].toString()
                : null,
        firebase_custom_token: (json["firebase_custom_token"] != null &&
                json["firebase_custom_token"] != false)
            ? json["firebase_custom_token"].toString()
            : null,
        partnerDisplayName: json["partner_display_name"],
        companyId: json["company_id"],
        branchId: (json["branch_id"] is int)
            ? json["branch_id"]
            : (json["branch_id"] is String
                ? int.tryParse(json["branch_id"])
                : null),
        partnerId: json["partner_id"],
        leaveBalance: _stringOrNull(
          json["leave_balance"] ??
              json["leaveBalance"] ??
              json["balance_leave"] ??
              json["remaining_leave_days"],
        ),
        webBaseUrl: json["web.base.url"],
        userCompanies: json["user_companies"] == null
            ? null
            : UserCompanies.fromJson(json["user_companies"]),
        userBranches: json["user_branches"] == null
            ? null
            : UserBranches.fromJson(json["user_branches"]),
        currencies: json["currencies"] == null
            ? null
            : Map.from(json["currencies"]!).map(
                (k, v) => MapEntry<String, Currency>(k, Currency.fromJson(v))),
        showEffect: json["show_effect"],
        displaySwitchCompanyMenu: json["display_switch_company_menu"],
        displaySwitchBranchMenu: json["display_switch_branch_menu"],
        cacheHashes: json["cache_hashes"] == null
            ? null
            : CacheHashes.fromJson(json["cache_hashes"]),
        allowedBranchIds: json["allowed_branch_ids"] == null
            ? []
            : List<dynamic>.from(json["allowed_branch_ids"]!.map((x) => x)),
        roles: json["roles"] == null
            ? []
            : List<String>.from(json["roles"]!.map((x) => x)),
        qr_status: json["qr_status"],
        certificate: json["certificate"] is Map
            ? Map<String, dynamic>.from(json["certificate"])
            : (json["certificate"] is String
                ? _tryDecodeCertificate(json["certificate"] as String)
                : null),
        defaultWidgets: json["default_widgets"] == null
            ? null
            : DefaultWidgets.fromJson(json["default_widgets"]),
        default_operating_unit_id: json["default_operating_unit_id"],
      );

  Map<String, dynamic> toJson() => {
        "uid": uid,
        "is_system": isSystem,
        "is_admin": isAdmin,
        "is_attendance_manager": isAttendanceManager,
        "user_context": userContext?.toJson(),
        "db": db,
        "server_version": serverVersion,
        "server_version_info": serverVersionInfo == null
            ? []
            : List<dynamic>.from(serverVersionInfo!.map((x) => x)),
        "name": name,
        "image_url": image_url,
        "username": username,
        "job_id": job_id,
        "emp_id": emp_id,
        "emp_profile_id": emp_profile_id,
        "emp_name": emp_name,
        "role_id": role_id,
        "odoo_user_id": odoo_user_id,
        "employee_id": employee_id,
        "holder_id": holder_id,
        "firebase_uid": firebase_uid,
        "firebase_custom_token": firebase_custom_token,
        "partner_display_name": partnerDisplayName,
        "company_id": companyId,
        "branch_id": branchId,
        "partner_id": partnerId,
        "leave_balance": leaveBalance,
        "web.base.url": webBaseUrl,
        "user_companies": userCompanies?.toJson(),
        "user_branches": userBranches?.toJson(),
        "currencies": currencies != null
            ? Map.from(currencies!)
                .map((k, v) => MapEntry<String, dynamic>(k, v.toJson()))
            : null,
        "show_effect": showEffect,
        "display_switch_company_menu": displaySwitchCompanyMenu,
        "display_switch_branch_menu": displaySwitchBranchMenu,
        "cache_hashes": cacheHashes?.toJson(),
        "allowed_branch_ids": allowedBranchIds == null
            ? []
            : List<dynamic>.from(allowedBranchIds!.map((x) => x)),
        "roles": roles == null ? [] : List<dynamic>.from(roles!.map((x) => x)),
        "qr_status": qr_status,
        "certificate": certificate,
        "default_widgets": defaultWidgets?.toJson(),
        "default_operating_unit_id": default_operating_unit_id,
      };

  static String? _stringOrNull(dynamic value) {
    if (value == null || value == false || value == true) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    if (lower == 'false' || lower == 'null') return null;
    return text;
  }
}

class CacheHashes {
  final String? loadMenus;
  final String? qweb;
  final String? translations;

  CacheHashes({
    this.loadMenus,
    this.qweb,
    this.translations,
  });

  factory CacheHashes.fromJson(Map<String, dynamic> json) => CacheHashes(
        loadMenus: json["load_menus"],
        qweb: json["qweb"],
        translations: json["translations"],
      );

  Map<String, dynamic> toJson() => {
        "load_menus": loadMenus,
        "qweb": qweb,
        "translations": translations,
      };
}

class Currency {
  final String? symbol;
  final String? position;
  final List<int>? digits;

  Currency({
    this.symbol,
    this.position,
    this.digits,
  });

  factory Currency.fromJson(Map<String, dynamic> json) => Currency(
        symbol: json["symbol"],
        position: json["position"],
        digits: json["digits"] == null
            ? []
            : List<int>.from(json["digits"]!.map((x) => x)),
      );

  Map<String, dynamic> toJson() => {
        "symbol": symbol,
        "position": position,
        "digits":
            digits == null ? [] : List<dynamic>.from(digits!.map((x) => x)),
      };
}

class UserBranches {
  final List<bool>? currentBranch;
  final List<dynamic>? allowedBranch;

  UserBranches({
    this.currentBranch,
    this.allowedBranch,
  });

  factory UserBranches.fromJson(Map<String, dynamic> json) => UserBranches(
        currentBranch: json["current_branch"] == null
            ? []
            : List<bool>.from(json["current_branch"]!.map((x) => x)),
        allowedBranch: json["allowed_branch"] == null
            ? []
            : List<dynamic>.from(json["allowed_branch"]!.map((x) => x)),
      );

  Map<String, dynamic> toJson() => {
        "current_branch": currentBranch == null
            ? []
            : List<dynamic>.from(currentBranch!.map((x) => x)),
        "allowed_branch": allowedBranch == null
            ? []
            : List<dynamic>.from(allowedBranch!.map((x) => x)),
      };
}

class UserCompanies {
  final List<dynamic>? currentCompany;
  final List<List<dynamic>>? allowedCompanies;

  UserCompanies({
    this.currentCompany,
    this.allowedCompanies,
  });

  factory UserCompanies.fromJson(Map<String, dynamic> json) => UserCompanies(
        currentCompany: json["current_company"] == null
            ? []
            : List<dynamic>.from(json["current_company"]!.map((x) => x)),
        allowedCompanies: json["allowed_companies"] == null
            ? []
            : List<List<dynamic>>.from(json["allowed_companies"]!
                .map((x) => List<dynamic>.from(x.map((x) => x)))),
      );

  Map<String, dynamic> toJson() => {
        "current_company": currentCompany == null
            ? []
            : List<dynamic>.from(currentCompany!.map((x) => x)),
        "allowed_companies": allowedCompanies == null
            ? []
            : List<dynamic>.from(allowedCompanies!
                .map((x) => List<dynamic>.from(x.map((x) => x)))),
      };
}

class UserContext {
  final int? mapWebsiteId;
  final int? routeMapWebsiteId;
  final int? routeStartPartnerId;
  final String? lang;
  final String? tz;
  final int? uid;

  UserContext({
    this.mapWebsiteId,
    this.routeMapWebsiteId,
    this.routeStartPartnerId,
    this.lang,
    this.tz,
    this.uid,
  });

  factory UserContext.fromJson(Map<String, dynamic> json) => UserContext(
        mapWebsiteId: json["map_website_id"],
        routeMapWebsiteId: json["route_map_website_id"],
        routeStartPartnerId: json["route_start_partner_id"],
        lang: json["lang"],
        tz: json["tz"],
        uid: json["uid"],
      );

  Map<String, dynamic> toJson() => {
        "map_website_id": mapWebsiteId,
        "route_map_website_id": routeMapWebsiteId,
        "route_start_partner_id": routeStartPartnerId,
        "lang": lang,
        "tz": tz,
        "uid": uid,
      };
}

class DefaultWidgets {
  final String? status;
  final String? message;
  final WidgetsData? data;

  DefaultWidgets({
    this.status,
    this.message,
    this.data,
  });

  factory DefaultWidgets.fromJson(Map<String, dynamic> json) => DefaultWidgets(
        status: json["status"]?.toString(),
        message: json["message"]?.toString(),
        data: json["data"] == null
            ? null
            : WidgetsData.fromJson(json["data"] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data?.toJson(),
      };
}

class WidgetsData {
  final WidgetInfo? attendanceWidget;
  final WidgetInfo? checkinWidget;
  final WidgetInfo? myRequestWidget;
  final WidgetInfo? myDocumentsWidget;
  final WidgetInfo? myProjectsWidget;
  final WidgetInfo? mediaWidget;
  final WidgetInfo? myReportsWidget;
  final WidgetInfo? timesheetWidget;
  final WidgetInfo? myNotesWidget;
  final WidgetInfo? lpoWidget;

  WidgetsData({
    this.attendanceWidget,
    this.checkinWidget,
    this.myRequestWidget,
    this.myDocumentsWidget,
    this.myProjectsWidget,
    this.mediaWidget,
    this.myReportsWidget,
    this.timesheetWidget,
    this.myNotesWidget,
    this.lpoWidget,
  });

  factory WidgetsData.fromJson(Map<String, dynamic> json) => WidgetsData(
        attendanceWidget: json["attendance_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["attendance_widget"] as Map<String, dynamic>),
      checkinWidget: json["checkin_widget"] == null
        ? null
        : WidgetInfo.fromJson(
          json["checkin_widget"] as Map<String, dynamic>),
        myRequestWidget: json["my_request_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["my_request_widget"] as Map<String, dynamic>),
        myDocumentsWidget: json["my_documents_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["my_documents_widget"] as Map<String, dynamic>),
        myProjectsWidget: json["my_projects_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["my_projects_widget"] as Map<String, dynamic>),
        mediaWidget: json["media_widget"] == null
            ? null
            : WidgetInfo.fromJson(json["media_widget"] as Map<String, dynamic>),
        myReportsWidget: json["my_reports_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["my_reports_widget"] as Map<String, dynamic>),
        timesheetWidget: json["timesheet_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["timesheet_widget"] as Map<String, dynamic>),
        myNotesWidget: json["my_notes_widget"] == null
            ? null
            : WidgetInfo.fromJson(
                json["my_notes_widget"] as Map<String, dynamic>),
        lpoWidget: json["lpo_widget"] == null
            ? null
            : WidgetInfo.fromJson(json["lpo_widget"] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        "attendance_widget": attendanceWidget?.toJson(),
      "checkin_widget": checkinWidget?.toJson(),
        "my_request_widget": myRequestWidget?.toJson(),
        "my_documents_widget": myDocumentsWidget?.toJson(),
        "my_projects_widget": myProjectsWidget?.toJson(),
        "media_widget": mediaWidget?.toJson(),
        "my_reports_widget": myReportsWidget?.toJson(),
        "timesheet_widget": timesheetWidget?.toJson(),
        "my_notes_widget": myNotesWidget?.toJson(),
        "lpo_widget": lpoWidget?.toJson(),
      };
}

/// Represents a single dashboard widget entry.
/// [recordToShow] may be an [int] or a [Map<String, dynamic>] depending on
/// the widget type – access the typed helpers for convenience.
class WidgetInfo {
  final int? widgetNumber;
  final String? widgetName;
  final dynamic recordToShow;
  final bool? isDisabled;

  WidgetInfo({
    this.widgetNumber,
    this.widgetName,
    this.recordToShow,
    this.isDisabled,
  });

  factory WidgetInfo.fromJson(Map<String, dynamic> json) => WidgetInfo(
        widgetNumber: json["widget_number"] is int
            ? json["widget_number"]
            : int.tryParse(json["widget_number"]?.toString() ?? ''),
        widgetName: json["widget_name"]?.toString(),
        recordToShow: json["record_to_show"],
        isDisabled: json["is_disabled"] is bool
            ? json["is_disabled"]
            : (json["is_disabled"]?.toString().toLowerCase() == 'true'),
      );

  Map<String, dynamic> toJson() => {
        "widget_number": widgetNumber,
        "widget_name": widgetName,
        "record_to_show": recordToShow,
        "is_disabled": isDisabled,
      };

  // ---------- typed helpers ----------

  /// Returns the numeric value of [recordToShow] when it is a plain number.
  int? get recordCount => recordToShow is int
      ? recordToShow as int
      : int.tryParse(recordToShow?.toString() ?? '');

  /// Returns [recordToShow] as a key→value map when it is an object.
  Map<String, dynamic>? get recordMap => recordToShow is Map
      ? Map<String, dynamic>.from(recordToShow as Map)
      : null;
}

// ── Typed record helpers ──────────────────────────────────────────────────────

class AttendanceRecord {
  final int present;
  final int absent;
  const AttendanceRecord({required this.present, required this.absent});
  factory AttendanceRecord.fromMap(Map<String, dynamic> m) =>
      AttendanceRecord(present: m["present"] ?? 0, absent: m["absent"] ?? 0);
  Map<String, dynamic> toJson() => {"present": present, "absent": absent};
}

class MyRequestRecord {
  final int totalRequestsCount;
  final int waitingForApprovalCount;
  const MyRequestRecord(
      {required this.totalRequestsCount,
      required this.waitingForApprovalCount});
  factory MyRequestRecord.fromMap(Map<String, dynamic> m) => MyRequestRecord(
      totalRequestsCount: m["total_requests_count"] ?? 0,
      waitingForApprovalCount: m["waiting_for_approval_count"] ?? 0);
  Map<String, dynamic> toJson() => {
        "total_requests_count": totalRequestsCount,
        "waiting_for_approval_count": waitingForApprovalCount
      };
}

class MyProjectsRecord {
  final int totalProjects;
  final int delayedProjects;
  const MyProjectsRecord(
      {required this.totalProjects, required this.delayedProjects});
  factory MyProjectsRecord.fromMap(Map<String, dynamic> m) => MyProjectsRecord(
      totalProjects: m["total_projects"] ?? 0,
      delayedProjects: m["delayed_projects"] ?? 0);
  Map<String, dynamic> toJson() =>
      {"total_projects": totalProjects, "delayed_projects": delayedProjects};
}

class MediaRecord {
  final int mediaCount;
  final int files;
  const MediaRecord({required this.mediaCount, required this.files});
  factory MediaRecord.fromMap(Map<String, dynamic> m) =>
      MediaRecord(mediaCount: m["media_count"] ?? 0, files: m["files"] ?? 0);
  Map<String, dynamic> toJson() => {"media_count": mediaCount, "files": files};
}

class MyNotesRecord {
  final int savedCount;
  final int draftCount;
  const MyNotesRecord({required this.savedCount, required this.draftCount});
  factory MyNotesRecord.fromMap(Map<String, dynamic> m) => MyNotesRecord(
      savedCount: m["saved_count"] ?? 0, draftCount: m["draft_count"] ?? 0);
  Map<String, dynamic> toJson() =>
      {"saved_count": savedCount, "draft_count": draftCount};
}

class LpoRecord {
  final int total;
  final int completed;
  const LpoRecord({required this.total, required this.completed});
  factory LpoRecord.fromMap(Map<String, dynamic> m) =>
      LpoRecord(total: m["total"] ?? 0, completed: m["completed"] ?? 0);
  Map<String, dynamic> toJson() => {"total": total, "completed": completed};
}

Map<String, dynamic>? _tryDecodeCertificate(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    // ignore malformed certificate payloads
  }
  return null;
}
