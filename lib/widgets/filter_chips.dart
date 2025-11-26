import 'package:flutter/material.dart';

class TaskFilterChips extends StatelessWidget {
  final String selectedFilter;
  final Function(String) onSelected;

  const TaskFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onSelected,
  });

  final List<String> filters = const ['All', 'Active', 'Completed'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: filters.map((filter) {
        final bool isSelected = filter == selectedFilter;
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: ChoiceChip(
            label: Text(
              filter,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onBackground,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            onSelected: (_) => onSelected(filter),
            selectedColor: Theme.of(context).colorScheme.primary,
            backgroundColor: Colors.grey.shade200,
            labelPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
          ),
        );
      }).toList(),
    );
  }
}
