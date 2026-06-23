class AssignableUser {
  final int id;
  final String name;

  AssignableUser({required this.id, required this.name});

  factory AssignableUser.fromJson(Map<String, dynamic> json) {
    return AssignableUser(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
    );
  }
}
