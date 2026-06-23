import 'package:cloud_firestore/cloud_firestore.dart';

class TodoListModel {
  final int? id; // Local SQLite ID (deprecated)
  final String? firebaseId; // Firebase document ID
  final String name;
  final String? iconName;
  final String? color;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TodoListModel({
    this.id,
    this.firebaseId,
    required this.name,
    this.iconName,
    this.color,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TodoListModel.fromMap(Map<String, dynamic> map) {
    return TodoListModel(
      id: map['id'] as int?,
      firebaseId: map['firebase_id'] as String?,
      name: map['name'] as String,
      iconName: map['icon_name'] as String?,
      color: map['color'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Create from Firestore document
  factory TodoListModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TodoListModel(
      firebaseId: doc.id,
      name: data['name'] as String? ?? '',
      iconName: data['icon_name'] as String?,
      color: data['color'] as String?,
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
      'name': name,
      'icon_name': iconName,
      'color': color,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'icon_name': iconName,
      'color': color,
      'sort_order': sortOrder,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  TodoListModel copyWith({
    int? id,
    String? firebaseId,
    String? name,
    String? iconName,
    String? color,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodoListModel(
      id: id ?? this.id,
      firebaseId: firebaseId ?? this.firebaseId,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TodoListModel &&
        (other.firebaseId == firebaseId || other.id == id);
  }

  @override
  int get hashCode => firebaseId?.hashCode ?? id.hashCode;
}
