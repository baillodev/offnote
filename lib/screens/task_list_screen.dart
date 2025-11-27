import 'package:flutter/material.dart';
import 'package:offnote/models/task.dart';
import 'package:offnote/services/task_list_service.dart';
import 'package:offnote/widgets/task_tile.dart';
import 'package:offnote/widgets/add_task_button.dart';
import 'package:offnote/widgets/connectivity_indicator.dart';
import 'package:offnote/widgets/filter_chips.dart';
import 'package:offnote/widgets/search_bar.dart' as custom;

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TaskLocalService _taskService = TaskLocalService();
  final TextEditingController _searchController = TextEditingController();

  List<Task> _allTasks = [];
  List<Task> _filteredTasks = [];
  String _selectedFilter = 'All';
  bool _isLoading = true;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);

    try {
      final tasks = await _taskService.getTasks();
      setState(() {
        _allTasks = tasks;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  void _applyFilters() {
    List<Task> filtered = _allTasks;

    // Filtrer par statut
    if (_selectedFilter == 'Active') {
      filtered = filtered.where((task) => !task.completed).toList();
    } else if (_selectedFilter == 'Completed') {
      filtered = filtered.where((task) => task.completed).toList();
    }

    // Filtrer par recherche
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((task) {
        return task.title.toLowerCase().contains(searchQuery) ||
            (task.description?.toLowerCase().contains(searchQuery) ?? false);
      }).toList();
    }

    // Trier par date de mise à jour (plus récent en premier)
    filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    setState(() {
      _filteredTasks = filtered;
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilters();
    });
  }

  void _onSearchChanged(String query) {
    _applyFilters();
  }

  Future<void> _toggleTaskCompletion(Task task) async {
    try {
      final updatedTask = Task(
        userId: task.userId,
        id: task.id,
        title: task.title,
        completed: !task.completed,
        description: task.description,
        dueDate: task.dueDate,
        priority: task.priority,
        tags: task.tags,
        isSynced: false,
        updatedAt: DateTime.now(),
      );

      await _taskService.updateTask(updatedTask);
      await _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  void _navigateToAddTask() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Formulaire d\'ajout à implémenter')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "OffNote",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
            tooltip: 'Actualiser',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ConnectivityIndicator(isOnline: _isOnline),
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: custom.SearchBar(
              controller: _searchController,
              onChanged: _onSearchChanged,
            ),
          ),

          // Filtres
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TaskFilterChips(
              selectedFilter: _selectedFilter,
              onSelected: _onFilterChanged,
            ),
          ),

          const SizedBox(height: 10),

          // Liste des tâches
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTasks.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _filteredTasks.length,
                    padding: const EdgeInsets.only(bottom: 80),
                    itemBuilder: (context, index) {
                      final task = _filteredTasks[index];
                      return Dismissible(
                        key: Key(task.id.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirmer la suppression'),
                              content: const Text(
                                'Voulez-vous vraiment supprimer cette tâche ?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Annuler'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'Supprimer',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) async {
                          await _taskService.deleteTask(task.id!);
                          await _loadTasks();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${task.title} supprimée'),
                                action: SnackBarAction(
                                  label: 'Annuler',
                                  onPressed: () {},
                                ),
                              ),
                            );
                          }
                        },
                        child: GestureDetector(
                          onTap: () {
                            _toggleTaskCompletion(task);
                          },
                          child: TaskTile(task: task),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: AddTaskButton(onPressed: _navigateToAddTask),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'Aucune tâche trouvée'
                : _selectedFilter == 'All'
                ? 'Aucune tâche'
                : _selectedFilter == 'Active'
                ? 'Aucune tâche active'
                : 'Aucune tâche terminée',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuyez sur + pour créer une tâche',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
