import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:offnote/models/task.dart';
import 'package:offnote/providers/connectivity_provider.dart';
import 'package:offnote/providers/task_provider.dart';
import 'package:offnote/screens/task_form_screen.dart';
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

class _TaskListScreenState extends State<TaskListScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<TaskProvider>().setSearchQuery(query);
  }

  void _onFilterChanged(String filter) {
    context.read<TaskProvider>().setFilter(filter);
  }

  void _toggleSort() {
    setState(() {
      _sortAscending = !_sortAscending;
    });
    context.read<TaskProvider>().sortTasks(_sortAscending);
  }

  Future<void> _toggleTaskCompletion(Task task, bool isOnline) async {
    final provider = context.read<TaskProvider>();
    final success =
        await provider.toggleTaskCompletion(task, isOnline: isOnline);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            task.completed
                ? 'Tâche marquée comme active'
                : 'Tâche marquée comme terminée',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${provider.errorMessage ?? "Inconnu"}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteTask(Task task, bool isOnline) async {
    final provider = context.read<TaskProvider>();
    final success = await provider.deleteTask(task, isOnline: isOnline);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${task.title} supprimée'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${provider.errorMessage ?? "Inconnu"}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _syncTasks(bool isOnline) async {
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connexion requise pour synchroniser'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final provider = context.read<TaskProvider>();
    final result = await provider.syncTasks(isOnline: isOnline);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _navigateToAddTask() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TaskFormScreen()),
    );

    if (result == true) {
      context.read<TaskProvider>().loadTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TaskProvider, ConnectivityProvider>(
      builder: (context, taskProvider, connectivityProvider, child) {
        final isOnline = connectivityProvider.isOnline;
        final filteredTasks = taskProvider.filteredTasks;
        final unsyncedCount = taskProvider.unsyncedCount;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              "OffNote",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              // TRI bouton
              IconButton(
                icon: Icon(
                  _sortAscending ? Icons.sort_by_alpha : Icons.sort,
                ),
                tooltip: "Trier les tâches",
                onPressed: _toggleSort,
              ),

              // Badge non synchronisé
              if (unsyncedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.shade300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sync_problem,
                              size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 4),
                          Text(
                            '$unsyncedCount',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Synchronisation
              IconButton(
                icon: taskProvider.isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.sync),
                onPressed: taskProvider.isSyncing
                    ? null
                    : () => _syncTasks(isOnline),
                tooltip: 'Synchroniser',
              ),

              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ConnectivityIndicator(isOnline: isOnline),
              )
            ],
          ),

          body: Column(
            children: [
              // Offline banner
              if (!isOnline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.orange.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off,
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mode offline - Les modifications seront synchronisées plus tard',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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
                  selectedFilter: taskProvider.selectedFilter,
                  onSelected: _onFilterChanged,
                ),
              ),

              const SizedBox(height: 10),

              // LISTE AVEC ANIMATIONS 🔥
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildTaskList(taskProvider, filteredTasks, isOnline),
                ),
              ),
            ],
          ),

          floatingActionButton: AddTaskButton(onPressed: _navigateToAddTask),
        );
      },
    );
  }

  Widget _buildTaskList(
    TaskProvider provider,
    List<Task> tasks,
    bool isOnline,
  ) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (provider.errorMessage != null) {
      return _buildErrorState(provider.errorMessage!);
    }

    if (tasks.isEmpty) {
      return _buildEmptyState(provider.selectedFilter);
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadTasks(),
      child: ListView.builder(
        itemCount: tasks.length,
        padding: const EdgeInsets.only(bottom: 80),
        itemBuilder: (context, index) {
          final task = tasks[index];

          return AnimatedOpacity(
            opacity: 1,
            duration: Duration(milliseconds: 300 + (index * 40)),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.2),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: AnimationController(
                    vsync: this,
                    duration: Duration(milliseconds: 300 + (index * 40)),
                  )..forward(),
                  curve: Curves.easeOut,
                ),
              ),
              child: Dismissible(
                key: Key(task.id.toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white, size: 32),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Confirmer la suppression'),
                      content: Text('Voulez-vous supprimer "${task.title}" ?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Annuler'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Supprimer',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) => _deleteTask(task, isOnline),
                child: GestureDetector(
                  onTap: () => _toggleTaskCompletion(task, isOnline),
                  child: TaskTile(task: task),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String selectedFilter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'Aucune tâche trouvée'
                : selectedFilter == 'All'
                    ? 'Aucune tâche'
                    : selectedFilter == 'Active'
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

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.read<TaskProvider>().loadTasks(),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
