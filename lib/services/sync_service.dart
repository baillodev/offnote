import 'dart:async';
import 'package:offnote/models/task.dart';
import 'package:offnote/services/api_service.dart';
import 'package:offnote/services/database_service.dart';

/// Gère la queue des opérations offline et la résolution de conflits
class SyncService {
  final ApiService _apiService;
  final DatabaseService _dbService;

  // Stream pour notifier les changements de synchronisation
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SyncService({
    required ApiService apiService,
    required DatabaseService dbService,
  }) : _apiService = apiService,
       _dbService = dbService;

  /// Ajoute une opération en attente dans la queue
  Future<void> addPendingOperation({
    required String operation, // 'create', 'update', 'delete'
    required int? taskId,
    required Map<String, dynamic> data,
  }) async {
    final db = await _dbService.database;

    await db.insert('pending_operations', {
      'operation': operation,
      'taskId': taskId,
      'data': data.toString(), // Sérialisation simple
      'timestamp': DateTime.now().toIso8601String(),
    });

    print('Opération ajoutée à la queue: $operation pour task $taskId');
  }

  /// Récupère toutes les opérations en attente
  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await _dbService.database;
    return await db.query('pending_operations', orderBy: 'timestamp ASC');
  }

  /// Supprime une opération de la queue après traitement
  Future<void> removePendingOperation(int operationId) async {
    final db = await _dbService.database;
    await db.delete(
      'pending_operations',
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  /// Vide complètement la queue (après sync réussie)
  Future<void> clearPendingOperations() async {
    final db = await _dbService.database;
    await db.delete('pending_operations');
    print('Queue des opérations vidée');
  }

  /// Synchronise les données locales avec l'API
  Future<SyncResult> syncTasks({bool isOnline = true}) async {
    if (_isSyncing) {
      print('Synchronisation déjà en cours');
      return SyncResult(success: false, message: 'Sync already in progress');
    }

    if (!isOnline) {
      print(' Mode offline - synchronisation impossible');
      return SyncResult(success: false, message: 'No internet connection');
    }

    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);

    try {
      print('Début de la synchronisation...');

      // ÉTAPE 1 : Traiter les opérations en attente
      await _processPendingOperations();

      // ÉTAPE 2 : Récupérer les tâches depuis l'API
      final apiTasks = await _apiService.getTasks(limit: 50);
      print('${apiTasks.length} tâches récupérées depuis l\'API');

      // ÉTAPE 3 : Récupérer les tâches locales
      final localTasksMaps = await _dbService.query('tasks');
      final localTasks = localTasksMaps
          .map((map) => Task.fromMap(map))
          .toList();
      print('${localTasks.length} tâches locales');

      // ÉTAPE 4 : Résoudre les conflits et fusionner
      final mergedTasks = await _resolveConflictsAndMerge(apiTasks, localTasks);
      print('${mergedTasks.length} tâches après fusion');

      // ÉTAPE 5 : Sauvegarder dans la base locale
      await _saveTasksToLocal(mergedTasks);

      _isSyncing = false;
      _syncStatusController.add(SyncStatus.success);

      print('ynchronisation réussie');
      return SyncResult(
        success: true,
        message: 'Synchronisation réussie',
        tasksSynced: mergedTasks.length,
      );
    } catch (e) {
      _isSyncing = false;
      _syncStatusController.add(SyncStatus.error);

      print('Erreur de synchronisation: $e');
      return SyncResult(success: false, message: 'Erreur: $e');
    }
  }

  /// Traite toutes les opérations en attente
  Future<void> _processPendingOperations() async {
    final operations = await getPendingOperations();

    if (operations.isEmpty) {
      print('Aucune opération en attente');
      return;
    }

    print('${operations.length} opérations en attente à traiter');

    for (final op in operations) {
      try {
        final operation = op['operation'] as String;
        final taskId = op['taskId'] as int?;

        switch (operation) {
          case 'create':
            // Récupérer la tâche locale et la créer via l'API
            if (taskId != null) {
              final taskMap = await _dbService.query('tasks');
              final task = taskMap
                  .map((m) => Task.fromMap(m))
                  .firstWhere((t) => t.id == taskId);

              final createdTask = await _apiService.createTask(task);
              print('Tâche créée via API: ${createdTask.id}');
            }
            break;

          case 'update':
            if (taskId != null) {
              final taskMap = await _dbService.query('tasks');
              final task = taskMap
                  .map((m) => Task.fromMap(m))
                  .firstWhere((t) => t.id == taskId);

              await _apiService.updateTask(task);
              print('Tâche mise à jour via API: $taskId');
            }
            break;

          case 'delete':
            if (taskId != null) {
              await _apiService.deleteTask(taskId);
              print('Tâche supprimée via API: $taskId');
            }
            break;
        }

        // Supprimer l'opération de la queue
        await removePendingOperation(op['id'] as int);
      } catch (e) {
        print('Erreur lors du traitement de l\'opération: $e');
        // On garde l'opération dans la queue pour retry
      }
    }
  }

  /// Résout les conflits entre tâches API et locales

  Future<List<Task>> _resolveConflictsAndMerge(
    List<Task> apiTasks,
    List<Task> localTasks,
  ) async {
    final Map<int, Task> mergedMap = {};

    // Ajouter toutes les tâches API dans la map
    for (final apiTask in apiTasks) {
      if (apiTask.id != null) {
        mergedMap[apiTask.id!] = apiTask;
      }
    }

    // Comparer avec les tâches locales
    for (final localTask in localTasks) {
      if (localTask.id == null) continue;

      final apiTask = mergedMap[localTask.id];

      if (apiTask == null) {
        // Tâche locale uniquement (peut-être créée offline)
        mergedMap[localTask.id!] = localTask;
        continue;
      }

      // RÉSOLUTION DE CONFLIT : Last Write Wins
      if (localTask.updatedAt.isAfter(apiTask.updatedAt)) {
        print(
          'Conflit détecté pour tâche ${localTask.id} - Version locale plus récente',
        );

        // Version locale plus récente, on la garde et on la pousse à l'API
        mergedMap[localTask.id!] = localTask.copyWith(isSynced: false);

        // Ajouter à la queue pour sync ultérieure
        await addPendingOperation(
          operation: 'update',
          taskId: localTask.id,
          data: localTask.toMap(),
        );
      } else {
        // Version API plus récente ou égale, on la garde
        mergedMap[localTask.id!] = apiTask.copyWith(
          // Préserver les champs locaux non présents dans l'API
          description: localTask.description,
          dueDate: localTask.dueDate,
          priority: localTask.priority,
          tags: localTask.tags,
          isSynced: true,
        );
      }
    }

    return mergedMap.values.toList();
  }

  /// Sauvegarde les tâches fusionnées dans la base locale
  Future<void> _saveTasksToLocal(List<Task> tasks) async {
    final db = await _dbService.database;

    // Vider la table tasks (on pourrait optimiser en faisant des updates/inserts sélectifs)
    await db.delete('tasks');

    // Insérer toutes les tâches
    for (final task in tasks) {
      await db.insert('tasks', task.toMap());
    }

    print('${tasks.length} tâches sauvegardées localement');
  }

  /// Marque une tâche comme synchronisée
  Future<void> markTaskAsSynced(int taskId) async {
    final db = await _dbService.database;
    await db.update(
      'tasks',
      {'isSynced': 1, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  /// Récupère les tâches non synchronisées
  Future<List<Task>> getUnsyncedTasks() async {
    final db = await _dbService.database;
    final results = await db.query(
      'tasks',
      where: 'isSynced = ?',
      whereArgs: [0],
    );

    return results.map((map) => Task.fromMap(map)).toList();
  }

  void dispose() {
    _syncStatusController.close();
  }
}

enum SyncStatus { idle, syncing, success, error }

class SyncResult {
  final bool success;
  final String message;
  final int? tasksSynced;

  SyncResult({required this.success, required this.message, this.tasksSynced});
}

// Extension pour copier une Task avec modifications
extension TaskCopyWith on Task {
  Task copyWith({
    int? userId,
    int? id,
    String? title,
    bool? completed,
    String? description,
    DateTime? dueDate,
    String? priority,
    List<String>? tags,
    bool? isSynced,
    DateTime? updatedAt,
  }) {
    return Task(
      userId: userId ?? this.userId,
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
