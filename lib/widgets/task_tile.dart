import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../screens/task_detail_screen.dart';
import '../providers/connectivity_provider.dart';
import '../providers/task_provider.dart';
import 'priority_badge.dart';
import 'sync_indicator.dart';

class TaskTile extends StatelessWidget {
  final Task task;

  const TaskTile({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskDetailScreen(task: task),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox pour changer statut
              Checkbox(
                value: task.completed,
                onChanged: (_) async {
                  await context.read<TaskProvider>().toggleTaskCompletion(
                        task,
                        isOnline: isOnline,
                      );
                },
                activeColor: Theme.of(context).colorScheme.primary,
              ),

              const SizedBox(width: 12),

              // Titre + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: task.completed
                            ? Colors.grey
                            : Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (task.dueDate != null)
                      Text(
                        'Due: ${task.dueDate!.toLocal().toString().split(' ')[0]}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Priorité + état synchro
              Column(
                children: [
                  PriorityBadge(priority: task.priority),
                  const SizedBox(height: 4),
                  SyncIndicator(isSynced: task.isSynced),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
