import 'package:el_race/ui/presentation/my_projects/domain/entities/attachment_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_filters_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_partner_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_event.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProjectListBloc extends Bloc<ProjectListEvent, ProjectListState> {
  static ProjectListBloc get(BuildContext context) => BlocProvider.of(context);
//
  final GetProjectsUseCase getProjectsUseCase;
  final GetProjectAttachmentsUseCase getProjectAttachmentsUseCase;
  final GetProjectsByPartnerUseCase? getProjectsByPartnerUseCase;
  final GetProjectsByFiltersUseCase? getProjectsByFiltersUseCase;

  List<ProjectEntity> projects = [];
  List<AttachmentEntity> projectAttacmentList = [];
  List<ProjectEntity> _allProjects = [];
  List<ProjectEntity> visibleProjects = [];
  final int _pageSize = 10;
  int _currentPage = 0;

  ProjectListBloc({
    required this.getProjectsUseCase,
    required this.getProjectAttachmentsUseCase,
    this.getProjectsByPartnerUseCase,
    this.getProjectsByFiltersUseCase,
  }) : super(ProjectListInitial()) {
    // on<LoadProjectsEvent>((event, emit) async {
    //   if(projects.isNotEmpty && !event.refresh)return;
    //   emit(ProjectListLoading());
    //   try {
    //     projects = await getProjectsUseCase();
    //     emit(ProjectListLoaded());
    //   } catch (e) {
    //     emit(ProjectListError(e.toString()));
    //   }
    // });

    on<LoadProjectsEvent>(_onLoadProjects);
    on<LoadProjectsByPartnerEvent>(_onLoadProjectsByPartner);
    on<LoadProjectsByFiltersEvent>(_onLoadProjectsByFilters);
    on<LoadMoreProjectsEvent>(_onLoadMoreProjects);

    on<GetProjectAttachmentsEvent>(
        (GetProjectAttachmentsEvent event, emit) async {
      debugPrint("===============================");
      debugPrint("📦 ProjectListBloc GetProjectAttachmentsEvent");
      debugPrint("projectId: ${event.projectId}");
      debugPrint("folderType: ${event.folderType}");
      debugPrint("===============================");
      emit(ProjectAttachmentsLoading());
      try {
        projectAttacmentList = await getProjectAttachmentsUseCase(
            event.projectId,
            folderType: event.folderType);
        emit(const ProjectAttachmentsLoaded());
      } catch (e) {
        emit(ProjectAttachmentsError(e.toString()));
      }
    });
  }

  Future<void> _onLoadProjects(LoadProjectsEvent event, Emitter emit) async {
    if (_allProjects.isNotEmpty && !event.refresh) return;
    emit(ProjectListLoading());
    try {
      _allProjects = await getProjectsUseCase();
      _currentPage = 1;
      visibleProjects = _allProjects.take(_pageSize).toList();
      emit(ProjectListLoaded());
    } catch (e) {
      emit(ProjectListError(e.toString()));
    }
  }

  Future<void> _onLoadProjectsByPartner(
      LoadProjectsByPartnerEvent event, Emitter emit) async {
    if (_allProjects.isNotEmpty && !event.refresh) return;
    emit(ProjectListLoading());
    try {
      if (getProjectsByPartnerUseCase != null) {
        _allProjects = await getProjectsByPartnerUseCase!(event.partnerId);
        _currentPage = 1;
        visibleProjects = _allProjects.take(_pageSize).toList();
        emit(ProjectListLoaded());
      } else {
        emit(ProjectListError('Partner projects use case not available'));
      }
    } catch (e) {
      emit(ProjectListError(e.toString()));
    }
  }

  Future<void> _onLoadProjectsByFilters(
      LoadProjectsByFiltersEvent event, Emitter emit) async {
    if (_allProjects.isNotEmpty && !event.refresh) return;
    emit(ProjectListLoading());
    try {
      if (getProjectsByFiltersUseCase != null) {
        _allProjects = await getProjectsByFiltersUseCase!(
          agreementId: event.agreementId,
          partnerId: event.partnerId,
          projectManagerId: event.projectManagerId,
          cityId: event.cityId,
          keyword: event.keyword,
        );
        _currentPage = 1;
        visibleProjects = _allProjects.take(_pageSize).toList();
        emit(ProjectListLoaded());
      } else {
        emit(ProjectListError('Projects filters use case not available'));
      }
    } catch (e) {
      emit(ProjectListError(e.toString()));
    }
  }

  void _onLoadMoreProjects(LoadMoreProjectsEvent event, Emitter emit) {
    final nextItems =
        _allProjects.skip(_pageSize * _currentPage).take(_pageSize).toList();
    final newItems =
        nextItems.where((item) => !visibleProjects.contains(item)).toList();

    if (newItems.isNotEmpty) {
      visibleProjects.addAll(newItems);
      debugPrint('project length: ${visibleProjects.length}');
      _currentPage++;
      emit(ProjectListLoaded());
    }
  }
}
