import 'dart:convert';

class Task {
  // Champs API
  final int userId;
  final int? id;
  final String title;
  final bool completed;

  // Champs locaux
  final String? description;
  final DateTime? dueDate;
  final String priority; // "low", "medium", "high"
  final List<String>? tags;

  final bool isSynced; // Pour savoir si la tâche est synchronisée
  final DateTime updatedAt; // Pour gérer les conflits

  Task({
    required this.userId,
    this.id,
    required this.title,
    required this.completed,
    this.description,
    this.dueDate,
    this.priority = "medium",
    this.tags,
    this.isSynced = true,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      userId: json['userId'] as int,
      id: json['id'] as int?,
      title: json['title'] as String,
      completed: json['completed'] as bool,
      description: null,
      dueDate: null,
      priority: "medium",
      tags: [],
      isSynced: true,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {"userId": userId, "id": id, "title": title, "completed": completed};
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      userId: map['userId'],
      id: map['id'],
      title: map['title'],
      completed: map['completed'] == 1,
      description: map['description'],
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      priority: map['priority'] ?? 'medium',
      tags: map['tags'] != null
          ? List<String>.from(jsonDecode(map['tags']))
          : [],
      isSynced: map['isSynced'] == 1,
      updatedAt: DateTime.parse(map['updatedAt']), // CORRIGÉ ICI
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "userId": userId,
      "id": id,
      "title": title,
      "completed": completed ? 1 : 0,
      "description": description,
      "dueDate": dueDate?.toIso8601String(),
      "priority": priority,
      "tags": tags != null ? jsonEncode(tags) : null,
      "isSynced": isSynced ? 1 : 0,
      "updatedAt": updatedAt.toIso8601String(), // CORRIGÉ ICI
    };
  }
}
