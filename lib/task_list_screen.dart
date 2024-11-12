import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskPriority { High, Medium, Low }

enum SortBy { Priority, DueDate, CompletionStatus }

class TaskListScreen extends StatefulWidget {
  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _taskController = TextEditingController();
  TaskPriority? _selectedPriority = TaskPriority.Low;
  SortBy? _sortBy;
  bool _showCompletedOnly = false;
  TaskPriority? _filterPriority;

  void _addTask() {
    if (_taskController.text.trim().isNotEmpty && _selectedPriority != null) {
      FirebaseFirestore.instance.collection('tasks').add({
        'name': _taskController.text.trim(),
        'completed': false,
        'priority': _selectedPriority.toString().split('.').last,
        'dueDate': DateTime.now().add(Duration(days: 7)), // Dummy due date
      });
      _taskController.clear();
    }
  }

  void _toggleCompletion(String taskId, bool currentStatus) {
    FirebaseFirestore.instance.collection('tasks').doc(taskId).update({
      'completed': !currentStatus,
    });
  }

  void _deleteTask(String taskId) {
    FirebaseFirestore.instance.collection('tasks').doc(taskId).delete();
  }

  Query _getTaskQuery() {
    Query query = FirebaseFirestore.instance.collection('tasks');

    if (_filterPriority != null) {
      query = query.where('priority',
          isEqualTo: _filterPriority.toString().split('.').last);
    }
    if (_showCompletedOnly) {
      query = query.where('completed', isEqualTo: true);
    } else {
      query = query.where('completed', isEqualTo: false);
    }

    if (_sortBy == SortBy.Priority) {
      query = query.orderBy('priority');
    } else if (_sortBy == SortBy.DueDate) {
      query = query.orderBy('dueDate');
    } else if (_sortBy == SortBy.CompletionStatus) {
      query = query.orderBy('completed');
    }
    return query;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Task Manager with Priority')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: InputDecoration(hintText: 'Enter Task'),
                  ),
                ),
                DropdownButton<TaskPriority>(
                  hint: Text('Priority'),
                  value: _selectedPriority,
                  onChanged: (value) {
                    setState(() => _selectedPriority = value);
                  },
                  items: TaskPriority.values.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child: Text(priority.toString().split('.').last),
                    );
                  }).toList(),
                ),
                ElevatedButton(onPressed: _addTask, child: Text('Add')),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButton<TaskPriority>(
                hint: Text('Filter Priority'),
                value: _filterPriority,
                onChanged: (value) {
                  setState(() => _filterPriority = value);
                },
                items: [
                  DropdownMenuItem(value: null, child: Text('All')),
                  ...TaskPriority.values.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child: Text(priority.toString().split('.').last),
                    );
                  }).toList(),
                ],
              ),
              DropdownButton<SortBy>(
                hint: Text('Sort By'),
                value: _sortBy,
                onChanged: (value) {
                  setState(() => _sortBy = value);
                },
                items: SortBy.values.map((sortBy) {
                  return DropdownMenuItem(
                    value: sortBy,
                    child: Text(sortBy.toString().split('.').last),
                  );
                }).toList(),
              ),
              Switch(
                value: _showCompletedOnly,
                onChanged: (value) {
                  setState(() => _showCompletedOnly = value);
                },
              ),
              Text(_showCompletedOnly ? 'Show Completed' : 'Show Pending'),
            ],
          ),
          Expanded(
            child: StreamBuilder(
              stream: _getTaskQuery().snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                final tasks = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final taskId = task.id;
                    return TaskTile(
                      taskId: taskId,
                      taskName: task['name'],
                      completed: task['completed'],
                      priority: task['priority'],
                      dueDate: task['dueDate']?.toDate(),
                      onToggleComplete: () =>
                          _toggleCompletion(taskId, task['completed']),
                      onDelete: () => _deleteTask(taskId),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TaskTile extends StatelessWidget {
  final String taskId;
  final String taskName;
  final bool completed;
  final String priority;
  final DateTime? dueDate;
  final VoidCallback onToggleComplete;
  final VoidCallback onDelete;

  TaskTile({
    required this.taskId,
    required this.taskName,
    required this.completed,
    required this.priority,
    this.dueDate,
    required this.onToggleComplete,
    required this.onDelete,
  });

  Color _getPriorityColor() {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.yellow;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Checkbox(value: completed, onChanged: (_) => onToggleComplete()),
      title: Text(
        taskName,
        style: TextStyle(
          decoration: completed ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text('Due: ${dueDate != null ? dueDate.toString() : 'N/A'}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 8,
            backgroundColor: _getPriorityColor(),
          ),
          IconButton(icon: Icon(Icons.delete), onPressed: onDelete),
        ],
      ),
    );
  }
}
