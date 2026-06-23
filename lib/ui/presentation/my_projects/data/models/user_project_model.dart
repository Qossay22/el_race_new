class UserProjectModel {
  final int projectId;
  final String projectName;
  final int totalProjects;
  final double totalProjectsAmount;
  final String? photoUrl;
  final int? agreementId;
  final String? agreementNo;
  final String? cityId;

  const UserProjectModel({
    required this.projectId,
    required this.projectName,
    required this.totalProjects,
    required this.totalProjectsAmount,
    this.photoUrl,
    this.agreementId,
    this.agreementNo,
    this.cityId,
  });

  factory UserProjectModel.fromJson(Map<String, dynamic> json) {
    int? parseId(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is List && value.isNotEmpty) return parseId(value.first);
      if (value is Map) {
        return parseId(value['id'] ?? value['agreement_id']);
      }
      return int.tryParse(value?.toString() ?? '');
    }

    int parseCount(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double parseAmount(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    dynamic pickAgreementFromProjectsList(dynamic rawProjects) {
      if (rawProjects is! List || rawProjects.isEmpty) return null;
      for (final entry in rawProjects) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        final nestedAgreement = map['agreement_id'] ??
            map['agreement'] ??
            map['agreementId'] ??
            map['project_agreement_id'];
        final parsed = parseId(nestedAgreement);
        if (parsed != null) return parsed;
      }
      return null;
    }

    dynamic pickAgreementNoFromProjectsList(dynamic rawProjects) {
      if (rawProjects is! List || rawProjects.isEmpty) return null;
      for (final entry in rawProjects) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        final value = map['agreement_no'] ??
            map['agreementNo'] ??
            map['agreement_ref'] ??
            map['agreement_name'];
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    final idValue = json['id'] ??
        json['partner_id'] ??
        json['client_id'] ??
        json['partnerId'];
    final agreementIdValue = json['agreement_id'] ??
        json['agreement'] ??
        json['agreementId'] ??
        json['project_agreement_id'] ??
        pickAgreementFromProjectsList(json['projects']);

    final rawPhoto = json['photo_url'] ??
        json['icon'] ??
        json['partner_photo'] ??
        json['image_url'];
    String? photoUrl = rawPhoto?.toString();
    if (photoUrl != null && photoUrl.contains('erp.elrace.compublic')) {
      photoUrl =
          photoUrl.replaceAll('erp.elrace.compublic', 'erp.elrace.com/public');
    }

    final totalProjects = parseCount(
      json['total_projects'] ??
          json['project_count'] ??
          json['projects_count'] ??
          json['work_orders_count'],
    );
    final totalAmount = parseAmount(
      json['total_projects_amount'] ??
          json['total_amount'] ??
          json['projects_amount'] ??
          json['amount'],
    );

    return UserProjectModel(
      projectId: idValue is int
          ? idValue
          : int.tryParse(idValue?.toString() ?? '') ?? 0,
      projectName: (json['name'] ??
              json['partner_name'] ??
              json['client_name'] ??
              '')
          .toString(),
      totalProjects: totalProjects,
      totalProjectsAmount: totalAmount,
      photoUrl: photoUrl,
      agreementId: parseId(agreementIdValue),
      agreementNo: (json['agreement_no'] ?? pickAgreementNoFromProjectsList(json['projects']))
          ?.toString(),
      cityId: json['city_id'] is List && (json['city_id'] as List).length > 1
          ? (json['city_id'] as List)[1]?.toString()
          : json['city_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': projectId,
      'name': projectName,
      'total_projects': totalProjects,
      'total_projects_amount': totalProjectsAmount,
      'photo_url': photoUrl,
      'agreement_id': agreementId,
      'agreement_no': agreementNo,
      'city_id': cityId,
    };
  }
}
