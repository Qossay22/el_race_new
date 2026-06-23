/// Model for Department/Team from ERP API
/// API Response format: { "id": 1, "name": "Software Development | Hassan Mohamed M Abuebeid" }
/// The name format is: "Department | EmployeeName"
class TeamModel {
  final int id;
  final String name; // Full name from API
  final String? department; // Extracted department name
  final String? employeeName; // Extracted employee name
  final String? description;
  final int? managerId;
  final String? managerName;
  final int? memberCount;

  const TeamModel({
    required this.id,
    required this.name,
    this.department,
    this.employeeName,
    this.description,
    this.managerId,
    this.managerName,
    this.memberCount,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    final fullName = json['name'] as String? ?? 
          json['team_name'] as String? ?? 
          json['department'] as String? ?? '';
    
    // Parse "Department | EmployeeName" format
    String? department;
    String? employeeName;
    
    if (fullName.contains(' | ')) {
      final parts = fullName.split(' | ');
      department = parts[0].trim();
      employeeName = parts.length > 1 ? parts[1].trim() : null;
    } else {
      // If no separator, treat the whole name as department
      department = fullName;
    }
    
    return TeamModel(
      id: json['id'] as int? ?? 
          json['team_id'] as int? ?? 
          json['department_id'] as int? ?? 0,
      name: fullName,
      department: department,
      employeeName: employeeName,
      description: json['description'] as String?,
      managerId: json['manager_id'] as int?,
      managerName: json['manager_name'] as String?,
      memberCount: json['member_count'] as int? ?? 
                   json['members_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (department != null) 'department': department,
      if (employeeName != null) 'employee_name': employeeName,
      if (description != null) 'description': description,
      if (managerId != null) 'manager_id': managerId,
      if (managerName != null) 'manager_name': managerName,
      if (memberCount != null) 'member_count': memberCount,
    };
  }

  /// Get display name (department only or full name)
  String get displayName => department ?? name;
  
  /// Get unique departments from a list of teams
  static List<String> getUniqueDepartments(List<TeamModel> teams) {
    final departments = <String>{};
    for (final team in teams) {
      if (team.department != null && team.department!.isNotEmpty) {
        departments.add(team.department!);
      }
    }
    return departments.toList()..sort();
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
