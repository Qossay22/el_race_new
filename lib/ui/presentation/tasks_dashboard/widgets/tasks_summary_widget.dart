import 'package:flutter/material.dart';
import '../../tasks/data/task_model.dart';

class TasksSummaryWidget extends StatelessWidget {
  final List<TaskModel> tasks;

  const TasksSummaryWidget({Key? key, required this.tasks}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalTasks = tasks.length;
    final pendingTasks = tasks.where((task) => !task.isCompleted).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSummaryCard('Total Tasks', totalTasks, Colors.blue),
        _buildSummaryCard('Pending Tasks', pendingTasks, Colors.orange),
      ],
    );
  }

  Widget _buildSummaryCard(String title, int count, Color color) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
