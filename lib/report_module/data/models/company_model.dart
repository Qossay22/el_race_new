import 'package:hive/hive.dart';

part 'company_model.g.dart';

@HiveType(typeId: 101)
class CompanyModel {
  @HiveField(0)
  final String companyName;

  @HiveField(1)
  final String logo;

  @HiveField(2)
  final String employeeName;

  @HiveField(3)
  final String personEmail;

  @HiveField(4)
  final String contactPhone;

  @HiveField(5)
  final String employeeID;

  @HiveField(6)
  final String endText;

  CompanyModel({
    required this.companyName,
    required this.logo,
    required this.employeeName,
    required this.personEmail,
    required this.contactPhone,
    required this.employeeID,
    required this.endText,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      companyName: json['companyName'] as String,
      logo: json['logo'] as String,
      employeeName: json['personName'] as String,
      personEmail: json['personEmail'] as String,
      contactPhone: json['contactPhone'] as String,
      employeeID: json['footerText'] as String,
      endText: json['endText'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companyName': companyName,
      'logo': logo,
      'personName': employeeName,
      'personEmail': personEmail,
      'contactPhone': contactPhone,
      'footerText': employeeID,
      'endText': endText,
    };
  }

  CompanyModel copyWith({
    String? companyName,
    String? logo,
    String? personName,
    String? personEmail,
    String? contactPhone,
    String? employeeID,
    String? endText,
  }) {
    return CompanyModel(
      companyName: companyName ?? this.companyName,
      logo: logo ?? this.logo,
      employeeName: personName ?? employeeName,
      personEmail: personEmail ?? this.personEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      employeeID: employeeID ?? this.employeeID,
      endText: endText ?? this.endText,
    );
  }
}
