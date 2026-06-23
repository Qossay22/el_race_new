/// Model for LPO (Local Purchase Order) search results
/// Represents individual LPO items returned from global search API
class LpoSearchModel {
  final int id;
  final String name;
  final String partnerId;
  final String? clientPhoto;
  final String? requestedByUserPhoto;
  final String project;
  final String requestedBy;
  final String requesterManager;
  final double amountTotal;
  final String dateOrder;
  final String state;
  final List<LpoAttachment> attachments;

  LpoSearchModel({
    required this.id,
    required this.name,
    required this.partnerId,
    this.clientPhoto,
    this.requestedByUserPhoto,
    required this.project,
    required this.requestedBy,
    required this.requesterManager,
    required this.amountTotal,
    required this.dateOrder,
    required this.state,
    required this.attachments,
  });

  /// Factory constructor to parse from JSON
  factory LpoSearchModel.fromJson(Map<String, dynamic> json) {
    return LpoSearchModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      partnerId: json['partner_id'] ?? '',
      clientPhoto: json['client_photo'],
      requestedByUserPhoto: json['requested_by_user_photo'],
      project: json['project'] ?? '',
      requestedBy: json['requested_by'] ?? '',
      requesterManager: json['requester_manager'] ?? '',
      amountTotal: _parseDouble(json['amount_total']),
      dateOrder: json['date_order'] ?? '',
      state: json['state'] ?? '',
      attachments: _parseAttachments(json['attachments']),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'partner_id': partnerId,
      'client_photo': clientPhoto,
      'requested_by_user_photo': requestedByUserPhoto,
      'project': project,
      'requested_by': requestedBy,
      'requester_manager': requesterManager,
      'amount_total': amountTotal,
      'date_order': dateOrder,
      'state': state,
      'attachments': attachments.map((a) => a.toJson()).toList(),
    };
  }

  /// Helper to safely parse double values
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Helper to parse attachments list
  static List<LpoAttachment> _parseAttachments(dynamic attachments) {
    if (attachments == null) return [];
    if (attachments is! List) return [];

    return attachments
        .where((item) => item is Map<String, dynamic>)
        .map((item) => LpoAttachment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  String toString() {
    return 'LpoSearchModel(id: $id, name: $name, partnerId: $partnerId, state: $state)';
  }
}

/// Model for LPO attachment
class LpoAttachment {
  final int id;
  final String name;
  final String url;

  LpoAttachment({
    required this.id,
    required this.name,
    required this.url,
  });

  /// Factory constructor to parse from JSON
  factory LpoAttachment.fromJson(Map<String, dynamic> json) {
    return LpoAttachment(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      url: json['url'] ?? '',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
    };
  }

  @override
  String toString() {
    return 'LpoAttachment(id: $id, name: $name)';
  }
}
