import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:offnote/services/task_list_service.dart';
import 'package:provider/provider.dart';
import 'package:offnote/providers/connectivity_provider.dart';
import 'package:offnote/providers/task_provider.dart';
import 'package:offnote/screens/task_list_screen.dart';
import 'package:offnote/services/api_service.dart';
import 'package:offnote/services/connectivity_service.dart';
import 'package:offnote/services/database_service.dart';
import 'package:offnote/services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser la base de données
  final dbService = DatabaseService();
  await dbService.database;
  print('Base de données initialisée');

  // Initialiser les services
  final apiService = ApiService();
  final localService = TaskLocalService();
  final connectivityService = ConnectivityService();
  final syncService = SyncService(apiService: apiService, dbService: dbService);

  runApp(
    MyApp(
      apiService: apiService,
      localService: localService,
      connectivityService: connectivityService,
      syncService: syncService,
    ),
  );
}

class MyApp extends StatelessWidget {
  final ApiService apiService;
  final TaskLocalService localService;
  final ConnectivityService connectivityService;
  final SyncService syncService;

  const MyApp({
    super.key,
    required this.apiService,
    required this.localService,
    required this.connectivityService,
    required this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provider de connectivité
        ChangeNotifierProvider(
          create: (_) =>
              ConnectivityProvider(connectivityService: connectivityService),
        ),

        // Provider de tâches (dépend des services)
        ChangeNotifierProvider(
          create: (_) => TaskProvider(
            apiService: apiService,
            localService: localService,
            syncService: syncService,
          )..initializeData(), // Initialiser les données au démarrage
        ),
      ],
      child: MaterialApp(
        title: 'OffNote',
        debugShowCheckedModeBanner: false,

        // Localisation française
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
        locale: const Locale('fr', 'FR'),

        theme: ThemeData(
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const TaskListScreen(),
      ),
    );
  }
}
