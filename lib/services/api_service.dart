import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:offnote/models/task.dart';

class ApiService {
  static const String baseUrl = 'https://jsonplaceholder.typicode.com';
  static const String todosEndpoint = '/todos';

  static const Map<String, String> headers = {
    'Content-Type': 'application/json; charset=UTF-8',
  };

  Future<List<Task>> getTasks({int? userId, int? limit}) async {
    try {
      String url = '$baseUrl$todosEndpoint';

      List<String> queryParams = [];
      if (userId != null) queryParams.add('userId=$userId');
      if (limit != null) queryParams.add('_limit=$limit');

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Task.fromJson(json)).toList();
      } else {
        throw Exception(
          'Échec du chargement des tâches. Code: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  Future<Task> getTaskById(int id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl$todosEndpoint/$id'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Task.fromJson(json);
      } else if (response.statusCode == 404) {
        throw Exception('Tâche introuvable (ID: $id)');
      } else {
        throw Exception(
          'Échec du chargement de la tâche. Code: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  Future<Task> createTask(Task task) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$todosEndpoint'),
        headers: headers,
        body: jsonEncode(task.toJson()),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Task.fromJson(json);
      } else {
        throw Exception(
          'Échec de la création de la tâche. Code: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  Future<Task> updateTask(Task task) async {
    if (task.id == null) {
      throw Exception('L\'ID de la tâche est requis pour la mise à jour');
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl$todosEndpoint/${task.id}'),
        headers: headers,
        body: jsonEncode(task.toJson()),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Task.fromJson(json);
      } else if (response.statusCode == 404) {
        throw Exception('Tâche introuvable (ID: ${task.id})');
      } else {
        throw Exception(
          'Échec de la mise à jour de la tâche. Code: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  Future<Task> patchTask(int id, Map<String, dynamic> updates) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl$todosEndpoint/$id'),
        headers: headers,
        body: jsonEncode(updates),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Task.fromJson(json);
      } else if (response.statusCode == 404) {
        throw Exception('Tâche introuvable (ID: $id)');
      } else {
        throw Exception(
          'Échec de la mise à jour partielle. Code: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  Future<bool> deleteTask(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$todosEndpoint/$id'),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 404) {
        throw Exception('Tâche introuvable (ID: $id)');
      } else {
        throw Exception(
          'Échec de la suppression de la tâche. Code: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Méthode utilitaire: Toggle le statut completed d'une tâche
  Future<Task> toggleTaskCompletion(int id, bool completed) async {
    return await patchTask(id, {'completed': completed});
  }

  /// Méthode utilitaire: Récupérer les tâches par userId avec limite
  Future<List<Task>> getUserTasks(int userId, {int limit = 20}) async {
    return await getTasks(userId: userId, limit: limit);
  }
}
