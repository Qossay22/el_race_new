import 'package:equatable/equatable.dart';

abstract class PartnerEvent extends Equatable {
  const PartnerEvent();

  @override
  List<Object?> get props => [];
}

class LoadPartnersEvent extends PartnerEvent {
  final bool refresh;

  const LoadPartnersEvent({this.refresh = false});

  @override
  List<Object?> get props => [refresh];
}

class SearchPartnersEvent extends PartnerEvent {
  final String keyword;

  const SearchPartnersEvent(this.keyword);

  @override
  List<Object?> get props => [keyword];
}

class LoadPartnerProjectsEvent extends PartnerEvent {
  final int partnerId;

  const LoadPartnerProjectsEvent(this.partnerId);

  @override
  List<Object?> get props => [partnerId];
}
