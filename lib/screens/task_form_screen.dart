import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:offnote/providers/connectivity_provider.dart';
import 'package:offnote/providers/task_provider.dart';
import 'package:offnote/widgets/custom_text_field.dart';
import 'package:intl/intl.dart';
import 'package:offnote/models/task.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? task; // <-- AJOUT POUR L'ÉDITION

  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _selectedDueDate;
  String _selectedPriority = 'medium';
  final List<String> _tags = [];
  final _tagController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // --- MODE ÉDITION ---
    if (widget.task != null) {
      final t = widget.task!;
      _titleController.text = t.title;
      _descriptionController.text = t.description ?? '';
      _selectedDueDate = t.dueDate;
      _selectedPriority = t.priority;
      _tags.addAll(t.tags ?? []);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _selectedDueDate = date;
      });
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final taskProvider = context.read<TaskProvider>();
    final isOnline = context.read<ConnectivityProvider>().isOnline;

    bool success = false;

    if (widget.task == null) {
      // --- CRÉATION ---
      success = await taskProvider.addTask(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        dueDate: _selectedDueDate,
        priority: _selectedPriority,
        tags: _tags.isEmpty ? null : _tags,
        isOnline: isOnline,
      );
    } else {
      // --- MISE À JOUR ---
      final updatedTask = widget.task!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        dueDate: _selectedDueDate,
        priority: _selectedPriority,
        tags: _tags,
      );

      success = await taskProvider.updateTask(
        updatedTask,
        isOnline: isOnline,
      );
    }

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.task == null
                ? (isOnline
                    ? 'Tâche créée et synchronisée'
                    : 'Tâche créée (sync plus tard)')
                : (isOnline
                    ? 'Tâche mise à jour'
                    : 'Modification enregistrée (sync plus tard)'),
          ),
          backgroundColor: isOnline ? Colors.green : Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Erreur: ${taskProvider.errorMessage ?? "Inconnue"}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;
    final isEditing = widget.task != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier la tâche' : 'Nouvelle tâche'),
        actions: [
          if (!isOnline)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off,
                          size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Offline',
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
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // TITLE
            CustomTextField(
              label: 'Titre *',
              controller: _titleController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Le titre est requis';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // DESCRIPTION
            CustomTextField(
              label: 'Description',
              controller: _descriptionController,
              maxLines: 4,
            ),

            const SizedBox(height: 20),

            // PRIORITY
            const Text(
              'Priorité',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Row(
              children: ['low', 'medium', 'high'].map((priority) {
                final selected = _selectedPriority == priority;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      priority.toUpperCase(),
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedPriority = priority);
                    },
                    selectedColor: _getPriorityColor(priority),
                    backgroundColor: Colors.grey.shade200,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // DUE DATE
            const Text(
              'Date d\'échéance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            InkWell(
              onTap: _selectDueDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDueDate == null
                          ? 'Choisir une date'
                          : DateFormat('dd MMMM yyyy', 'fr_FR')
                              .format(_selectedDueDate!),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    if (_selectedDueDate != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () =>
                            setState(() => _selectedDueDate = null),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // TAGS
            const Text(
              'Tags',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: InputDecoration(
                      hintText: 'Ajouter un tag',
                      filled: true,
                      fillColor:
                          Theme.of(context).colorScheme.surfaceVariant,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: _addTag,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (_tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags
                    .map((tag) => Chip(
                          label: Text(tag),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removeTag(tag),
                        ))
                    .toList(),
              ),

            const SizedBox(height: 32),

            // SAVE BUTTON
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        isEditing ? 'Mettre à jour' : 'Créer la tâche',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            if (!isOnline) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mode offline : La tâche sera synchronisée automatiquement lors de la reconnexion',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
