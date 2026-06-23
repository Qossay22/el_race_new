class ApprovalItem {
  final String type;
  final String id;
  final String empName;
  final String name;
  final String location;
  final String approver;
  final String date;

  ApprovalItem({
    required this.type,
    required this.id,
    required this.empName,
    required this.name,
    required this.location,
    required this.approver,
    required this.date,
  });

  factory ApprovalItem.fromJson(Map<String, dynamic> json, String type) {
    return ApprovalItem(
      type: type,
      id: json['id']?.toString() ?? '',
      empName: json['emp_name'] ?? '',
      name: json['name'] ?? '',
      location: json['location'] ?? '',
      approver: json['approver'] ?? '',
      date: json['date'] ?? '',
    );
  }
}
