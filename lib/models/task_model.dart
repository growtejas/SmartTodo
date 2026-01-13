import 'package:hive/hive.dart';

part 'task_model.g.dart';

@HiveType(typeId: 0)
class SubTask {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  bool isDone;

  SubTask({required this.id, required this.title, this.isDone = false});

  SubTask copyWith({String? id, String? title, bool? isDone}) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }
}

@HiveType(typeId: 1)
class Task {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  bool isDone;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime? dueDate;

  @HiveField(6)
  DateTime? reminder;

  @HiveField(7)
  String priority;

  @HiveField(8)
  String category;

  @HiveField(9)
  int orderIndex;

  @HiveField(10)
  List<SubTask> subTasks;

  @HiveField(11)
  bool isExpanded;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.isDone = false,
    required this.createdAt,
    this.dueDate,
    this.reminder,
    this.priority = 'medium',
    this.category = 'Personal',
    required this.orderIndex,
    this.subTasks = const [],
    this.isExpanded = false,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    bool? isDone,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? reminder,
    String? priority,
    String? category,
    int? orderIndex,
    List<SubTask>? subTasks,
    bool? isExpanded,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      reminder: reminder ?? this.reminder,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      orderIndex: orderIndex ?? this.orderIndex,
      subTasks: subTasks ?? this.subTasks,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  double get progress {
    if (subTasks.isEmpty) return isDone ? 1.0 : 0.0;
    final completed = subTasks.where((subTask) => subTask.isDone).length;
    return completed / subTasks.length;
  }

  bool get allSubTasksCompleted {
    return subTasks.isNotEmpty && subTasks.every((subTask) => subTask.isDone);
  }
}
