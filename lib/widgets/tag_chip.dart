import 'package:flutter/material.dart';

class TagChip extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback? onDeleted;

  const TagChip({super.key, required this.label, this.color, this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: color ?? Colors.grey.shade600,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      deleteIcon: onDeleted != null
          ? const Icon(Icons.close, size: 16, color: Colors.white)
          : null,
      onDeleted: onDeleted,
    );
  }
}
