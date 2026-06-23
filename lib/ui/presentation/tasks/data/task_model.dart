import 'package:collection/collection.dart';

class TaskModel {
  final int? id;
  final String? name;
  final String? description;
  final String? priority;
  final String? stage;
  final String? assignedUser;
  final String? team;
  final DateTime? createdAt;
  final String? projectId;
  final List<dynamic> reportIds;

  const TaskModel({
    this.id,
    this.name,
    this.description,
    this.priority,
    this.stage,
    this.assignedUser,
    this.team,
    this.createdAt,
    this.projectId,
    this.reportIds = const [],
  });

  bool get isCompleted {
    final stageStr = (stage ?? '').toLowerCase();
    return stageStr == 'done' ||
        stageStr == 'completed' ||
        stageStr == 'finished' ||
        stageStr == 'complete';
  }

  TaskModel copyWith({
    int? id,
    String? name,
    String? description,
    String? priority,
    String? stage,
    String? assignedUser,
    String? team,
    DateTime? createdAt,
    String? projectId,
    List<dynamic>? reportIds,
  }) {
    return TaskModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      stage: stage ?? this.stage,
      assignedUser: assignedUser ?? this.assignedUser,
      team: team ?? this.team,
      createdAt: createdAt ?? this.createdAt,
      projectId: projectId ?? this.projectId,
      reportIds: reportIds ?? this.reportIds,
    );
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final rawDate = json['create_date'] as String?;
    if (rawDate != null && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate);
    }

    return TaskModel(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String?,
      description: json['description'] as String?,
      priority: json['priority']?.toString(),
      stage: json['stage'] as String?,
      assignedUser: json['assigned_user'] as String?,
      team: json['team'] as String?,
      createdAt: parsedDate,
      projectId: json['project_id']?.toString(),
      reportIds: (json['x_report_ids'] as List?)?.toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'priority': priority,
      'stage': stage,
      'assigned_user': assignedUser,
      'team': team,
      'create_date': createdAt?.toIso8601String(),
      'project_id': projectId,
      'x_report_ids': reportIds,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskModel &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.priority == priority &&
        other.stage == stage &&
        other.assignedUser == assignedUser &&
        other.team == team &&
        other.createdAt == createdAt &&
        other.projectId == projectId &&
        const DeepCollectionEquality().equals(other.reportIds, reportIds);
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        description,
        priority,
        stage,
        assignedUser,
        team,
        createdAt,
        projectId,
        const DeepCollectionEquality().hash(reportIds),
      );
}
