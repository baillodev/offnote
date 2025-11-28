import 'package:flutter_test/flutter_test.dart';

import 'package:offnote/main.dart';
import 'package:offnote/services/api_service.dart';
import 'package:offnote/services/connectivity_service.dart';
import 'package:offnote/services/database_service.dart' show DatabaseService;
import 'package:offnote/services/sync_service.dart';
import 'package:offnote/services/task_list_service.dart';

void main() async {
  final dbService = DatabaseService();
  await dbService.database;

  // Initialiser les services
  final apiService = ApiService();
  final localService = TaskLocalService();
  final connectivityService = ConnectivityService();
  final syncService = SyncService(apiService: apiService, dbService: dbService);
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MyApp(
        apiService: apiService,
        localService: localService,
        connectivityService: connectivityService,
        syncService: syncService,
      ),
    );
  });
}
