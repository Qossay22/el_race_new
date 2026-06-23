import 'package:flutter/material.dart';
import 'package:el_race/data/models/global_search_item.dart';
import 'package:el_race/ui/presentation/tasks/task_details_screen.dart';
import 'package:el_race/ui/presentation/tasks/data/task_model.dart';
import 'package:el_race/ui/presentation/lpo/screens/lpo_screen.dart';
import 'package:el_race/ui/presentation/PettyCash/PettyCashScreen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/project_list_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_bloc.dart';
import 'package:el_race/ui/presentation/my_projects/data/repositories/project_repository_impl.dart';
import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_partner_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Helper class for navigating to detail screens from search results
///
/// This handles navigation logic for different categories.
/// Extend this class as you implement detail screens for each category.
class GlobalSearchNavigationHelper {
  /// Navigate to the appropriate detail screen based on category
  static void navigateToDetail(BuildContext context, GlobalSearchItem item) {
    switch (item.category) {
      case 'tasks':
        _navigateToTaskDetails(context, item);
        break;

      case 'petty_cash':
        _navigateToPettyCashDetails(context, item);
        break;

      case 'projects':
        _navigateToProjectDetails(context, item);
        break;

      case 'lpo':
        _navigateToLpoDetails(context, item);
        break;

      case 'notes':
        _navigateToNoteDetails(context, item);
        break;

      case 'documents':
        _navigateToDocumentDetails(context, item);
        break;

      default:
        _showNotImplemented(context, item);
    }
  }

  /// Navigate to Task Details
  static void _navigateToTaskDetails(
      BuildContext context, GlobalSearchItem item) {
    try {
      // Construct TaskModel from search item data
      final task = TaskModel(
        id: item.id,
        name: item.title,
        description: item.additionalData?['description'],
        projectId: item.additionalData?['project_id']?.toString(),
        priority: item.additionalData?['priority']?.toString(),
        stage: item.additionalData?['stage_id']?.toString() ??
            item.additionalData?['stage'],
        assignedUser: item.additionalData?['assigned_user'],
        team: item.additionalData?['team'],
        createdAt: _parseDate(item.additionalData?['create_date']),
        reportIds: item.additionalData?['x_report_ids'] ?? const [],
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TaskDetailsScreen(task: task),
        ),
      );
    } catch (e) {
      debugPrint('Error navigating to task details: $e');
      _showError(context, 'Unable to open task details');
    }
  }

  /// Navigate to Petty Cash Details
  static void _navigateToPettyCashDetails(
    BuildContext context,
    GlobalSearchItem item,
  ) {
    // Navigate to PettyCash main screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PettyCashScreen(),
      ),
    );
  }

  /// Navigate to Project Details
  static void _navigateToProjectDetails(
    BuildContext context,
    GlobalSearchItem item,
  ) {
    try {
      final data = item.additionalData ?? const <String, dynamic>{};

      int? _asInt(dynamic value) {
        if (value is int) return value;
        if (value is String) return int.tryParse(value);
        return null;
      }

      final int partnerId = _asInt(data['partner_id']) ?? item.id;
      final String partnerName =
          (data['partner_name'] ?? item.title).toString();
      final String partnerPhoto =
          (data['photo_url'] ?? data['partner_photo'] ?? '').toString();

      final repo = ProjectRepositoryImpl(ProjectRemoteDataSource());
      final bloc = ProjectListBloc(
        getProjectsUseCase: GetProjectsUseCase(repository: repo),
        getProjectAttachmentsUseCase:
            GetProjectAttachmentsUseCase(repository: repo),
        getProjectsByPartnerUseCase:
            GetProjectsByPartnerUseCase(repository: repo),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: bloc,
            child: ProjectListScreen(
              bloc: bloc,
              partnerId: partnerId,
              partnerName: partnerName,
              partnerPhoto: partnerPhoto,
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error navigating to project details: $e');
      _showError(context, 'Unable to open project details');
    }
  }

  /// Navigate to LPO Details
  static void _navigateToLpoDetails(
    BuildContext context,
    GlobalSearchItem item,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LpoListScreen(),
      ),
    );
  }

  /// Navigate to Note Details
  static void _navigateToNoteDetails(
    BuildContext context,
    GlobalSearchItem item,
  ) {
    // TODO: Implement navigation to Note details screen
    // Once you have the detail screen ready, uncomment and modify:
    /*
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteDetailScreen(
          noteId: item.id,
        ),
      ),
    );
    */

    _showNotImplemented(context, item);
  }

  /// Navigate to Document Details
  static void _navigateToDocumentDetails(
    BuildContext context,
    GlobalSearchItem item,
  ) {
    // TODO: Implement navigation to Document viewer/details screen
    // Once you have the detail screen ready, uncomment and modify:
    /*
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          documentId: item.id,
          documentName: item.title,
        ),
      ),
    );
    */

    _showNotImplemented(context, item);
  }

  /// Show not implemented message
  static void _showNotImplemented(BuildContext context, GlobalSearchItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Navigation to ${item.displayCategory} details coming soon!',
        ),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  /// Show error message
  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  /// Parse date from string safely
  static DateTime? _parseDate(dynamic dateStr) {
    if (dateStr == null) return null;
    try {
      return DateTime.parse(dateStr.toString());
    } catch (e) {
      return null;
    }
  }
}
