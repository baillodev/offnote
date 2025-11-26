import 'package:flutter/material.dart';
import 'package:offnote/screens/task_list_screen.dart';
import 'package:offnote/services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = DatabaseService();
  await db.database;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const TaskListScreen(),
    );
  }
}
