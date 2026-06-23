import 'package:cloud_firestore/cloud_firestore.dart';
import 'task_member_model.dart';

class TodoModel {
  final int? id; // Local SQLite ID (deprecated)
  final String? firebaseId; // Firebase document ID
  final String? ownerUid; // Owner user document ID in Firestore
  final String title;
  final String? description;
  final bool isCompleted;
  final bool isImportant;
  final bool isMyDay;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String? assignedTo;
  final String? assignedToName; // Name of the assigned member (legacy)
  final List<TaskMember>?
      assignedMembers; // List of assigned members with status
  final List<TaskMember>? followedUpBy; // List of followers with status
  final List<String>? followers; // Names of followers (legacy)
  final List<String>? attachments; // Attachment file paths/names
  final String? listId; // Firebase list ID (changed from int)
  final String? reportId; // Reference to Report
  final int? teamId; // Team/Department ID from ERP
  final String? department; // Department name
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TodoModel({
    this.id,
    this.firebaseId,
    this.ownerUid,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.isImportant = false,
    this.isMyDay = false,
    this.startDate,
    this.dueDate,
    this.assignedTo,
    this.assignedToName,
    this.assignedMembers,
    this.followedUpBy,
    this.followers,
    this.attachments,
    this.listId,
    this.reportId,
    this.teamId,
    this.department,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Calculate progress based on assigned members completion
  double get progress {
    if (assignedMembers == null || assignedMembers!.isEmpty) {
      return isCompleted ? 1.0 : 0.0;
    }
    final completed = assignedMembers!.where((m) => m.isCompleted).length;
    return completed / assignedMembers!.length;
  }

  /// Get progress percentage string
  String get progressText {
    return '${(progress * 100).toInt()}%';
  }

  factory TodoModel.fromMap(Map<String, dynamic> map) {
    return TodoModel(
      id: map['id'] as int?,
      firebaseId: map['firebase_id'] as String?,
      ownerUid: map['owner_uid'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      isCompleted: (map['is_completed'] as int?) == 1,
      isImportant: (map['is_important'] as int?) == 1,
      isMyDay: (map['is_my_day'] as int?) == 1,
      startDate: map['start_date'] != null
          ? DateTime.parse(map['start_date'] as String)
          : null,
      dueDate: map['due_date'] != null
          ? DateTime.parse(map['due_date'] as String)
          : null,
      assignedTo: map['assigned_to'] as String?,
      assignedToName: map['assigned_to_name'] as String?,
      assignedMembers: map['assigned_members'] != null
          ? (map['assigned_members'] as List)
              .map((m) => TaskMember.fromMap(m as Map<String, dynamic>))
              .toList()
          : null,
      followedUpBy: map['followed_up_by'] != null
          ? (map['followed_up_by'] as List)
              .map((m) => TaskMember.fromMap(m as Map<String, dynamic>))
              .toList()
          : null,
      followers: map['followers'] != null
          ? List<String>.from(map['followers'] as List)
          : null,
      attachments: map['attachments'] != null
          ? List<String>.from(map['attachments'] as List)
          : null,
      listId: map['list_id'] as String?,
      reportId: map['report_id'] as String?,
      teamId: map['team_id'] as int?,
      department: map['department'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Create from Firestore document
  factory TodoModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TodoModel(
      firebaseId: doc.id,
      ownerUid: data['owner_uid'] as String? ?? doc.reference.parent.parent?.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      isCompleted: data['is_completed'] as bool? ?? false,
      isImportant: data['is_important'] as bool? ?? false,
      isMyDay: data['is_my_day'] as bool? ?? false,
      startDate: data['start_date'] != null
          ? (data['start_date'] as Timestamp).toDate()
          : null,
      dueDate: data['due_date'] != null
          ? (data['due_date'] as Timestamp).toDate()
          : null,
      assignedTo: data['assigned_to'] as String?,
      assignedToName: data['assigned_to_name'] as String?,
      assignedMembers: data['assigned_members'] != null
          ? (data['assigned_members'] as List)
              .map((m) => TaskMember.fromMap(m as Map<String, dynamic>))
              .toList()
          : null,
      followedUpBy: data['followed_up_by'] != null
          ? (data['followed_up_by'] as List)
              .map((m) => TaskMember.fromMap(m as Map<String, dynamic>))
              .toList()
          : null,
      followers: data['followers'] != null
          ? List<String>.from(data['followers'] as List)
          : null,
      attachments: data['attachments'] != null
          ? List<String>.from(data['attachments'] as List)
          : null,
      listId: data['list_id'] as String?,
      reportId: data['report_id'] as String?,
      teamId: data['team_id'] as int?,
      department: data['department'] as String?,
      sortOrder: data['sort_order'] as int? ?? 0,
      createdAt: data['created_at'] != null
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updated_at'] != null
          ? (data['updated_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (firebaseId != null) 'firebase_id': firebaseId,
      if (ownerUid != null) 'owner_uid': ownerUid,
      'title': title,
      'description': description,
      'is_completed': isCompleted ? 1 : 0,
      'is_important': isImportant ? 1 : 0,
      'is_my_day': isMyDay ? 1 : 0,
      'start_date': startDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'assigned_to': assignedTo,
      'assigned_to_name': assignedToName,
      'assigned_members': assignedMembers?.map((m) => m.toMap()).toList(),
      'followed_up_by': followedUpBy?.map((m) => m.toMap()).toList(),
      'followers': followers,
      'attachments': attachments,
      'list_id': listId,
      'report_id': reportId,
      'team_id': teamId,
      'department': department,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'owner_uid': ownerUid,
      'title': title,
      'description': description,
      'is_completed': isCompleted,
      'is_important': isImportant,
      'is_my_day': isMyDay,
      'start_date': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'due_date': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'assigned_to': assignedTo,
      'assigned_to_name': assignedToName,
      'assigned_members': assignedMembers?.map((m) => m.toMap()).toList() ?? [],
      'followed_up_by': followedUpBy?.map((m) => m.toMap()).toList() ?? [],
      'followers': followers ?? [],
      'attachments': attachments ?? [],
      'list_id': listId,
      'report_id': reportId,
      'team_id': teamId,
      'department': department,
      'sort_order': sortOrder,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  TodoModel copyWith({
    int? id,
    String? firebaseId,
    String? ownerUid,
    String? title,
    String? description,
    bool? isCompleted,
    bool? isImportant,
    bool? isMyDay,
    DateTime? startDate,
    DateTime? dueDate,
    String? assignedTo,
    String? assignedToName,
    List<TaskMember>? assignedMembers,
    List<TaskMember>? followedUpBy,
    List<String>? followers,
    List<String>? attachments,
    String? listId,
    String? reportId,
    int? teamId,
    String? department,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodoModel(
      id: id ?? this.id,
      firebaseId: firebaseId ?? this.firebaseId,
      ownerUid: ownerUid ?? this.ownerUid,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      isImportant: isImportant ?? this.isImportant,
      isMyDay: isMyDay ?? this.isMyDay,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedMembers: assignedMembers ?? this.assignedMembers,
      followedUpBy: followedUpBy ?? this.followedUpBy,
      followers: followers ?? this.followers,
      attachments: attachments ?? this.attachments,
      listId: listId ?? this.listId,
      reportId: reportId ?? this.reportId,
      teamId: teamId ?? this.teamId,
      department: department ?? this.department,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create a new todo with cleared optional fields
  TodoModel clearDueDate() {
    return TodoModel(
      id: id,
      firebaseId: firebaseId,
      ownerUid: ownerUid,
      title: title,
      description: description,
      isCompleted: isCompleted,
      isImportant: isImportant,
      isMyDay: isMyDay,
      startDate: startDate,
      dueDate: null,
      assignedTo: assignedTo,
      assignedToName: assignedToName,
      assignedMembers: assignedMembers,
      followedUpBy: followedUpBy,
      followers: followers,
      attachments: attachments,
      listId: listId,
      reportId: reportId,
      teamId: teamId,
      department: department,
      sortOrder: sortOrder,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TodoModel &&
        (other.firebaseId == firebaseId || other.id == id);
  }

  @override
  int get hashCode => firebaseId?.hashCode ?? id.hashCode;
}
