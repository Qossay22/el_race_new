import 'package:equatable/equatable.dart';

class PartnerEntity extends Equatable {
  final int id;
  final String name;
  final String? icon;
  final int workOrdersCount;

  const PartnerEntity({
    required this.id,
    required this.name,
    this.icon,
    required this.workOrdersCount,
  });

  @override
  List<Object?> get props => [id, name, icon, workOrdersCount];
}
