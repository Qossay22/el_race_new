import 'package:flutter/material.dart';

typedef FilterCallback = void Function(String filter);

class TasksFilterWidget extends StatelessWidget {
  final FilterCallback onFilterChanged;

  const TasksFilterWidget({Key? key, required this.onFilterChanged})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildFilterButton('All', onFilterChanged),
        _buildFilterButton('Completed', onFilterChanged),
        _buildFilterButton('Pending', onFilterChanged),
      ],
    );
  }

  Widget _buildFilterButton(String label, FilterCallback callback) {
    return ElevatedButton(
      onPressed: () => callback(label),
      child: Text(label),
    );
  }
}
