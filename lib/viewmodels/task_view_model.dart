import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/delivery_task.dart';
import '../repositories/task_repository.dart';
import '../services/task_service.dart';

class TaskViewModel extends ChangeNotifier {
  TaskViewModel({required TaskRepository taskRepository})
      : _taskRepository = taskRepository {
    _tasksSubscription = _taskRepository.watchTasks().listen(
      _handleCacheUpdate,
      onError: (error) {
        _errorMessage = 'Cache stream error: $error';
        notifyListeners();
      },
    );

    unawaited(_refreshQueueCount());
  }

  final TaskRepository _taskRepository;

  bool _isLoading = false;
  String? _errorMessage;
  List<DeliveryTask> _tasks = const [];
  bool _usingDemoData = false;
  bool _isOffline = false;
  int _pendingSyncCount = 0;
  DateTime? _lastSuccessfulSync;
  DateTime? _lastCacheUpdate;
  StreamSubscription<List<DeliveryTask>>? _tasksSubscription;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<DeliveryTask> get tasks => _tasks;
  bool get usingDemoData => _usingDemoData;
  bool get isOffline => _isOffline;
  int get pendingSyncCount => _pendingSyncCount;
  DateTime? get lastSuccessfulSync => _lastSuccessfulSync;
  DateTime? get lastCacheUpdate => _lastCacheUpdate;

  Future<void> loadTasks({bool forceRefresh = false}) async {
    if (_isLoading) {
      return;
    }

    _errorMessage = null;
    _setLoading(true);
    _usingDemoData = false;
    _isOffline = false;

    try {
      final fetched = await _taskRepository.refreshTasks();
      _tasks = fetched;
      _lastSuccessfulSync = DateTime.now();
      await _taskRepository.syncPendingDeliveries();
      await _refreshQueueCount();
      _isOffline = false;
    } on TaskApiException catch (error) {
      _handleRemoteError(error.message);
    } catch (error) {
      _handleRemoteError('Unexpected error: $error');
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
      final result = await _taskRepository.markAsDelivered(
        task,
        proofCode: proofCode,
      );

      if (result.queued) {
        _isOffline = true;
        _errorMessage = 'Queued delivery update; will sync when online.';
      } else {
        _isOffline = false;
      }

      await _refreshQueueCount();
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

  Future<void> saveProofOfDelivery(
    DeliveryTask task, {
    String? proofCode,
    String? photoUrl,
  }) async {
    _errorMessage = null;
    notifyListeners();

    if (_usingDemoData) {
      _tasks = _tasks
          .map(
            (item) => item.id == task.id
                ? item.copyWith(
                    proofCode: proofCode ?? item.proofCode,
                    proofPhotoUrl: photoUrl ?? item.proofPhotoUrl,
                  )
                : item,
          )
          .toList();
      notifyListeners();
      return;
    }

    try {
      await _taskRepository.saveProofOfDelivery(
        task,
        proofCode: proofCode,
        photoUrl: photoUrl,
      );
      _tasks = _tasks
          .map(
            (item) => item.id == task.id
                ? item.copyWith(
                    proofCode: proofCode ?? item.proofCode,
                    proofPhotoUrl: photoUrl ?? item.proofPhotoUrl,
                  )
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

  void _loadDemoData(String? message) {
    final demoTasks = _taskRepository.demoTasks();
    _tasks = demoTasks;
    _usingDemoData = true;
    _isOffline = false;
    _errorMessage = message ??
        'Backend unavailable. Showing OrderVista demo tasks instead.';
    unawaited(_taskRepository.cacheTasks(demoTasks));
    notifyListeners();
  }

  void _handleCacheUpdate(List<DeliveryTask> tasks) {
    if (_usingDemoData) {
      return;
    }

    _tasks = tasks;
    _lastCacheUpdate = DateTime.now();
    if (tasks.isNotEmpty) {
      _usingDemoData = false;
    }
    notifyListeners();
  }

  void _handleRemoteError(String message) {
    if (_tasks.isNotEmpty && !_usingDemoData) {
      _errorMessage = message;
      _isOffline = true;
      notifyListeners();
      return;
    }

    _loadDemoData(message);
  }

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    super.dispose();
  }

  Future<void> syncPendingDeliveries() async {
    try {
      final synced = await _taskRepository.syncPendingDeliveries();
      await _refreshQueueCount();
      if (synced > 0) {
        _isOffline = false;
        _errorMessage = null;
      }
    } catch (error) {
      _isOffline = true;
      _errorMessage ??= 'Delivery sync failed: $error';
    }
    notifyListeners();
  }

  Future<void> _refreshQueueCount() async {
    _pendingSyncCount = await _taskRepository.pendingQueueCount();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
