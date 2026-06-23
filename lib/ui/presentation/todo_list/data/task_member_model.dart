import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for assigned member with completion status
class TaskMember {
  final String name;
  final String? odooId;   // employee_id (hr.employee)
  final String? userId;   // odoo_user_id (res.users) — used for matching the logged-in user
  final bool isCompleted;
  final DateTime? completedAt;

  const TaskMember({
    required this.name,
    this.odooId,
    this.userId,
    this.isCompleted = false,
    this.completedAt,
  });

  factory TaskMember.fromMap(Map<String, dynamic> map) {
    return TaskMember(
      name: map['name'] as String? ?? '',
      odooId: map['odoo_id'] as String?,
      userId: map['user_id'] as String?,
      isCompleted: map['is_completed'] as bool? ?? false,
      completedAt: map['completed_at'] != null
          ? (map['completed_at'] is Timestamp
              ? (map['completed_at'] as Timestamp).toDate()
              : DateTime.parse(map['completed_at'] as String))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'odoo_id': odooId,
      'user_id': userId,
      'is_completed': isCompleted,
      'completed_at': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  TaskMember copyWith({
    String? name,
    String? odooId,
    String? userId,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return TaskMember(
      name: name ?? this.name,
      odooId: odooId ?? this.odooId,
      userId: userId ?? this.userId,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Get first name only
  String get firstName {
    final parts = name.split(' ');
    return parts.isNotEmpty ? parts.first : name;
  }

  /// Get initials (first letter of first 2 words)
  String get initials {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

/// Model for task comment
class TaskComment {
  final String? id;
  final String authorName;
  final String? authorId;
  final String content;
  final DateTime createdAt;

  const TaskComment({
    this.id,
    required this.authorName,
    this.authorId,
    required this.content,
    required this.createdAt,
  });

  factory TaskComment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TaskComment(
      id: doc.id,
      authorName: data['author_name'] as String? ?? 'Unknown',
      authorId: data['author_id'] as String?,
      content: data['content'] as String? ?? '',
      createdAt: data['created_at'] != null
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory TaskComment.fromMap(Map<String, dynamic> map) {
    return TaskComment(
      id: map['id'] as String?,
      authorName: map['author_name'] as String? ?? 'Unknown',
      authorId: map['author_id'] as String?,
      content: map['content'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? (map['created_at'] is Timestamp
              ? (map['created_at'] as Timestamp).toDate()
              : DateTime.parse(map['created_at'] as String))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'author_name': authorName,
      'author_id': authorId,
      'content': content,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  /// Get first name of author
  String get authorFirstName {
    final parts = authorName.split(' ');
    return parts.isNotEmpty ? parts.first : authorName;
  }

  /// Get author initial
  String get authorInitial {
    return authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U';
  }
}
