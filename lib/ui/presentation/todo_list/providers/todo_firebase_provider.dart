import 'dart:async';
import 'package:flutter/foundation.dart';

import '../data/todo_list_model.dart';
import '../data/todo_model.dart';
import '../services/team_members_api_service.dart';
import '../services/todo_firebase_service.dart';

enum TodoFilter {
  all,
  myDay,
  important,
  planned,
  assignedToMe,
  tasks,
  customList,
}

/// Provider for Task Management using Firebase
/// All CRUD operations are done through Firebase
/// Only team members are fetched from backend API
class TodoFirebaseProvider extends ChangeNotifier {
  final TodoFirebaseService _firebaseService = TodoFirebaseService.instance;
  final TeamMembersApiService _membersService = TeamMembersApiService.instance;

  List<TodoModel> _todos = [];
  List<TodoModel> _filteredTodos = [];
  List<TodoListModel> _todoLists = [];
  List<TeamMember> _teamMembers = [];
  TodoFilter _currentFilter = TodoFilter.all;
  String? _currentListId;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  // Counts
  int _totalCount = 0;
  int _myDayCount = 0;
  int _importantCount = 0;
  int _plannedCount = 0;
  int _assignedToMeCount = 0;

  // Stream subscriptions
  StreamSubscription? _todosSubscription;
  StreamSubscription? _listsSubscription;

  // Getters
  List<TodoModel> get todos => _filteredTodos;
  List<TodoListModel> get todoLists => _todoLists;
  List<TeamMember> get teamMembers => _teamMembers;
  TodoFilter get currentFilter => _currentFilter;
  String? get currentListId => _currentListId;
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
    await loadTeamMembers();
    await refreshCounts();
    _setupStreams();
  }

  // Setup real-time streams
  void _setupStreams() {
    // Listen to todos changes
    _todosSubscription = _firebaseService.streamAllTodos().listen(
      (todos) {
        _todos = todos;
        _applyFilter();
        refreshCounts();
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Error in todos stream: $e');
      },
    );

    // Listen to lists changes
    _listsSubscription = _firebaseService.streamAllTodoLists().listen(
      (lists) {
        _todoLists = lists;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Error in lists stream: $e');
      },
    );
  }

  @override
  void dispose() {
    _todosSubscription?.cancel();
    _listsSubscription?.cancel();
    super.dispose();
  }

  // Load all todos
  Future<void> loadTodos() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _todos = await _firebaseService.getAllTodos();
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
      _todoLists = await _firebaseService.getAllTodoLists();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load lists: $e';
      notifyListeners();
    }
  }

  // Load team members from backend (only backend interaction)
  Future<void> loadTeamMembers({bool forceRefresh = false}) async {
    try {
      _teamMembers =
          await _membersService.getTeamMembers(forceRefresh: forceRefresh);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading team members: $e');
    }
  }

  // Search team members
  Future<List<TeamMember>> searchTeamMembers(String query) async {
    return await _membersService.searchMembers(query);
  }

  // Refresh counts
  Future<void> refreshCounts() async {
    try {
      _totalCount = await _firebaseService.getTodosCount();
      _myDayCount = await _firebaseService.getMyDayCount();
      _importantCount = await _firebaseService.getImportantCount();
      _plannedCount = await _firebaseService.getPlannedCount();

      // For assigned to me, count todos with assigned_to not null
      final assignedTodos = await _firebaseService.getAssignedToMeTodos(null);
      _assignedToMeCount = assignedTodos.where((t) => !t.isCompleted).length;

      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing counts: $e');
    }
  }

  // Set filter
  Future<void> setFilter(TodoFilter filter, {String? listId}) async {
    _currentFilter = filter;
    _currentListId = listId;
    _isLoading = true;
    notifyListeners();

    try {
      switch (filter) {
        case TodoFilter.myDay:
          _todos = await _firebaseService.getMyDayTodos();
          break;
        case TodoFilter.important:
          _todos = await _firebaseService.getImportantTodos();
          break;
        case TodoFilter.planned:
          _todos = await _firebaseService.getPlannedTodos();
          break;
        case TodoFilter.assignedToMe:
          _todos = await _firebaseService.getAssignedToMeTodos(null);
          break;
        case TodoFilter.customList:
          if (listId != null) {
            _todos = await _firebaseService.getTodosByListId(listId);
          }
          break;
        case TodoFilter.all:
        case TodoFilter.tasks:
          _todos = await _firebaseService.getAllTodos();
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
      _filteredTodos = await _firebaseService.searchTodos(query);
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
    String? assignedToName,
    String? listId,
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
        assignedToName: assignedToName,
        listId: listId ?? _currentListId,
        sortOrder: _todos.length,
        createdAt: now,
        updatedAt: now,
      );

      final firebaseId = await _firebaseService.insertTodo(todo);
      final newTodo = todo.copyWith(firebaseId: firebaseId);

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
      await _firebaseService.updateTodo(updatedTodo);

      final index = _todos.indexWhere((t) => t.firebaseId == todo.firebaseId);
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
  Future<bool> deleteTodo(TodoModel todo) async {
    try {
      final firebaseId = todo.firebaseId;
      if (firebaseId == null) return false;

      await _firebaseService.deleteTodo(
        firebaseId,
        ownerUid: todo.ownerUid,
      );
      _todos.removeWhere((t) => t.firebaseId == firebaseId);
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
      return await _firebaseService.getTodosByReportId(reportId);
    } catch (e) {
      debugPrint('Error getting todos by report: $e');
      return [];
    }
  }

  /// Get count of tasks for a report
  Future<int> getTasksCountByReportId(String reportId) async {
    try {
      return await _firebaseService.getTasksCountByReportId(reportId);
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

      final firebaseId = await _firebaseService.insertTodo(todo);
      final newTodo = todo.copyWith(firebaseId: firebaseId);

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
  Future<void> toggleComplete(TodoModel todo) async {
    try {
      final firebaseId = todo.firebaseId;
      if (firebaseId == null) return;

      final index = _todos.indexWhere((t) => t.firebaseId == firebaseId);
      if (index != -1) {
        final currentTodo = _todos[index];
        final newValue = !currentTodo.isCompleted;
        await _firebaseService.toggleTodoComplete(
          firebaseId,
          newValue,
          ownerUid: currentTodo.ownerUid,
        );
        _todos[index] = currentTodo.copyWith(
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
  Future<void> toggleImportant(TodoModel todo) async {
    try {
      final firebaseId = todo.firebaseId;
      if (firebaseId == null) return;

      final index = _todos.indexWhere((t) => t.firebaseId == firebaseId);
      if (index != -1) {
        final currentTodo = _todos[index];
        final newValue = !currentTodo.isImportant;
        await _firebaseService.toggleTodoImportant(
          firebaseId,
          newValue,
          ownerUid: currentTodo.ownerUid,
        );
        _todos[index] = currentTodo.copyWith(
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
  Future<void> toggleMyDay(TodoModel todo) async {
    try {
      final firebaseId = todo.firebaseId;
      if (firebaseId == null) return;

      final index = _todos.indexWhere((t) => t.firebaseId == firebaseId);
      if (index != -1) {
        final currentTodo = _todos[index];
        final newValue = !currentTodo.isMyDay;
        await _firebaseService.toggleTodoMyDay(
          firebaseId,
          newValue,
          ownerUid: currentTodo.ownerUid,
        );
        _todos[index] = currentTodo.copyWith(
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

    // Update sort order in Firebase
    await _firebaseService.updateTodoOrder(_filteredTodos);
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

      final firebaseId = await _firebaseService.insertTodoList(list);
      final newList = list.copyWith(firebaseId: firebaseId);

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
      await _firebaseService.updateTodoList(updatedList);

      final index =
          _todoLists.indexWhere((l) => l.firebaseId == list.firebaseId);
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
  Future<bool> deleteTodoList(String firebaseId) async {
    try {
      await _firebaseService.deleteTodoList(firebaseId);
      _todoLists.removeWhere((l) => l.firebaseId == firebaseId);

      // If we're viewing this list, go back to all
      if (_currentListId == firebaseId) {
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
  Future<int> getTodoCountForList(String listId) async {
    return await _firebaseService.getTodoCountByListId(listId);
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
