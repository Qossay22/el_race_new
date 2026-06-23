import 'package:el_race/ui/presentation/my_projects/domain/entities/partner_entity.dart';
import 'package:equatable/equatable.dart';

abstract class PartnerState extends Equatable {
  const PartnerState();

  @override
  List<Object?> get props => [];
}

class PartnerInitial extends PartnerState {}

class PartnerLoading extends PartnerState {}

class PartnerLoaded extends PartnerState {
  final List<PartnerEntity> partners;

  const PartnerLoaded(this.partners);

  @override
  List<Object?> get props => [partners];
}

class PartnerError extends PartnerState {
  final String message;

  const PartnerError(this.message);

  @override
  List<Object?> get props => [message];
}

class PartnerSearchLoaded extends PartnerState {
  final List<PartnerEntity> partners;
  final String keyword;

  const PartnerSearchLoaded(this.partners, this.keyword);

  @override
  List<Object?> get props => [partners, keyword];
}
