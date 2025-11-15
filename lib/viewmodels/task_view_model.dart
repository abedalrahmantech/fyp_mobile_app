import 'package:flutter/foundation.dart';

import '../models/delivery_task.dart';
import '../services/task_service.dart';

class TaskViewModel extends ChangeNotifier {
  TaskViewModel({required TaskService taskService})
      : _taskService = taskService;

  final TaskService _taskService;

  bool _isLoading = false;
  String? _errorMessage;
  List<DeliveryTask> _tasks = const [];
  bool _usingDemoData = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<DeliveryTask> get tasks => _tasks;
  bool get usingDemoData => _usingDemoData;

  Future<void> loadTasks({bool forceRefresh = false}) async {
    if (_isLoading) {
      return;
    }

    _setLoading(true);
    _errorMessage = null;
    _usingDemoData = false;

    try {
      final fetched = await _taskService.fetchTasks();
      _tasks = fetched;
    } on TaskApiException catch (error) {
      _errorMessage = error.message;
      _loadDemoData();
    } catch (error) {
      _errorMessage = 'Unexpected error: $error';
      _loadDemoData();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> markAsDelivered(
    DeliveryTask task, {
    String? proofCode,
  }) async {
    _errorMessage = null;
    notifyListeners();

    if (_usingDemoData) {
      _tasks = _tasks
          .map(
            (item) => item.id == task.id
                ? item.copyWith(status: 'delivered', proofCode: proofCode)
                : item,
          )
          .toList();
      notifyListeners();
      return;
    }

    try {
      await _taskService.completeTask(task.id, proofCode: proofCode);
      _tasks = _tasks
          .map(
            (item) => item.id == task.id
                ? item.copyWith(status: 'delivered', proofCode: proofCode)
                : item,
          )
          .toList();
      notifyListeners();
    } on TaskApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      rethrow;
    } catch (error) {
      _errorMessage = 'Unexpected error: $error';
      notifyListeners();
      rethrow;
    }
  }

  void _loadDemoData() {
    _tasks = _taskService.demoTasks();
    _usingDemoData = true;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
