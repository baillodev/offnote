import 'dart:async';
import 'package:flutter/material.dart';
import 'package:offnote/models/task.dart';
import 'package:offnote/services/api_service.dart';
import 'package:offnote/services/sync_service.dart';
import 'package:offnote/services/task_list_service.dart';

class TaskProvider extends ChangeNotifier {
  final ApiService _apiService;
  final TaskLocalService _localService;
  final SyncService _syncService;

  // État des tâches
  List<Task> _tasks = [];
  List<Task> get tasks => _tasks;

  // État de chargement
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // État de synchronisation
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  // Erreurs
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Filtres et recherche
  String _selectedFilter = 'All'; // 'All', 'Active', 'Completed'
  String get selectedFilter => _selectedFilter;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  // Tri
  String _sortMode = 'updated_desc'; // 'updated_desc', 'updated_asc', 'alpha'
  String get sortMode => _sortMode;

  // Tâches filtrées et triées
  List<Task> get filteredTasks {
    List<Task> filtered = _tasks;

    // Filtre par statut
    if (_selectedFilter == 'Active') {
      filtered = filtered.where((task) => !task.completed).toList();
    } else if (_selectedFilter == 'Completed') {
      filtered = filtered.where((task) => task.completed).toList();
    }

    // Filtre par recherche
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((task) {
        return task.title.toLowerCase().contains(query) ||
            (task.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Tri
    filtered = _applySorting(filtered);

    return filtered;
  }

  // Nombre de tâches non synchronisées
  int get unsyncedCount => _tasks.where((t) => !t.isSynced).length;

  late final StreamSubscription _syncSubscription;

  TaskProvider({
    required ApiService apiService,
    required TaskLocalService localService,
    required SyncService syncService,
  }) : _apiService = apiService,
       _localService = localService,
       _syncService = syncService {
    // Écouter les changements de statut de sync
    _syncSubscription = _syncService.syncStatusStream.listen((status) {
      _isSyncing = status == SyncStatus.syncing;
      notifyListeners();
    });
  }

  /// Change le mode de tri
  void setSortMode(String mode) {
    _sortMode = mode;
    notifyListeners();
  }

  /// Applique le tri sur une liste de tâches
  List<Task> _applySorting(List<Task> list) {
    final sorted = [...list];

    switch (_sortMode) {
      case 'updated_asc':
        sorted.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;

      case 'alpha':
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;

      case 'updated_desc':
      default:
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    return sorted;
  }

  /// Initialise les données au démarrage de l'app
  Future<void> initializeData() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      // 1. Charger depuis la base locale d'abord
      _tasks = await _localService.getTasks();
      print('${_tasks.length} tâches chargées depuis la base locale');
      notifyListeners(); // Afficher immédiatement les données locales

      // 2. Si la base locale est vide, charger depuis l'API
      if (_tasks.isEmpty) {
        print('Base locale vide, chargement depuis l\'API...');
        try {
          final apiTasks = await _apiService.getTasks(limit: 20);
          print('${apiTasks.length} tâches récupérées depuis l\'API');

          // Sauvegarder dans la base locale
          for (final task in apiTasks) {
            await _localService.addTask(task);
          }

          _tasks = apiTasks;
          print('Données initiales sauvegardées localement');
        } catch (e) {
          print('Erreur lors du chargement depuis l\'API: $e');
          _errorMessage = 'Impossible de charger les données depuis l\'API';
        }
      }
    } catch (e) {
      _errorMessage = 'Erreur d\'initialisation: $e';
      print('$_errorMessage');
    } finally {
      _setLoading(false);
    }
  }

  /// Charge les tâches depuis la base locale
  Future<void> loadTasks() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      _tasks = await _localService.getTasks();
      print('${_tasks.length} tâches chargées depuis la base locale');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur de chargement: $e';
      print('$_errorMessage');
    } finally {
      _setLoading(false);
    }
  }

  /// Ajoute une nouvelle tâche
  Future<bool> addTask({
    required String title,
    String? description,
    DateTime? dueDate,
    String priority = 'medium',
    List<String>? tags,
    required bool isOnline,
  }) async {
    try {
      final newTask = Task(
        userId: 1,
        title: title,
        completed: false,
        description: description,
        dueDate: dueDate,
        priority: priority,
        tags: tags ?? [],
        isSynced: false,
        updatedAt: DateTime.now(),
      );

      if (isOnline) {
        try {
          final createdTask = await _apiService.createTask(newTask);

          // Créer une nouvelle Task avec l'ID de l'API et isSynced = true
          final synced = Task(
            userId: createdTask.userId,
            id: createdTask.id,
            title: title,
            completed: false,
            description: description,
            dueDate: dueDate,
            priority: priority,
            tags: tags ?? [],
            isSynced: true,
            updatedAt: DateTime.now(),
          );

          await _localService.addTask(synced);
          _tasks.add(synced);
          print('Tâche créée et synchronisée: ${synced.id}');
        } catch (e) {
          await _localService.addTask(newTask);
          await _syncService.addPendingOperation(
            operation: 'create',
            taskId: newTask.id,
            data: newTask.toMap(),
          );
          _tasks.add(newTask);
          print('Tâche créée localement (sync en attente): $e');
        }
      } else {
        await _localService.addTask(newTask);
        await _syncService.addPendingOperation(
          operation: 'create',
          taskId: newTask.id,
          data: newTask.toMap(),
        );
        _tasks.add(newTask);
        print('Tâche créée offline (sync en attente)');
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de l\'ajout: $e';
      print('$_errorMessage');
      return false;
    }
  }

  /// Met à jour une tâche existante
  Future<bool> updateTask(Task task, {required bool isOnline}) async {
    try {
      final updatedTask = Task(
        userId: task.userId,
        id: task.id,
        title: task.title,
        completed: task.completed,
        description: task.description,
        dueDate: task.dueDate,
        priority: task.priority,
        tags: task.tags,
        isSynced: false,
        updatedAt: DateTime.now(),
      );

      if (isOnline) {
        try {
          await _apiService.updateTask(updatedTask);

          // Marquer comme synchronisé après succès de l'API
          final syncedTask = Task(
            userId: updatedTask.userId,
            id: updatedTask.id,
            title: updatedTask.title,
            completed: updatedTask.completed,
            description: updatedTask.description,
            dueDate: updatedTask.dueDate,
            priority: updatedTask.priority,
            tags: updatedTask.tags,
            isSynced: true,
            updatedAt: updatedTask.updatedAt,
          );

          await _localService.updateTask(syncedTask);
          _updateTaskInList(syncedTask);
          print('Tâche mise à jour et synchronisée: ${task.id}');
        } catch (e) {
          await _localService.updateTask(updatedTask);
          await _syncService.addPendingOperation(
            operation: 'update',
            taskId: task.id,
            data: updatedTask.toMap(),
          );
          _updateTaskInList(updatedTask);
          print('Tâche mise à jour localement (sync en attente)');
        }
      } else {
        await _localService.updateTask(updatedTask);
        await _syncService.addPendingOperation(
          operation: 'update',
          taskId: task.id,
          data: updatedTask.toMap(),
        );
        _updateTaskInList(updatedTask);
        print('Tâche mise à jour offline (sync en attente)');
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour: $e';
      print('$_errorMessage');
      return false;
    }
  }

  /// Toggle le statut completed d'une tâche
  Future<bool> toggleTaskCompletion(Task task, {required bool isOnline}) async {
    final updatedTask = Task(
      userId: task.userId,
      id: task.id,
      title: task.title,
      completed: !task.completed,
      description: task.description,
      dueDate: task.dueDate,
      priority: task.priority,
      tags: task.tags,
      isSynced: task.isSynced,
      updatedAt: DateTime.now(),
    );

    return await updateTask(updatedTask, isOnline: isOnline);
  }

  /// Supprime une tâche
  Future<bool> deleteTask(Task task, {required bool isOnline}) async {
    try {
      if (task.id == null) return false;

      if (isOnline) {
        try {
          await _apiService.deleteTask(task.id!);
          await _localService.deleteTask(task.id!);
          _tasks.removeWhere((t) => t.id == task.id);
          print('Tâche supprimée et synchronisée: ${task.id}');
        } catch (e) {
          await _syncService.addPendingOperation(
            operation: 'delete',
            taskId: task.id,
            data: {},
          );
          _tasks.removeWhere((t) => t.id == task.id);
          print('Tâche marquée pour suppression (sync en attente)');
        }
      } else {
        await _localService.deleteTask(task.id!);
        await _syncService.addPendingOperation(
          operation: 'delete',
          taskId: task.id,
          data: {},
        );
        _tasks.removeWhere((t) => t.id == task.id);
        print('Tâche supprimée offline (sync en attente)');
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la suppression: $e';
      print('$_errorMessage');
      return false;
    }
  }

  /// Synchronise les données avec l'API
  Future<SyncResult> syncTasks({required bool isOnline}) async {
    if (!isOnline) {
      return SyncResult(success: false, message: 'Pas de connexion internet');
    }

    try {
      final result = await _syncService.syncTasks(isOnline: isOnline);

      if (result.success) {
        // Recharger les tâches depuis la base locale
        await loadTasks();
      }

      return result;
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Erreur de synchronisation: $e',
      );
    }
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _selectedFilter = 'All';
    _searchQuery = '';
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _updateTaskInList(Task updatedTask) {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
    }
  }

  @override
  void dispose() {
    _syncSubscription.cancel();
    super.dispose();
  }
}
