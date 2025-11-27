import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offnote.db');

    return await openDatabase(
      path,
      version: 3, // Incrémenté à 3 pour forcer la migration
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Création initiale de la base (version 3)
  Future<void> _onCreate(Database db, int version) async {
    // Table des tâches
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY,
        userId INTEGER NOT NULL,
        title TEXT NOT NULL,
        completed INTEGER NOT NULL,
        description TEXT,
        dueDate TEXT,
        priority TEXT,
        tags TEXT,
        isSynced INTEGER NOT NULL,
        updatedAt TEXT NOT NULL
      );
    ''');

    // Table des opérations en attente (pour sync offline)
    await db.execute('''
      CREATE TABLE pending_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT NOT NULL,
        taskId INTEGER,
        data TEXT NOT NULL,
        timestamp TEXT NOT NULL
      );
    ''');

    print('Base de données créée avec version $version');
  }

  /// Migration de la base
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Migration de la base v$oldVersion -> v$newVersion');

    if (oldVersion < 2) {
      // Ajout de la table pending_operations si elle n'existe pas
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_operations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          operation TEXT NOT NULL,
          taskId INTEGER,
          data TEXT NOT NULL,
          timestamp TEXT NOT NULL
        );
      ''');

      print('Table pending_operations créée');
    }

    if (oldVersion < 3) {
      // Corriger le nom de la colonne updateAt -> updatedAt
      print('Correction du nom de colonne updateAt -> updatedAt');

      // Créer une nouvelle table avec le bon schéma
      await db.execute('''
        CREATE TABLE tasks_new (
          id INTEGER PRIMARY KEY,
          userId INTEGER NOT NULL,
          title TEXT NOT NULL,
          completed INTEGER NOT NULL,
          description TEXT,
          dueDate TEXT,
          priority TEXT,
          tags TEXT,
          isSynced INTEGER NOT NULL,
          updatedAt TEXT NOT NULL
        );
      ''');

      // Copier les données de l'ancienne table (si elle existe et a des données)
      try {
        await db.execute('''
          INSERT INTO tasks_new 
          SELECT id, userId, title, completed, description, dueDate, 
                 priority, tags, isSynced, updateAt as updatedAt 
          FROM tasks;
        ''');
      } catch (e) {
        print('Pas de données à migrer (normal si première installation): $e');
      }

      // Supprimer l'ancienne table et renommer la nouvelle
      await db.execute('DROP TABLE IF EXISTS tasks;');
      await db.execute('ALTER TABLE tasks_new RENAME TO tasks;');

      print('Colonne corrigée avec succès');
    }
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      table,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
  }

  Future<int> update(String table, Map<String, dynamic> data, int id) async {
    final db = await database;
    return await db.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(String table, int id) async {
    final db = await database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  /// Récupère toutes les opérations en attente
  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    return await query('pending_operations', orderBy: 'timestamp ASC');
  }

  /// Compte le nombre d'opérations en attente
  Future<int> getPendingOperationsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pending_operations',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Supprime toutes les opérations en attente
  Future<void> clearPendingOperations() async {
    final db = await database;
    await db.delete('pending_operations');
  }

  /// Ferme la base de données
  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }

  /// Supprime complètement la base (pour tests/debug)
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offnote.db');
    await databaseFactory.deleteDatabase(path);
    _db = null;
    print('Base de données supprimée');
  }
}
