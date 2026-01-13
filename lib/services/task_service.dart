import 'package:flutter/foundation.dart'; // Keep for debugPrint if needed, or remove if not used
import 'package:hive_flutter/hive_flutter.dart';
import '../models/task_model.dart';
// REMOVED: import 'notification_service.dart';

class TaskService {
  static const String _boxName = 'tasks';
  late Box<Task> _taskBox;

  // Initialization remains the same
  Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SubTaskAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TaskAdapter());
    }

    // Open the box
    _taskBox = await Hive.openBox<Task>(_boxName);
  }

  // Add task without notification scheduling
  Future<void> addTask(Task task) async {
    try {
      // Input validation could be added here if needed
      await _taskBox.put(task.id, task);
      debugPrint('TaskService: Added task ${task.id}');
      // REMOVED: Notification scheduling logic
    } catch (e) {
      debugPrint('Error adding task: $e'); // Use debugPrint for consistency
      rethrow; // Rethrow to allow UI to handle error
    }
  }

  // Update task without notification logic
  Future<void> updateTask(Task task) async {
    try {
      if (!_taskBox.containsKey(task.id)) {
        // Optionally handle case where task might have been deleted elsewhere
        debugPrint(
          'TaskService: Attempted to update non-existent task ${task.id}',
        );
        return; // Or throw Exception('Task not found');
      }
      //final Task? oldTask = _taskBox.get(task.id); // Get old task if needed for comparison, but not for notifications now
      await _taskBox.put(task.id, task);
      debugPrint('TaskService: Updated task ${task.id}');

      // REMOVED: Reminder update/cancellation logic
    } catch (e) {
      debugPrint('Error updating task: $e');
      rethrow;
    }
  }

  // Update multiple tasks (e.g., for reordering)
  // More efficient than calling updateTask individually in a loop
  Future<void> updateTasks(List<Task> tasks) async {
    try {
      final Map<String, Task> taskMap = {for (var task in tasks) task.id: task};
      await _taskBox.putAll(taskMap);
      debugPrint('TaskService: Updated batch of ${tasks.length} tasks');
    } catch (e) {
      debugPrint('Error updating tasks batch: $e');
      rethrow;
    }
  }

  // Delete task without notification cancellation
  Future<void> deleteTask(String taskId) async {
    try {
      if (!_taskBox.containsKey(taskId)) {
        debugPrint(
          'TaskService: Attempted to delete non-existent task $taskId',
        );
        return; // Or throw Exception('Task not found');
      }
      await _taskBox.delete(taskId);
      debugPrint('TaskService: Deleted task $taskId');
      // REMOVED: Notification cancellation logic
    } catch (e) {
      debugPrint('Error deleting task: $e');
      rethrow;
    }
  }

  // Get all tasks, sorted by orderIndex
  List<Task> getAllTasks() {
    try {
      final tasks = _taskBox.values.toList();
      // Sort tasks by orderIndex to maintain order
      tasks.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return tasks;
    } catch (e) {
      debugPrint('Error getting all tasks: $e');
      return []; // Return empty list on error
    }
  }

  // Reorder tasks - simplified by calling updateTasks for batch update
  // Note: The logic to determine the new order happens in the UI (_onReorder)
  // This function is now less necessary if _updateTaskOrderIndices calls updateTasks directly.
  // Keeping it here for potential future use or if you prefer this structure.
  Future<void> reorderTasks(List<Task> orderedTasks) async {
    // The UI layer should have already updated the orderIndex in orderedTasks
    await updateTasks(orderedTasks);
  }

  // Close the Hive box (good practice for app lifecycle management)
  Future<void> closeBox() async {
    try {
      await _taskBox.close();
    } catch (e) {
      debugPrint('Error closing task box: $e');
    }
  }
}
