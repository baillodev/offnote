import 'package:offnote/models/task.dart';

import 'database_service.dart';

class TaskLocalService {
  final _db = DatabaseService();

  Future<int> addTask(Task task) async {
    return await _db.insert("tasks", task.toMap());
  }

  Future<List<Task>> getTasks() async {
    final result = await _db.query("tasks");

    return result.map((e) => Task.fromMap(e)).toList();
  }

  Future<int> updateTask(Task task) async {
    if (task.id == null) throw Exception("La tâche doit avoir un ID");

    return _db.update("tasks", task.toMap(), task.id!);
  }

  Future<int> deleteTask(int id) async {
    return await _db.delete("tasks", id);
  }
}
