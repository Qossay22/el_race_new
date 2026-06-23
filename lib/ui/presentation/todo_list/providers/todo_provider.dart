import 'package:flutter/foundation.dart';

import '../data/todo_list_model.dart';
import '../data/todo_model.dart';
import '../services/todo_database_service.dart';

enum TodoFilter {
  all,
  myDay,
  important,
  planned,
  assignedToMe,
  tasks,
  customList,
}

class TodoProvider extends ChangeNotifier {
  final TodoDatabaseService _dbService = TodoDatabaseService();

  List<TodoModel> _todos = [];
  List<TodoModel> _filteredTodos = [];
  List<TodoListModel> _todoLists = [];
  TodoFilter _currentFilter = TodoFilter.all;
  int? _currentListId;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  // Counts
  int _totalCount = 0;
  int _myDayCount = 0;
  int _importantCount = 0;
  int _plannedCount = 0;
  int _assignedToMeCount = 0;

  // Getters
  List<TodoModel> get todos => _filteredTodos;
  List<TodoListModel> get todoLists => _todoLists;
  TodoFilter get currentFilter => _currentFilter;
  int? get currentListId => _currentListId;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get totalCount => _totalCount;
  int get myDayCount => _myDayCount;
  int get importantCount => _importantCount;
  int get plannedCount => _plannedCount;
  int get assignedToMeCount => _assignedToMeCount;

  // Initialize
  Future<void> initialize() async {
    await loadTodos();
    await loadTodoLists();
    await refreshCounts();
  }

  // Load all todos
  Future<void> loadTodos() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _todos = await _dbService.getAllTodos();
      _applyFilter();
    } catch (e) {
      _errorMessage = 'Failed to load todos: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load all todo lists
  Future<void> loadTodoLists() async {
    try {
      _todoLists = await _dbService.getAllTodoLists();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load lists: $e';
      notifyListeners();
    }
  }

  // Refresh counts
  Future<void> refreshCounts() async {
    try {
      _totalCount = await _dbService.getTodosCount();
      _myDayCount = await _dbService.getMyDayCount();
      _importantCount = await _dbService.getImportantCount();
      _plannedCount = await _dbService.getPlannedCount();

      // For assigned to me, count todos with assigned_to not null
      final assignedTodos = await _dbService.getAssignedToMeTodos(null);
      _assignedToMeCount = assignedTodos.where((t) => !t.isCompleted).length;

      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing counts: $e');
    }
  }

  // Set filter
  Future<void> setFilter(TodoFilter filter, {int? listId}) async {
    _currentFilter = filter;
    _currentListId = listId;
    _isLoading = true;
    notifyListeners();

    try {
      switch (filter) {
        case TodoFilter.myDay:
          _todos = await _dbService.getMyDayTodos();
          break;
        case TodoFilter.important:
          _todos = await _dbService.getImportantTodos();
          break;
        case TodoFilter.planned:
          _todos = await _dbService.getPlannedTodos();
          break;
        case TodoFilter.assignedToMe:
          _todos = await _dbService.getAssignedToMeTodos(null);
          break;
        case TodoFilter.customList:
          if (listId != null) {
            _todos = await _dbService.getTodosByListId(listId);
          }
          break;
        case TodoFilter.all:
        case TodoFilter.tasks:
          _todos = await _dbService.getAllTodos();
          break;
      }
      _applyFilter();
    } catch (e) {
      _errorMessage = 'Failed to filter todos: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Apply search filter
  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredTodos = List.from(_todos);
    } else {
      _filteredTodos = _todos
          .where((todo) =>
              todo.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (todo.description
                      ?.toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ??
                  false))
          .toList();
    }
  }

  // Search
  Future<void> search(String query) async {
    _searchQuery = query;
    if (query.isEmpty) {
      _applyFilter();
    } else {
      _filteredTodos = await _dbService.searchTodos(query);
    }
    notifyListeners();
  }

  // Clear search
  void clearSearch() {
    _searchQuery = '';
    _applyFilter();
    notifyListeners();
  }

  // Add todo
  Future<TodoModel?> addTodo({
    required String title,
    String? description,
    bool isImportant = false,
    bool isMyDay = false,
    DateTime? dueDate,
    String? assignedTo,
    int? listId,
  }) async {
    try {
      final now = DateTime.now();
      final todo = TodoModel(
        title: title,
        description: description,
        isImportant: isImportant,
        isMyDay: isMyDay,
        dueDate: dueDate,
        assignedTo: assignedTo,
        listId: (listId ?? _currentListId)?.toString(),
        sortOrder: _todos.length,
        createdAt: now,
        updatedAt: now,
      );

      final id = await _dbService.insertTodo(todo);
      final newTodo = todo.copyWith(id: id);

      _todos.insert(0, newTodo);
      _applyFilter();
      await refreshCounts();
      notifyListeners();

      return newTodo;
    } catch (e) {
      _errorMessage = 'Failed to add todo: $e';
      notifyListeners();
      return null;
    }
  }

  // Update todo
  Future<bool> updateTodo(TodoModel todo) async {
    try {
      final updatedTodo = todo.copyWith(updatedAt: DateTime.now());
      await _dbService.updateTodo(updatedTodo);

      final index = _todos.indexWhere((t) => t.id == todo.id);
      if (index != -1) {
        _todos[index] = updatedTodo;
      }

      _applyFilter();
      await refreshCounts();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update todo: $e';
      notifyListeners();
      return false;
    }
  }

  // Delete todo
  Future<bool> deleteTodo(int id) async {
    try {
      await _dbService.deleteTodo(id);
      _todos.removeWhere((t) => t.id == id);
      _applyFilter();
      await refreshCounts();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete todo: $e';
      notifyListeners();
      return false;
    }
  }

  // ==================== REPORT RELATED METHODS ====================

  /// Get todos linked to a specific report
  Future<List<TodoModel>> getTodosByReportId(String reportId) async {
    try {
      return await _dbService.getTodosByReportId(reportId);
    } catch (e) {
      debugPrint('Error getting todos by report: $e');
      return [];
    }
  }

  /// Get count of tasks for a report
  Future<int> getTasksCountByReportId(String reportId) async {
    try {
      return await _dbService.getTasksCountByReportId(reportId);
    } catch (e) {
      debugPrint('Error getting tasks count: $e');
      return 0;
    }
  }

  /// Create a task from a report
  Future<TodoModel?> createTaskFromReport({
    required String reportId,
    required String reportName,
    String? description,
    bool isImportant = false,
    DateTime? dueDate,
  }) async {
    try {
      final now = DateTime.now();
      final todo = TodoModel(
        title: reportName,
        description: description,
        reportId: reportId,
        isImportant: isImportant,
        dueDate: dueDate,
        isCompleted: false,
        isMyDay: false,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

      final id = await _dbService.insertTodo(todo);
      final newTodo = todo.copyWith(id: id);

      _todos.insert(0, newTodo);
      _applyFilter();
      await refreshCounts();
      notifyListeners();

      return newTodo;
    } catch (e) {
      _errorMessage = 'Failed to create task from report: $e';
      notifyListeners();
      return null;
    }
  }

  // ==================== END REPORT METHODS ====================

  // Toggle complete
  Future<void> toggleComplete(int id) async {
    try {
      final index = _todos.indexWhere((t) => t.id == id);
      if (index != -1) {
        final todo = _todos[index];
        final newValue = !todo.isCompleted;
        await _dbService.toggleTodoComplete(id, newValue);
        _todos[index] = todo.copyWith(
          isCompleted: newValue,
          updatedAt: DateTime.now(),
        );
        _applyFilter();
        await refreshCounts();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to toggle complete: $e';
      notifyListeners();
    }
  }

  // Toggle important
  Future<void> toggleImportant(int id) async {
    try {
      final index = _todos.indexWhere((t) => t.id == id);
      if (index != -1) {
        final todo = _todos[index];
        final newValue = !todo.isImportant;
        await _dbService.toggleTodoImportant(id, newValue);
        _todos[index] = todo.copyWith(
          isImportant: newValue,
          updatedAt: DateTime.now(),
        );
        _applyFilter();
        await refreshCounts();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to toggle important: $e';
      notifyListeners();
    }
  }

  // Toggle my day
  Future<void> toggleMyDay(int id) async {
    try {
      final index = _todos.indexWhere((t) => t.id == id);
      if (index != -1) {
        final todo = _todos[index];
        final newValue = !todo.isMyDay;
        await _dbService.toggleTodoMyDay(id, newValue);
        _todos[index] = todo.copyWith(
          isMyDay: newValue,
          updatedAt: DateTime.now(),
        );
        _applyFilter();
        await refreshCounts();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to toggle my day: $e';
      notifyListeners();
    }
  }

  // Reorder todos
  Future<void> reorderTodos(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final todo = _filteredTodos.removeAt(oldIndex);
    _filteredTodos.insert(newIndex, todo);

    // Update sort order in database
    await _dbService.updateTodoOrder(_filteredTodos);
    notifyListeners();
  }

  // ==================== TODO LIST OPERATIONS ====================

  // Add list
  Future<TodoListModel?> addTodoList({
    required String name,
    String? iconName,
    String? color,
  }) async {
    try {
      final now = DateTime.now();
      final list = TodoListModel(
        name: name,
        iconName: iconName,
        color: color,
        sortOrder: _todoLists.length,
        createdAt: now,
        updatedAt: now,
      );

      final id = await _dbService.insertTodoList(list);
      final newList = list.copyWith(id: id);

      _todoLists.add(newList);
      notifyListeners();

      return newList;
    } catch (e) {
      _errorMessage = 'Failed to add list: $e';
      notifyListeners();
      return null;
    }
  }

  // Update list
  Future<bool> updateTodoList(TodoListModel list) async {
    try {
      final updatedList = list.copyWith(updatedAt: DateTime.now());
      await _dbService.updateTodoList(updatedList);

      final index = _todoLists.indexWhere((l) => l.id == list.id);
      if (index != -1) {
        _todoLists[index] = updatedList;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update list: $e';
      notifyListeners();
      return false;
    }
  }

  // Delete list
  Future<bool> deleteTodoList(int id) async {
    try {
      await _dbService.deleteTodoList(id);
      _todoLists.removeWhere((l) => l.id == id);

      // If we're viewing this list, go back to all
      if (_currentListId == id) {
        await setFilter(TodoFilter.all);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete list: $e';
      notifyListeners();
      return false;
    }
  }

  // Get todo count for list
  Future<int> getTodoCountForList(int listId) async {
    return await _dbService.getTodoCountByListId(listId);
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
