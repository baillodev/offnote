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

  // Filtre
  String _selectedFilter = 'All';
  String get selectedFilter => _selectedFilter;

  // Recherche
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  // Tri
  String _sortMode = 'updated_desc'; // updated_desc / updated_asc / alpha
  String get sortMode => _sortMode;

  // Tâches filtrées + triées
  List<Task> get filteredTasks {
    List<Task> filtered = [..._tasks];

    // Filtrage par statut
    if (_selectedFilter == 'Active') {
      filtered = filtered.where((t) => !t.completed).toList();
    } else if (_selectedFilter == 'Completed') {
      filtered = filtered.where((t) => t.completed).toList();
    }

    // Recherche
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

  int get unsyncedCount => _tasks.where((t) => !t.isSynced).length;

  late final StreamSubscription _syncSubscription;

  TaskProvider({
    required ApiService apiService,
    required TaskLocalService localService,
    required SyncService syncService,
  }) : _apiService = apiService,
       _localService = localService,
       _syncService = syncService {
    _syncSubscription = _syncService.syncStatusStream.listen((status) {
      _isSyncing = status == SyncStatus.syncing;
      notifyListeners();
    });
  }

  void setSortMode(String mode) {
    _sortMode = mode;
    notifyListeners();
  }

  void sortTasks(bool ascending) {
    _sortMode = ascending ? 'alpha' : 'updated_desc';
    _tasks = _applySorting(_tasks);
    notifyListeners();
  }

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

  Future<void> initializeData() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      _tasks = await _localService.getTasks();
      notifyListeners();

      if (_tasks.isEmpty) {
        try {
          final apiTasks = await _apiService.getTasks(limit: 20);

          for (final task in apiTasks) {
            await _localService.addTask(task);
          }

          _tasks = apiTasks;
        } catch (e) {
          _errorMessage = 'Impossible de charger les données depuis l\'API';
        }
      }
    } catch (e) {
      _errorMessage = 'Erreur d\'initialisation: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadTasks() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      _tasks = await _localService.getTasks();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur de chargement: $e';
    } finally {
      _setLoading(false);
    }
  }

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

          final synced = newTask.copyWith(id: createdTask.id, isSynced: true);

          await _localService.addTask(synced);
          _tasks.add(synced);
        } catch (e) {
          await _localService.addTask(newTask);
          await _syncService.addPendingOperation(
            operation: 'create',
            taskId: newTask.id,
            data: newTask.toMap(),
          );
          _tasks.add(newTask);
        }
      } else {
        await _localService.addTask(newTask);
        await _syncService.addPendingOperation(
          operation: 'create',
          taskId: newTask.id,
          data: newTask.toMap(),
        );
        _tasks.add(newTask);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de l\'ajout: $e';
      return false;
    }
  }

  Future<bool> updateTask(Task task, {required bool isOnline}) async {
    try {
      final updated = task.copyWith(updatedAt: DateTime.now(), isSynced: false);

      if (isOnline) {
        try {
          await _apiService.updateTask(updated);

          final synced = updated.copyWith(isSynced: true);

          await _localService.updateTask(synced);
          _updateTaskInList(synced);
        } catch (e) {
          await _localService.updateTask(updated);
          await _syncService.addPendingOperation(
            operation: 'update',
            taskId: updated.id,
            data: updated.toMap(),
          );
          _updateTaskInList(updated);
        }
      } else {
        await _localService.updateTask(updated);
        await _syncService.addPendingOperation(
          operation: 'update',
          taskId: updated.id,
          data: updated.toMap(),
        );
        _updateTaskInList(updated);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour: $e';
      return false;
    }
  }

  Future<bool> deleteTask(Task task, {required bool isOnline}) async {
    try {
      if (task.id == null) return false;

      if (isOnline) {
        try {
          await _apiService.deleteTask(task.id!);
          await _localService.deleteTask(task.id!);
          _tasks.removeWhere((t) => t.id == task.id);
        } catch (e) {
          await _syncService.addPendingOperation(
            operation: 'delete',
            taskId: task.id,
            data: {},
          );
          _tasks.removeWhere((t) => t.id == task.id);
        }
      } else {
        await _localService.deleteTask(task.id!);
        await _syncService.addPendingOperation(
          operation: 'delete',
          taskId: task.id,
          data: {},
        );
        _tasks.removeWhere((t) => t.id == task.id);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la suppression: $e';
      return false;
    }
  }

  Future<bool> toggleTaskCompletion(Task task, {required bool isOnline}) async {
    final updated = task.copyWith(
      completed: !task.completed,
      updatedAt: DateTime.now(),
    );

    return await updateTask(updated, isOnline: isOnline);
  }

  Future<SyncResult> syncTasks({required bool isOnline}) async {
    if (!isOnline) {
      return SyncResult(success: false, message: 'Pas de connexion internet');
    }

    try {
      final result = await _syncService.syncTasks(isOnline: isOnline);

      if (result.success) {
        await loadTasks();
      }

      return result;
    } catch (e) {
      return SyncResult(success: false, message: 'Erreur: $e');
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
