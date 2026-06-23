class ProjectManagerFilterItem {
  const ProjectManagerFilterItem({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.projectCount,
    required this.lastUpdate,
  });

  final int id;
  final String name;
  final String? photoUrl;
  final int projectCount;
  final String? lastUpdate;

  factory ProjectManagerFilterItem.fromJson(Map<String, dynamic> json) {
    final rawPhoto = json['photo_url']?.toString();
    final normalizedPhoto = (rawPhoto != null &&
            rawPhoto.contains('erp.elrace.compublic'))
        ? rawPhoto.replaceAll('erp.elrace.compublic', 'erp.elrace.com/public')
        : rawPhoto;

    return ProjectManagerFilterItem(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse((json['id'] ?? '').toString()) ?? 0,
      name: (json['name'] ?? '').toString(),
      photoUrl: normalizedPhoto,
      projectCount: json['project_count'] is int
          ? json['project_count'] as int
          : int.tryParse((json['project_count'] ?? '').toString()) ?? 0,
      lastUpdate: json['last_update']?.toString(),
    );
  }
}
