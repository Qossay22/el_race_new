/// Global search result model
/// Supports multiple categories: petty_cash, projects, lpo, notes, documents, tasks
class GlobalSearchItem {
  final int id;
  final String title;
  final String? subtitle;
  final String category;
  final Map<String, dynamic>? additionalData;

  GlobalSearchItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.category,
    this.additionalData,
  });

  /// Factory constructor to parse from JSON response
  factory GlobalSearchItem.fromJson(
    Map<String, dynamic> json,
    String category,
  ) {
    // Remove image_emp from additionalData for petty_cash
    final Map<String, dynamic> cleanedData = Map.from(json);
    if (category == 'petty_cash' && cleanedData.containsKey('image_emp')) {
      cleanedData.remove('image_emp');
    }

    return GlobalSearchItem(
      id: _parseId(json['id']),
      title: _parseTitle(json, category),
      subtitle: _parseSubtitle(json, category),
      category: category,
      additionalData: cleanedData,
    );
  }

  /// Safely parse ID from different formats
  static int _parseId(dynamic id) {
    if (id is int) return id;
    if (id is String) return int.tryParse(id) ?? 0;
    return 0;
  }

  /// Parse title based on category
  static String _parseTitle(Map<String, dynamic> json, String category) {
    switch (category) {
      case 'petty_cash':
        return json['name'] ?? json['display_name'] ?? 'Expense #${json['id']}';
      case 'projects':
        return json['name'] ?? 'Project #${json['id']}';
      case 'lpo':
        return json['name'] ?? 'LPO #${json['id']}';
      case 'notes':
        return json['name'] ?? json['memo'] ?? 'Note #${json['id']}';
      case 'documents':
        return json['name'] ??
            json['display_name'] ??
            'Document #${json['id']}';
      case 'tasks':
        return json['name'] ?? 'Task #${json['id']}';
      case 'my_actions':
        return json['name'] ?? 'Action #${json['id']}';
      default:
        return json['name'] ?? 'Item #${json['id']}';
    }
  }

  /// Parse subtitle based on category
  static String? _parseSubtitle(Map<String, dynamic> json, String category) {
    switch (category) {
      case 'petty_cash':
        // Note: image_emp field is excluded from the data
        final amount = json['total_amount'] ?? json['amount'];
        final state = json['state'] ?? json['status'];
        return '${amount != null ? '$amount AED' : ''} ${state != null ? '• $state' : ''}'
            .trim();
      case 'projects':
        return json['partner_name'] ?? json['partner_id'];
      case 'lpo':
        final amount = json['amount_total'];
        final partner = json['partner_name'] ?? json['partner_id'];
        return '${amount != null ? '$amount AED' : ''} ${partner != null ? '• $partner' : ''}'
            .trim();
      case 'notes':
        return json['user_name'] ?? json['user_id'];
      case 'documents':
        final size = json['file_size'];
        final type = json['mimetype'];
        return '${type ?? ''} ${size != null ? '• ${_formatFileSize(size)}' : ''}'
            .trim();
      case 'tasks':
        final project = json['project_name'] ?? json['project_id'];
        final stage = json['stage_name'] ?? json['stage_id'];
        return '${project ?? ''} ${stage != null ? '• $stage' : ''}'.trim();
      case 'my_actions':
        final employee = json['employee_name'];
        final status = json['status'];
        final vendor = json['vendor'];
        return [
          if (employee != null) employee.toString(),
          if (status != null) status.toString().toUpperCase(),
          if (vendor != null && vendor.toString().isNotEmpty) vendor.toString(),
        ].join(' • ');
      default:
        return null;
    }
  }

  /// Format file size for documents
  static String _formatFileSize(dynamic size) {
    if (size == null) return '';
    final bytes = size is int ? size : int.tryParse(size.toString()) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get display category name
  String get displayCategory {
    switch (category) {
      case 'petty_cash':
        return 'Petty Cash';
      case 'projects':
        return 'Project';
      case 'lpo':
        return 'LPO';
      case 'notes':
        return 'Note';
      case 'documents':
        return 'Document';
      case 'tasks':
        return 'Task';
      case 'my_actions':
        return 'My Actions';
      default:
        return category;
    }
  }

  @override
  String toString() {
    return 'GlobalSearchItem(id: $id, title: $title, category: $category)';
  }
}
