import 'package:el_race/ui/presentation/my_projects/domain/entities/partner_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_partner_projects_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/partner_event.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/partner_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PartnerBloc extends Bloc<PartnerEvent, PartnerState> {
  static PartnerBloc get(BuildContext context) => BlocProvider.of(context);

  final GetPartnerProjectsUseCase getPartnerProjectsUseCase;

  List<PartnerEntity> partners = [];
  List<PartnerEntity> _allPartners = [];

  PartnerBloc({
    required this.getPartnerProjectsUseCase,
  }) : super(PartnerInitial()) {
    on<LoadPartnersEvent>(_onLoadPartners);
    on<SearchPartnersEvent>(_onSearchPartners);
    on<LoadPartnerProjectsEvent>(_onLoadPartnerProjects);
  }

  Future<void> _onLoadPartners(LoadPartnersEvent event, Emitter emit) async {
    if (_allPartners.isNotEmpty && !event.refresh) return;

    emit(PartnerLoading());
    try {
      _allPartners =
          await getPartnerProjectsUseCase(partnerId: null, keyword: null);
      partners = List.from(_allPartners);
      emit(PartnerLoaded(partners));
    } catch (e) {
      emit(PartnerError(e.toString()));
    }
  }

  Future<void> _onSearchPartners(
      SearchPartnersEvent event, Emitter emit) async {
    if (event.keyword.isEmpty) {
      partners = List.from(_allPartners);
      emit(PartnerLoaded(partners));
      return;
    }

    emit(PartnerLoading());
    try {
      final searchResults = await getPartnerProjectsUseCase(
        partnerId: null,
        keyword: event.keyword,
      );
      partners = searchResults;
      emit(PartnerSearchLoaded(partners, event.keyword));
    } catch (e) {
      emit(PartnerError(e.toString()));
    }
  }

  Future<void> _onLoadPartnerProjects(
      LoadPartnerProjectsEvent event, Emitter emit) async {
    emit(PartnerLoading());
    try {
      // This will navigate to the project list for this specific partner
      // The actual projects will be loaded in the next screen
      final partnerProjects = await getPartnerProjectsUseCase(
        partnerId: event.partnerId,
        keyword: null,
      );
      emit(PartnerLoaded(partnerProjects));
    } catch (e) {
      emit(PartnerError(e.toString()));
    }
  }
}
