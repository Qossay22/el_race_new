import 'package:flutter/material.dart';
import '../../tasks/data/task_model.dart';
import '../screens/task_details.dart';

class TaskCardWidget extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onToggleComplete;

  const TaskCardWidget({
    Key? key,
    required this.task,
    required this.onToggleComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, TaskDetailsScreen.routeName);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name ?? 'No title',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task.description ?? 'No description',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  task.isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: task.isCompleted ? Colors.green : Colors.grey,
                ),
                onPressed: onToggleComplete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
