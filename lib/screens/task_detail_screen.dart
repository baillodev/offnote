import 'package:flutter/material.dart';
import 'package:offnote/screens/task_form_screen.dart';
import 'package:provider/provider.dart';
import 'package:offnote/models/task.dart';
import 'package:offnote/providers/connectivity_provider.dart';
import 'package:offnote/providers/task_provider.dart';
import 'package:offnote/widgets/priority_badge.dart';
import 'package:offnote/widgets/sync_indicator.dart';
import 'package:offnote/widgets/tag_chip.dart';
import 'package:intl/intl.dart';

class TaskDetailScreen extends StatelessWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  Future<void> _toggleCompletion(BuildContext context, bool isOnline) async {
    final provider = context.read<TaskProvider>();
    final success = await provider.toggleTaskCompletion(
      task,
      isOnline: isOnline,
    );

    if (!context.mounted) return;

    if (success) {
      Navigator.pop(context);
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
    }
  }

  Future<void> _deleteTask(BuildContext context, bool isOnline) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous supprimer "${task.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final provider = context.read<TaskProvider>();
    final success = await provider.deleteTask(task, isOnline: isOnline);

    if (!context.mounted) return;

    if (success) {
      Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la tâche'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Modifier',
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)),
              );

              if (updated == true && context.mounted) {
                context.read<TaskProvider>().loadTasks();
              }
            },
          ),

          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteTask(context, isOnline),
            tooltip: 'Supprimer',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec statut de sync
              _buildSyncStatusBanner(),

              const SizedBox(height: 20),

              // Titre
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: task.completed,
                    onChanged: (value) => _toggleCompletion(context, isOnline),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: task.completed
                            ? Colors.grey
                            : Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Badges (priorité, tags)
              Row(
                children: [
                  PriorityBadge(priority: task.priority),
                  const SizedBox(width: 8),
                  if (task.tags != null && task.tags!.isNotEmpty)
                    ...task.tags!.map(
                      (tag) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TagChip(label: tag),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 24),

              // Description
              if (task.description != null && task.description!.isNotEmpty) ...[
                _buildSectionTitle('Description'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    task.description!,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Date d'échéance
              if (task.dueDate != null) ...[
                _buildSectionTitle('Date d\'échéance'),
                const SizedBox(height: 8),
                _buildInfoCard(
                  icon: Icons.calendar_today,
                  text: DateFormat(
                    'dd MMMM yyyy',
                    'fr_FR',
                  ).format(task.dueDate!),
                  color: _isOverdue(task.dueDate!) ? Colors.red : Colors.blue,
                ),
                const SizedBox(height: 24),
              ],

              // Informations supplémentaires
              _buildSectionTitle('Informations'),
              const SizedBox(height: 8),
              _buildInfoCard(
                icon: Icons.person_outline,
                text: 'User ID: ${task.userId}',
                color: Colors.grey,
              ),
              const SizedBox(height: 8),
              _buildInfoCard(
                icon: Icons.update,
                text:
                    'Dernière modification: ${DateFormat('dd/MM/yyyy HH:mm').format(task.updatedAt)}',
                color: Colors.grey,
              ),

              const SizedBox(height: 32),

              // Bouton d'action principal
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _toggleCompletion(context, isOnline),
                  icon: Icon(task.completed ? Icons.undo : Icons.check),
                  label: Text(
                    task.completed
                        ? 'Marquer comme non terminée'
                        : 'Marquer comme terminée',
                    style: TextStyle(
                      color: task.completed
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: task.completed
                        ? Colors.orange
                        : Theme.of(context).colorScheme.primary,
                    iconColor: task.completed
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: task.isSynced ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: task.isSynced ? Colors.green.shade200 : Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SyncIndicator(isSynced: task.isSynced, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.isSynced
                      ? 'Synchronisée'
                      : 'En attente de synchronisation',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: task.isSynced
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
                if (!task.isSynced)
                  Text(
                    'Les modifications seront envoyées lors de la prochaine sync',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  bool _isOverdue(DateTime dueDate) {
    return dueDate.isBefore(DateTime.now()) && !task.completed;
  }
}
