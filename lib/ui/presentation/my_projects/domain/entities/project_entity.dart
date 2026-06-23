import 'package:equatable/equatable.dart';

class ProjectEntity extends Equatable {
  final int projectId;
  final String partnerId;
  final String agreementId;
  final String woRefNo;
  final String name;
  final double woAmount;
  final String projectStatus;
  final String date;
  final String dateStart;
  final int? differenceDays;
  final String? projectManagerPhoto;

  const ProjectEntity({
    required this.projectId,
    required this.partnerId,
    required this.agreementId,
    required this.woRefNo,
    required this.name,
    required this.woAmount,
    required this.projectStatus,
    required this.date,
    required this.dateStart,
    this.differenceDays,
    this.projectManagerPhoto,
  });

  @override
  List<Object?> get props => [
        projectId,
        partnerId,
        agreementId,
        woRefNo,
        name,
        woAmount,
        projectStatus,
        date,
        dateStart,
        differenceDays,
        projectManagerPhoto,
      ];
}
