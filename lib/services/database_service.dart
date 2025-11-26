import 'package:sqflite/sqflite.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import '../models/task.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  static Database? _database;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "tasks.db");

    return await openDatabase(path, version: 1, onCreate: _createTables);
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY,
        userId INTEGER,
        title TEXT,
        completed INTEGER,
        description TEXT,
        dueDate TEXT,
        priority TEXT,
        tags TEXT,
        isSynced INTEGER,
        updatedAt TEXT
      )
    ''');
  }

  Future<int> insertTask(Task task) async {
    final db = await database;
    return await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final result = await db.query('tasks', orderBy: "updatedAt DESC");
    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<Task?> getTaskById(int id) async {
    final db = await database;
    final result = await db.query(
      'tasks',
      where: "id = ?",
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return Task.fromMap(result.first);
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return await db.update(
      'tasks',
      task.toMap(),
      where: "id = ?",
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete('tasks', where: "id = ?", whereArgs: [id]);
  }

  Future<List<Task>> getUnsyncedTasks() async {
    final db = await database;
    final result = await db.query('tasks', where: "isSynced = 0");
    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<void> markAsSynced(int id) async {
    final db = await database;
    await db.update('tasks', {"isSynced": 1}, where: "id = ?", whereArgs: [id]);
  }
}
