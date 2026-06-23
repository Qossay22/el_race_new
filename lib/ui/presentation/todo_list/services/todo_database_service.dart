import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../data/todo_list_model.dart';
import '../data/todo_model.dart';

class TodoDatabaseService {
  static final TodoDatabaseService _instance = TodoDatabaseService._internal();
  static Database? _database;

  factory TodoDatabaseService() => _instance;

  TodoDatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'todo_database.db');
    return await openDatabase(
      path,
      version: 2, // Incremented for report_id migration
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create todo_lists table
    await db.execute('''
      CREATE TABLE todo_lists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon_name TEXT,
        color TEXT,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create todos table
    await db.execute('''
      CREATE TABLE todos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        is_completed INTEGER DEFAULT 0,
        is_important INTEGER DEFAULT 0,
        is_my_day INTEGER DEFAULT 0,
        due_date TEXT,
        assigned_to TEXT,
        list_id INTEGER,
        report_id TEXT,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (list_id) REFERENCES todo_lists (id) ON DELETE SET NULL
      )
    ''');

    // Create indexes for better performance
    await db
        .execute('CREATE INDEX idx_todos_is_completed ON todos(is_completed)');
    await db
        .execute('CREATE INDEX idx_todos_is_important ON todos(is_important)');
    await db.execute('CREATE INDEX idx_todos_is_my_day ON todos(is_my_day)');
    await db.execute('CREATE INDEX idx_todos_due_date ON todos(due_date)');
    await db.execute('CREATE INDEX idx_todos_list_id ON todos(list_id)');
    await db.execute('CREATE INDEX idx_todos_report_id ON todos(report_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add report_id column for version 2
      await db.execute('ALTER TABLE todos ADD COLUMN report_id TEXT');
      await db.execute('CREATE INDEX idx_todos_report_id ON todos(report_id)');
    }
  }

  // ==================== TODO OPERATIONS ====================

  Future<int> insertTodo(TodoModel todo) async {
    final db = await database;
    return await db.insert('todos', todo.toMap());
  }

  Future<int> updateTodo(TodoModel todo) async {
    final db = await database;
    return await db.update(
      'todos',
      todo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  Future<int> deleteTodo(int id) async {
    final db = await database;
    return await db.delete(
      'todos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<TodoModel?> getTodoById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return TodoModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<TodoModel>> getAllTodos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      orderBy: 'sort_order ASC, created_at DESC',
    );
    return maps.map((map) => TodoModel.fromMap(map)).toList();
  }

  Future<List<TodoModel>> getIncompleteTodos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      where: 'is_completed = ?',
      whereArgs: [0],
      orderBy: 'sort_order ASC, created_at DESC',
    );
    return maps.map((map) => TodoModel.fromMap(map)).toList();
  }

  Future<List<TodoModel>> getMyDayTodos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      where: 'is_my_day = ?',
      whereArgs: [1],
      orderBy: 'is_completed ASC, sort_order ASC, created_at DESC',
    );
    return maps.map((map) => TodoModel.fromMap(map)).toList();
  }

  Future<List<TodoModel>> getImportantTodos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      where: 'is_important = ?',
      whereArgs: [1],
      orderBy: 'is_completed ASC, sort_order ASC, created_at DESC',
    );
    return maps.map((map) => TodoModel.fromMap(map)).toList();
  }

  Future<List<TodoModel>> getPlannedTodos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      where: 'due_date IS NOT NULL',
      orderBy: 'is_completed ASC, due_date ASC, sort_order ASC',
    );
    return maps.map((map) => TodoModel.fromMap(map)).toList();
  }

  Future<List<TodoModel>> getAssignedToMeTodos(String? assignee) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      where: 'assigned_to = ? OR assigned_to IS NOT NULL',
      whereArgs: assignee != null ? [assignee] : null,
      orderBy: 'is_completed ASC, sort_order ASC, created_at DESC',
    );
    return maps.map((map) => TodoModel.fromMap(map)).toList();
  }

  Future<List<TodoModel>> getTodosByListId(int listId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      where: 'list_id = ?',
      whereArgs: [listId],
      orderBy: 'is_completed ASC, sort_order ASC, created_at DESC',
    );
    return maps.map((map) => TodoModel.fromMap(map)).toList();
  }

  Future<List<TodoModel>> getTodosByReportId(String reportId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      where: 'report_id = ?',
      whereArgs: [reportId],
      orderBy: 'is_completed ASC, sort_order ASC, created_at DESC',
    );
    return maps.map((map) => TodoModel.fromMap(map)).toList();
  }

  Future<int> getTasksCountByReportId(String reportId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM todos WHERE report_id = ?',
      [reportId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<TodoModel>> searchTodos(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      where: 'title LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'is_completed ASC, sort_order ASC, created_at DESC',
    );
    return maps.map((map) => TodoModel.fromMap(map)).toList();
  }

  Future<int> toggleTodoComplete(int id, bool isCompleted) async {
    final db = await database;
    return await db.update(
      'todos',
      {
        'is_completed': isCompleted ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> toggleTodoImportant(int id, bool isImportant) async {
    final db = await database;
    return await db.update(
      'todos',
      {
        'is_important': isImportant ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> toggleTodoMyDay(int id, bool isMyDay) async {
    final db = await database;
    return await db.update(
      'todos',
      {
        'is_my_day': isMyDay ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTodoOrder(List<TodoModel> todos) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < todos.length; i++) {
      batch.update(
        'todos',
        {
          'sort_order': i,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [todos[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> getTodosCount() async {
    final db = await database;
    final result = await db
        .rawQuery('SELECT COUNT(*) as count FROM todos WHERE is_completed = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getMyDayCount() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM todos WHERE is_my_day = 1 AND is_completed = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getImportantCount() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM todos WHERE is_important = 1 AND is_completed = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getPlannedCount() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM todos WHERE due_date IS NOT NULL AND is_completed = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Reset My Day at midnight
  Future<void> resetMyDay() async {
    final db = await database;
    await db.update(
      'todos',
      {
        'is_my_day': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
  }

  // ==================== TODO LIST OPERATIONS ====================

  Future<int> insertTodoList(TodoListModel list) async {
    final db = await database;
    return await db.insert('todo_lists', list.toMap());
  }

  Future<int> updateTodoList(TodoListModel list) async {
    final db = await database;
    return await db.update(
      'todo_lists',
      list.toMap(),
      where: 'id = ?',
      whereArgs: [list.id],
    );
  }

  Future<int> deleteTodoList(int id) async {
    final db = await database;
    // First update all todos in this list to have no list
    await db.update(
      'todos',
      {'list_id': null},
      where: 'list_id = ?',
      whereArgs: [id],
    );
    return await db.delete(
      'todo_lists',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<TodoListModel>> getAllTodoLists() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todo_lists',
      orderBy: 'sort_order ASC, created_at DESC',
    );
    return maps.map((map) => TodoListModel.fromMap(map)).toList();
  }

  Future<TodoListModel?> getTodoListById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todo_lists',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return TodoListModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> getTodoCountByListId(int listId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM todos WHERE list_id = ? AND is_completed = 0',
      [listId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== UTILITY ====================

  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
