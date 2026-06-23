import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/tasks/data/assignable_user_model.dart';
import 'package:el_race/ui/presentation/tasks/data/task_model.dart';
import 'package:el_race/ui/presentation/tasks/data/tasks_api_service.dart';

class TasksRepository {
  final TasksApiService _api;

  TasksRepository({TasksApiService? api}) : _api = api ?? TasksApiService();

  String _getTokenOrThrow() {
    final login = SharedPref.getLoginDataOrNull();
    final token = login?.result?.token;
    if (token == null || token.isEmpty) {
      throw TasksApiException('Missing auth token', code: 401);
    }
    return token;
  }

  Future<List<TaskModel>> getUserTasks() async {
    final token = _getTokenOrThrow();
    return _api.fetchTasks(token: token);
  }

  Future<List<AssignableUser>> getAssignableUsers() async {
    final token = _getTokenOrThrow();
    return _api.fetchAssignableUsers(token: token);
  }

  Future<TaskModel> createTask({
    required String name,
    String? description,
    String? priority,
    int? userId,
    String? attachmentBase64,
    String? attachmentFilename,
    String? comment,
  }) async {
    final token = _getTokenOrThrow();
    return _api.createTask(
      token: token,
      name: name,
      description: description,
      priority: priority,
      userId: userId,
      attachmentBase64: attachmentBase64,
      attachmentFilename: attachmentFilename,
      comment: comment,
    );
  }

  Future<String> submitTask({required int taskId}) async {
    final token = _getTokenOrThrow();
    return _api.submitTask(token: token, taskId: taskId);
  }

  Future<String> linkReportToTask({
    required int taskId,
    required String reportId,
  }) async {
    final token = _getTokenOrThrow();
    return _api.linkReportToTask(
        token: token, taskId: taskId, reportId: reportId);
  }

  Future<String> updateTask({
    required int taskId,
    String? name,
    String? description,
    String? priority,
  }) async {
    final token = _getTokenOrThrow();
    return _api.updateTask(
      token: token,
      taskId: taskId,
      name: name,
      description: description,
      priority: priority,
    );
  }

  Future<String> deleteTask({required int taskId}) async {
    final token = _getTokenOrThrow();
    return _api.deleteTask(token: token, taskId: taskId);
  }
}
