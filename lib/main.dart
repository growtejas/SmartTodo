import 'package:flutter/material.dart';
import 'services/task_service.dart';
import 'models/task_model.dart';

//import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final taskService = TaskService();
    await taskService.init();
    runApp(TodoApp(taskService: taskService));
  } catch (e, stacktrace) {
    debugPrint('🔴 ERROR DURING INITIALIZATION: $e');
    debugPrint('🔴 Stacktrace: $stacktrace');
  }
}

class TodoApp extends StatelessWidget {
  final TaskService taskService;

  const TodoApp({super.key, required this.taskService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Todo App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: TodoHomePage(taskService: taskService),
    );
  }
}

class TodoHomePage extends StatefulWidget {
  final TaskService taskService;
  const TodoHomePage({super.key, required this.taskService});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  late List<Task> _tasks;
  bool _isLoading = true;
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _subTaskController = TextEditingController();
  String _selectedPriority = 'medium';
  String _selectedCategory = 'Personal';
  DateTime? _selectedDueDate;
  DateTime? _selectedReminder;
  String _filterCategory = 'All';
  final _addTaskFormKey = GlobalKey<FormState>();

  final List<String> _categories = [
    'All',
    'Personal',
    'Work',
    'Shopping',
    'Health',
    'Education',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _tasks = [];
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 500)); // Simulate loading

    setState(() {
      _tasks = widget.taskService.getAllTasks();
      if (_tasks.isEmpty) {
        _addSampleTasks();
      }
      _isLoading = false;
    });
  }

  void _addSampleTasks() {
    setState(() {
      _tasks.addAll([
        Task(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Welcome to Smart Todo!',
          description: 'This is your first task with subtasks feature.',
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 1)),
          priority: 'high',
          category: 'Personal',
          orderIndex: 0,
          subTasks: [
            SubTask(
              id: '${DateTime.now().millisecondsSinceEpoch}_1',
              title: 'Explore the app features',
            ),
            SubTask(
              id: '${DateTime.now().millisecondsSinceEpoch}_2',
              title: 'Try adding your own tasks',
            ),
          ],
        ),
      ]);
    });
  }

  Future<void> _addTask(List<SubTask> subTasks) async {
    if (!_addTaskFormKey.currentState!.validate()) {
      return;
    }

    try {
      if (_selectedReminder != null &&
          _selectedReminder!.isBefore(DateTime.now())) {
        throw Exception('Reminder time cannot be in the past');
      }

      if (_selectedDueDate != null &&
          _selectedDueDate!.isBefore(DateTime.now())) {
        throw Exception('Due date cannot be in the past');
      }

      final task = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _taskController.text.trim(),
        description: _descController.text.trim(),
        createdAt: DateTime.now(),
        dueDate: _selectedDueDate,
        reminder: _selectedReminder,
        priority: _selectedPriority,
        category: _selectedCategory,
        orderIndex: _tasks.length,
        subTasks: subTasks,
      );

      await widget.taskService.addTask(task);
      setState(() {
        _tasks.add(task);
      });
      _clearForm();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task added successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ✅ FIX 2: persist when adding a subtask from the task card
  void _addSubTask(Task task) async {
    if (_subTaskController.text.trim().isNotEmpty) {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index == -1) return;

      final newSubTask = SubTask(
        id: '${DateTime.now().millisecondsSinceEpoch}_sub',
        title: _subTaskController.text.trim(),
      );

      final updatedTask = task.copyWith(
        subTasks: [...task.subTasks, newSubTask],
      );

      await widget.taskService.updateTask(updatedTask); // persist
      setState(() {
        _tasks[index] = updatedTask;
        _subTaskController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Subtask added!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // ✅ FIX 1: persist every subtask toggle (not only when all are done)
  void _toggleSubTask(Task task, String subTaskId) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == task.id);
    if (taskIndex == -1) return;

    final updatedSubTasks = task.subTasks.map((subTask) {
      if (subTask.id == subTaskId) {
        return subTask.copyWith(isDone: !subTask.isDone);
      }
      return subTask;
    }).toList();

    final allSubtasksCompleted = updatedSubTasks.every((st) => st.isDone);

    final updatedTask = task.copyWith(
      subTasks: updatedSubTasks,
      isDone: allSubtasksCompleted ? true : task.isDone,
    );

    await widget.taskService.updateTask(updatedTask); // persist
    setState(() {
      _tasks[taskIndex] = updatedTask;
    });

    if (allSubtasksCompleted && !task.isDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'All subtasks completed! Task marked as done. 🎉',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green.shade600,
        ),
      );
    }
  }

  // ✅ FIX 3: persist when deleting a subtask
  void _deleteSubTask(Task task, String subTaskId) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == task.id);
    if (taskIndex == -1) return;

    final updatedSubTasks = task.subTasks
        .where((subTask) => subTask.id != subTaskId)
        .toList();

    final updatedTask = task.copyWith(subTasks: updatedSubTasks);

    await widget.taskService.updateTask(updatedTask); // persist
    setState(() {
      _tasks[taskIndex] = updatedTask;
    });
  }

  void _editTask(Task task) {
    final tempTaskController = TextEditingController(text: task.title);
    final tempDescController = TextEditingController(text: task.description);
    String tempPriority = task.priority;
    String tempCategory = task.category;
    DateTime? tempDueDate = task.dueDate;
    DateTime? tempReminder = task.reminder;
    List<SubTask> tempSubTasks = List.from(task.subTasks);
    final tempSubTaskController = TextEditingController();
    final editFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Task',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Form(
                        key: editFormKey,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              TextFormField(
                                controller: tempTaskController,
                                decoration: const InputDecoration(
                                  labelText: 'Task Title *',
                                  border: OutlineInputBorder(),
                                  hintText: 'Enter task title',
                                ),
                                maxLength: 100,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter a task title';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: tempDescController,
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  border: OutlineInputBorder(),
                                  hintText: 'Enter task description (optional)',
                                ),
                                maxLines: 3,
                                maxLength: 500,
                              ),
                              const SizedBox(height: 16),

                              // Subtasks Section in Edit Dialog
                              _buildSubTasksSection(
                                tempSubTasks,
                                tempSubTaskController,
                                setDialogState,
                                (newSubTasks) {
                                  tempSubTasks = newSubTasks;
                                },
                              ),
                              const SizedBox(height: 16),

                              DropdownButtonFormField<String>(
                                initialValue: tempCategory,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                ),
                                items: _categories
                                    .where((cat) => cat != 'All')
                                    .map((String category) {
                                      return DropdownMenuItem<String>(
                                        value: category,
                                        child: Text(category),
                                      );
                                    })
                                    .toList(),
                                onChanged: (String? newValue) {
                                  setDialogState(() {
                                    tempCategory = newValue!;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),

                              DropdownButtonFormField<String>(
                                initialValue: tempPriority,
                                decoration: const InputDecoration(
                                  labelText: 'Priority',
                                  border: OutlineInputBorder(),
                                ),
                                items: ['low', 'medium', 'high'].map((
                                  String priority,
                                ) {
                                  return DropdownMenuItem<String>(
                                    value: priority,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: _getPriorityColor(priority),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          priority.toUpperCase(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setDialogState(() {
                                    tempPriority = newValue!;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),

                              // Due Date with improved UX
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline
                                        .withAlpha((0.3 * 255).round()),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  leading: Icon(
                                    Icons.calendar_today,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  title: const Text('Due Date'),
                                  subtitle: Text(
                                    _formatDate(tempDueDate),
                                    style: TextStyle(
                                      color:
                                          _isOverdue(tempDueDate) &&
                                              !task.isDone
                                          ? Colors.red
                                          : null,
                                    ),
                                  ),
                                  trailing: tempDueDate != null
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            setDialogState(() {
                                              tempDueDate = null;
                                            });
                                          },
                                        )
                                      : null,
                                  onTap: () async {
                                    final DateTime? picked =
                                        await showDatePicker(
                                          context: context,
                                          initialDate:
                                              tempDueDate ?? DateTime.now(),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime(2100),
                                        );
                                    if (picked != null) {
                                      setDialogState(() {
                                        tempDueDate = picked;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (editFormKey.currentState!.validate()) {
                                final index = _tasks.indexWhere(
                                  (t) => t.id == task.id,
                                );
                                if (index != -1) {
                                  final updatedTask = task.copyWith(
                                    title: tempTaskController.text.trim(),
                                    description: tempDescController.text.trim(),
                                    priority: tempPriority,
                                    category: tempCategory,
                                    dueDate: tempDueDate,
                                    reminder: tempReminder,
                                    subTasks: tempSubTasks,
                                  );

                                  // ✅ FIX 4: persist edits (including subtasks) from the dialog
                                  await widget.taskService.updateTask(
                                    updatedTask,
                                  );

                                  setState(() {
                                    _tasks[index] = updatedTask;
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Task updated successfully!',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: Colors.green.shade600,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Save Changes'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubTasksSection(
    List<SubTask> subTasks,
    TextEditingController subTaskController,
    StateSetter setDialogState,
    Function(List<SubTask>) onSubTasksUpdate,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Subtasks',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${subTasks.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Add Subtask Input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: subTaskController,
                decoration: InputDecoration(
                  hintText: 'Add a subtask...',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  suffixIcon: subTaskController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            subTaskController.clear();
                            setDialogState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (value) => setDialogState(() {}),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    setDialogState(() {
                      final newSubTask = SubTask(
                        id: '${DateTime.now().millisecondsSinceEpoch}_sub',
                        title: value.trim(),
                      );
                      subTasks.add(newSubTask);
                      onSubTasksUpdate(List.from(subTasks));
                      subTaskController.clear();
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: subTaskController.text.trim().isNotEmpty
                  ? FloatingActionButton.small(
                      onPressed: () {
                        final newSubTask = SubTask(
                          id: '${DateTime.now().millisecondsSinceEpoch}_sub',
                          title: subTaskController.text.trim(),
                        );
                        subTasks.add(newSubTask);
                        onSubTasksUpdate(List.from(subTasks));
                        subTaskController.clear();
                        setDialogState(() {});
                      },
                      child: const Icon(Icons.add),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),

        // Subtasks List
        if (subTasks.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...subTasks.asMap().entries.map((entry) {
            final index = entry.key;
            final subTask = entry.value;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withAlpha((0.4 * 255).round()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withAlpha((0.1 * 255).round()),
                ),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                  onPressed: () {
                    setDialogState(() {
                      subTasks.removeAt(index);
                      onSubTasksUpdate(List.from(subTasks));
                    });
                  },
                ),
                title: Text(
                  subTask.title,
                  style: TextStyle(
                    fontSize: 14,
                    decoration: subTask.isDone
                        ? TextDecoration.lineThrough
                        : null,
                    color: subTask.isDone
                        ? Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha((0.4 * 255).round())
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                trailing: Checkbox(
                  value: subTask.isDone,
                  onChanged: (value) {
                    setDialogState(() {
                      subTasks[index] = subTask.copyWith(
                        isDone: value ?? false,
                      );

                      // Check if all subtasks are completed
                      final allSubtasksCompleted = subTasks.every(
                        (st) => st.isDone,
                      );
                      if (allSubtasksCompleted && subTasks.isNotEmpty) {
                        // Show a subtle indication that main task will be completed
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'All subtasks completed! Main task will be marked as done.',
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            backgroundColor: Colors.green.shade600,
                          ),
                        );
                      }

                      onSubTasksUpdate(List.from(subTasks));
                    });
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            );
          }),

          // Auto-completion hint
          if (subTasks.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withAlpha((0.2 * 255).round()),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Completing all subtasks will automatically mark the main task as done',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  void _clearForm() {
    _taskController.clear();
    _descController.clear();
    _subTaskController.clear();
    _selectedPriority = 'medium';
    _selectedCategory = 'Personal';
    _selectedDueDate = null;
    _selectedReminder = null;
  }

  Future<void> _toggleTask(String taskId) async {
    try {
      final index = _tasks.indexWhere((task) => task.id == taskId);
      if (index != -1) {
        final task = _tasks[index];
        final newCompletionState = !task.isDone;

        // Update all subtasks to match the main task's completion state
        final updatedSubTasks = task.subTasks.map((subTask) {
          return subTask.copyWith(isDone: newCompletionState);
        }).toList();

        final updatedTask = task.copyWith(
          isDone: newCompletionState,
          subTasks: updatedSubTasks,
        );

        await widget.taskService.updateTask(updatedTask);
        setState(() {
          _tasks[index] = updatedTask;
        });

        // Show feedback message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newCompletionState
                  ? 'Task completed! All subtasks updated. ✅'
                  : 'Task reopened. All subtasks updated. 🔄',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            backgroundColor: newCompletionState
                ? Colors.green.shade600
                : Colors.blue.shade600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating task: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _toggleTaskExpansion(String taskId) {
    setState(() {
      final index = _tasks.indexWhere((task) => task.id == taskId);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(
          isExpanded: !_tasks[index].isExpanded,
        );
      }
    });
  }

  Future<void> _deleteTask(String taskId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text(
          'Are you sure you want to delete this task? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.taskService.deleteTask(taskId);
      setState(() {
        _tasks.removeWhere((task) => task.id == taskId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task deleted successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final Task item = _tasks.removeAt(oldIndex);
      _tasks.insert(newIndex, item);

      for (int i = 0; i < _tasks.length; i++) {
        _tasks[i] = _tasks[i].copyWith(orderIndex: i);
      }
    });
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
  // Removed unused function _withOpacity

  String _formatDate(DateTime? date) {
    if (date == null) return 'No date set';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final taskDate = DateTime(date.year, date.month, date.day);

    if (taskDate == today) return 'Today';
    if (taskDate == tomorrow) return 'Tomorrow';
    return '${date.day}/${date.month}/${date.year}';
  }
  // Removed unused function _formatDateTime

  /*
  String _getWeekday(DateTime date) {
    switch (date.weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  String _getMonth(DateTime date) {
    switch (date.month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
      default:
        return '';
    }
  }
*/
  bool _isReminderSoon(DateTime? reminder) {
    if (reminder == null) return false;
    final now = DateTime.now();
    final difference = reminder.difference(now);
    return difference.inHours <= 24 && difference.isNegative == false;
  }

  bool _isOverdue(DateTime? dueDate) {
    if (dueDate == null) return false;
    return dueDate.isBefore(DateTime.now());
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else if (hour >= 17 && hour < 22) {
      return 'Good evening';
    } else {
      return 'Good night';
    }
  }

  List<Task> get _filteredTasks {
    var filtered = _tasks.where((task) {
      final categoryMatch =
          _filterCategory == 'All' || task.category == _filterCategory;
      return categoryMatch;
    }).toList();

    filtered.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final completedTasks = _tasks.where((task) => task.isDone).length;
    final totalTasks = _tasks.length;
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
    final filteredTasks = _filteredTasks;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Responsive Header Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth < 600 ? 20 : 32,
                vertical: screenWidth < 600 ? 20 : 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(
                      context,
                    ).colorScheme.primary.withAlpha((0.8 * 255).round()),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Smart Todo',
                              style: TextStyle(
                                fontSize: screenWidth < 600 ? 28 : 32,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getGreeting(),
                              style: TextStyle(
                                fontSize: screenWidth < 600 ? 14 : 16,
                                color: Theme.of(context).colorScheme.onPrimary
                                    .withAlpha((0.9 * 255).round()),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (screenWidth >
                          350) // Hide stats button on very small screens
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _showStatsDialog,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onPrimary
                                    .withAlpha((0.15 * 255).round()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.insights_outlined,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: screenWidth < 600 ? 20 : 24,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (totalTasks > 0) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Your Progress',
                              style: TextStyle(
                                fontSize: screenWidth < 600 ? 14 : 16,
                                color: Theme.of(context).colorScheme.onPrimary
                                    .withAlpha((0.9 * 255).round()),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '$completedTasks/$totalTasks',
                              style: TextStyle(
                                fontSize: screenWidth < 600 ? 14 : 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Progress bar without the celebration icon
                        Stack(
                          children: [
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .onPrimary
                                  .withAlpha((0.3 * 255).round()),
                              color: Theme.of(context).colorScheme.onPrimary,
                              borderRadius: BorderRadius.circular(10),
                              minHeight: 10,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      'Add your first task to get started! 🚀',
                      style: TextStyle(
                        fontSize: screenWidth < 600 ? 14 : 16,
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withAlpha((0.9 * 255).round()),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Responsive Category Filter
            Container(
              height: screenWidth < 600 ? 50 : 60,
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth < 600 ? 12 : 16,
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _filterCategory == category;
                  return Container(
                    margin: EdgeInsets.all(screenWidth < 600 ? 4 : 8),
                    child: FilterChip(
                      label: Text(
                        category,
                        style: TextStyle(fontSize: screenWidth < 600 ? 12 : 14),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _filterCategory = category;
                        });
                      },
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline.withAlpha(
                                (0.3 * 255).round(),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Tasks List with Loading State
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : filteredTasks.isEmpty
                  ? _buildEmptyState()
                  : ReorderableListView.builder(
                      padding: EdgeInsets.all(screenWidth < 600 ? 12 : 16),
                      itemCount: filteredTasks.length,
                      onReorder: _onReorder,
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];
                        return _buildTaskItem(task, index, screenWidth);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 4,
      ),
    );
  }

  void _showStatsDialog() {
    final overdueTasks = _tasks
        .where((task) => !task.isDone && _isOverdue(task.dueDate))
        .length;
    final dueTodayTasks = _tasks.where((task) {
      if (task.isDone || task.dueDate == null) return false;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDate = DateTime(
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
      );
      return dueDate.isAtSameMomentAs(today);
    }).length;
    // removed unused upcomingReminders
    _tasks
        .where((task) => !task.isDone && _isReminderSoon(task.reminder))
        .length;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Task Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              _buildStatItem(
                context,
                Icons.assignment_late_outlined,
                'Overdue Tasks',
                overdueTasks,
                Colors.red,
              ),
              const SizedBox(height: 16),
              _buildStatItem(
                context,
                Icons.today_outlined,
                'Due Today',
                dueTodayTasks,
                Colors.orange,
              ),
              const SizedBox(height: 16),
              _buildStatItem(
                context,
                Icons.check_circle_outline,
                'Completed Tasks',
                _tasks.where((task) => task.isDone).length,
                Colors.green,
              ),
              const SizedBox(height: 16),
              _buildStatItem(
                context,
                Icons.list_alt,
                'Total Tasks',
                _tasks.length,
                Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTaskDialog() {
    _clearForm();
    final newSubTasks = <SubTask>[];
    final newSubTaskController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add New Task',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Form(
                        key: _addTaskFormKey,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _taskController,
                                decoration: const InputDecoration(
                                  labelText: 'Task Title *',
                                  border: OutlineInputBorder(),
                                  hintText: 'What needs to be done?',
                                  prefixIcon: Icon(Icons.task_outlined),
                                ),
                                maxLength: 100,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter a task title';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _descController,
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  border: OutlineInputBorder(),
                                  hintText: 'Add more details... (optional)',
                                  prefixIcon: Icon(Icons.description_outlined),
                                ),
                                maxLines: 3,
                                maxLength: 500,
                              ),
                              const SizedBox(height: 16),

                              // Subtasks Section
                              _buildSubTasksSection(
                                newSubTasks,
                                newSubTaskController,
                                setDialogState,
                                (updatedSubTasks) {
                                  newSubTasks.clear();
                                  newSubTasks.addAll(updatedSubTasks);
                                },
                              ),
                              const SizedBox(height: 16),

                              DropdownButtonFormField<String>(
                                initialValue: _selectedCategory,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.category_outlined),
                                ),
                                items: _categories
                                    .where((cat) => cat != 'All')
                                    .map((String category) {
                                      return DropdownMenuItem<String>(
                                        value: category,
                                        child: Text(category),
                                      );
                                    })
                                    .toList(),
                                onChanged: (String? newValue) {
                                  setDialogState(() {
                                    _selectedCategory = newValue!;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),

                              DropdownButtonFormField<String>(
                                initialValue: _selectedPriority,
                                decoration: const InputDecoration(
                                  labelText: 'Priority',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.flag_outlined),
                                ),
                                items: ['low', 'medium', 'high'].map((
                                  String priority,
                                ) {
                                  return DropdownMenuItem<String>(
                                    value: priority,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: _getPriorityColor(priority),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          priority.toUpperCase(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setDialogState(() {
                                    _selectedPriority = newValue!;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),

                              // Due Date
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline
                                        .withAlpha((0.3 * 255).round()),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  leading: Icon(
                                    Icons.calendar_today_outlined,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  title: const Text('Due Date'),
                                  subtitle: Text(_formatDate(_selectedDueDate)),
                                  trailing: _selectedDueDate != null
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            setDialogState(() {
                                              _selectedDueDate = null;
                                            });
                                          },
                                        )
                                      : null,
                                  onTap: () async {
                                    final DateTime? picked =
                                        await showDatePicker(
                                          context: context,
                                          initialDate:
                                              _selectedDueDate ??
                                              DateTime.now(),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime(2100),
                                        );
                                    if (picked != null) {
                                      setDialogState(() {
                                        _selectedDueDate = picked;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (_addTaskFormKey.currentState!.validate()) {
                                _addTask(newSubTasks);
                                Navigator.of(context).pop();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Create Task'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String label,
    int count,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((0.2 * 255).round())),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha((0.2 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((0.8 * 255).round()),
                  ),
                ),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading your tasks...',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.checklist_rounded,
              size: 80,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withAlpha((0.3 * 255).round()),
            ),
            const SizedBox(height: 20),
            Text(
              'No tasks found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((0.5 * 255).round()),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing filters or add a new task',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((0.4 * 255).round()),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showAddTaskDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Task'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(Task task, int index, double screenWidth) {
    final isOverdue = _isOverdue(task.dueDate);
    final completedSubTasks = task.subTasks
        .where((subTask) => subTask.isDone)
        .length;
    final totalSubTasks = task.subTasks.length;
    final subTaskProgress = totalSubTasks > 0
        ? completedSubTasks / totalSubTasks
        : 0.0;

    return Card(
      key: Key(task.id),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: task.isDone
          ? Theme.of(context).colorScheme.surface.withAlpha((0.6 * 255).round())
          : Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Main Task
          ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: screenWidth < 600 ? 12 : 16,
              vertical: 8,
            ),
            leading: ReorderableDragStartListener(
              index: index,
              child: Checkbox(
                value: task.isDone,
                onChanged: (value) => _toggleTask(task.id),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: screenWidth < 600 ? 15 : 16,
                          fontWeight: FontWeight.w500,
                          decoration: task.isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: task.isDone
                              ? Theme.of(context).colorScheme.onSurface
                                    .withAlpha((0.4 * 255).round())
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isOverdue && !task.isDone)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.red.withAlpha((0.3 * 255).round()),
                          ),
                        ),
                        child: Text(
                          'OVERDUE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description,
                    style: TextStyle(
                      fontSize: screenWidth < 600 ? 13 : 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
                      decoration: task.isDone
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer
                            .withAlpha((0.2 * 255).round()),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    if (task.dueDate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isOverdue && !task.isDone
                              ? Colors.red.withAlpha((0.1 * 255).round())
                              : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha((0.5 * 255).round()),
                          borderRadius: BorderRadius.circular(6),
                          border: isOverdue && !task.isDone
                              ? Border.all(
                                  color: Colors.red.withAlpha(
                                    (0.3 * 255).round(),
                                  ),
                                )
                              : null,
                        ),
                        child: Text(
                          _formatDate(task.dueDate),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isOverdue && !task.isDone
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isOverdue && !task.isDone
                                ? Colors.red
                                : null,
                          ),
                        ),
                      ),
                    if (task.subTasks.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.checklist_rtl_outlined,
                              size: 12,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$completedSubTasks/$totalSubTasks',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (task.subTasks.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      task.isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                    ),
                    onPressed: () => _toggleTaskExpansion(task.id),
                  ),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(task.priority),
                    shape: BoxShape.circle,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text('Edit', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(fontSize: 14, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editTask(task);
                    } else if (value == 'delete') {
                      _deleteTask(task.id);
                    }
                  },
                ),
              ],
            ),
            onTap: () => _editTask(task),
          ),

          // Subtasks Progress Bar (if any subtasks exist)
          if (task.subTasks.isNotEmpty && !task.isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: subTaskProgress,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(subTaskProgress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
                    ),
                  ),
                ],
              ),
            ),

          // Subtasks Section
          if (task.isExpanded && task.subTasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Add Subtask Input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _subTaskController,
                          decoration: InputDecoration(
                            hintText: 'Add a subtask...',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            suffixIcon: _subTaskController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => _subTaskController.clear(),
                                  )
                                : null,
                          ),
                          onSubmitted: (value) => _addSubTask(task),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: _subTaskController.text.trim().isNotEmpty
                            ? FloatingActionButton.small(
                                onPressed: () => _addSubTask(task),
                                child: const Icon(Icons.add),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Subtasks List
                  ...task.subTasks.map((subTask) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withAlpha((0.3 * 255).round()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          leading: Checkbox(
                            value: subTask.isDone,
                            onChanged: (value) =>
                                _toggleSubTask(task, subTask.id),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          title: Text(
                            subTask.title,
                            style: TextStyle(
                              fontSize: 14,
                              decoration: subTask.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: subTask.isDone
                                  ? Theme.of(context).colorScheme.onSurface
                                        .withAlpha((0.4 * 255).round())
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => _deleteSubTask(task, subTask.id),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
