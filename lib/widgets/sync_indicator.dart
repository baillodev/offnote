import 'package:flutter/material.dart';

class SyncIndicator extends StatelessWidget {
  final bool isSynced;
  final double size;

  const SyncIndicator({super.key, required this.isSynced, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Icon(
      isSynced ? Icons.check_circle : Icons.sync_problem,
      color: isSynced ? Colors.green : Colors.orange,
      size: size,
    );
  }
}
