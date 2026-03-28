import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/delivery_task.dart';
import '../repositories/task_repository.dart';
import '../services/mapbox_service.dart';
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

  /// When non-null, overrides the default sort with a GPS-based sequence.
  List<String>? _routeSequenceOverride;
  DateTime? _lastResequenceTime;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<DeliveryTask> get tasks => _sortTasks(_tasks);
  bool get usingDemoData => _usingDemoData;
  bool get isOffline => _isOffline;
  int get pendingSyncCount => _pendingSyncCount;
  DateTime? get lastSuccessfulSync => _lastSuccessfulSync;
  DateTime? get lastCacheUpdate => _lastCacheUpdate;
  bool get hasRouteOverride => _routeSequenceOverride != null;
  DateTime? get lastResequenceTime => _lastResequenceTime;

  /// Sorts tasks with the following priority:
  /// 1. Pending/in-transit tasks come before delivered tasks
  /// 2. Within same status group, sort by effective priority (higher first)
  ///    — effective priority = base priority + time-urgency bonus
  /// 3. Then by scheduled time (earlier first)
  /// 4. Finally by creation/ID for consistency
  List<DeliveryTask> _sortTasks(List<DeliveryTask> tasks) {
    final now = DateTime.now();
    final sorted = List<DeliveryTask>.from(tasks);

    // If a GPS-based route override exists, use it for active tasks
    if (_routeSequenceOverride != null) {
      final seq = _routeSequenceOverride!;
      sorted.sort((a, b) {
        final statusOrder = {'pending': 0, 'in-transit': 1, 'delivered': 2};
        final statusA = statusOrder[a.status.toLowerCase()] ?? 1;
        final statusB = statusOrder[b.status.toLowerCase()] ?? 1;
        if (statusA != statusB) return statusA.compareTo(statusB);

        // Within active tasks, use the optimised sequence
        final idxA = seq.indexOf(a.id);
        final idxB = seq.indexOf(b.id);
        final posA = idxA >= 0 ? idxA : 9999;
        final posB = idxB >= 0 ? idxB : 9999;
        if (posA != posB) return posA.compareTo(posB);

        return a.id.compareTo(b.id);
      });
      return sorted;
    }

    sorted.sort((a, b) {
      // First: status priority (pending > in-transit > delivered)
      final statusOrder = {'pending': 0, 'in-transit': 1, 'delivered': 2};
      final statusA = statusOrder[a.status.toLowerCase()] ?? 1;
      final statusB = statusOrder[b.status.toLowerCase()] ?? 1;
      if (statusA != statusB) return statusA.compareTo(statusB);

      // Second: effective priority (higher first, so reverse comparison)
      final effectiveA = computeEffectivePriority(a, now);
      final effectiveB = computeEffectivePriority(b, now);
      if (effectiveA != effectiveB) {
        return effectiveB.compareTo(effectiveA);
      }

      // Third: scheduled time (earlier first)
      if (a.scheduledAt != null && b.scheduledAt != null) {
        return a.scheduledAt!.compareTo(b.scheduledAt!);
      }
      if (a.scheduledAt != null) return -1;
      if (b.scheduledAt != null) return 1;

      // Finally: by ID for consistency
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  /// Computes dynamic effective priority:
  ///   base priority + urgency bonus based on time window.
  /// - Overdue (past scheduled time): +50
  /// - Within 30 minutes: +30
  /// - Within 1 hour: +20
  /// - Within 2 hours: +10
  static int computeEffectivePriority(DeliveryTask task, DateTime now) {
    if (task.status.toLowerCase() == 'delivered') return task.priority;
    if (task.scheduledAt == null) return task.priority;

    final diff = task.scheduledAt!.difference(now);
    int bonus = 0;
    if (diff.isNegative) {
      bonus = 50; // overdue
    } else if (diff.inMinutes <= 30) {
      bonus = 30; // imminent
    } else if (diff.inMinutes <= 60) {
      bonus = 20; // approaching
    } else if (diff.inMinutes <= 120) {
      bonus = 10; // upcoming
    }
    return task.priority + bonus;
  }

  /// Returns urgency label for UI display.
  static String? urgencyLabel(DeliveryTask task, DateTime now) {
    if (task.status.toLowerCase() == 'delivered') return null;
    if (task.scheduledAt == null) return null;

    final diff = task.scheduledAt!.difference(now);
    if (diff.isNegative) return 'OVERDUE';
    if (diff.inMinutes <= 30) return 'IMMINENT';
    if (diff.inMinutes <= 60) return 'APPROACHING';
    if (diff.inMinutes <= 120) return 'UPCOMING';
    return null;
  }

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

  Future<void> updateTaskStatus(String taskId, String newStatus) async {
    _errorMessage = null;
    notifyListeners();

    if (_usingDemoData) {
      _tasks = _tasks
          .map((item) =>
              item.id == taskId ? item.copyWith(status: newStatus) : item)
          .toList();
      notifyListeners();
      return;
    }

    try {
      await _taskRepository.updateTaskStatus(taskId, newStatus);
      // Optimistic update for immediate UI feedback
      _tasks = _tasks
          .map((item) =>
              item.id == taskId ? item.copyWith(status: newStatus) : item)
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

  /// Re-sequences remaining active tasks by nearest-neighbour from the
  /// driver's current GPS location. Geocodes each task address via Mapbox,
  /// then computes the optimised visit order.
  Future<void> resequenceFromLocation(
    GeoPoint driverLocation,
    MapboxService mapbox,
  ) async {
    final activeTasks = _tasks.where(
      (t) => t.status.toLowerCase() != 'delivered',
    );
    if (activeTasks.length < 2) return; // nothing to optimise

    final Map<String, GeoPoint> points = {};
    for (final t in activeTasks) {
      if (t.address.isEmpty) continue;
      try {
        final geo = await mapbox.forwardGeocode(t.address);
        if (geo != null) {
          points[t.id] = geo;
        }
      } catch (_) {
        // skip tasks that fail geocoding
      }
    }
    if (points.length < 2) return;

    _routeSequenceOverride =
        MapboxService.nearestNeighbourSequence(driverLocation, points);
    _lastResequenceTime = DateTime.now();
    notifyListeners();
  }

  /// Clears the GPS-based route override, restoring priority-based sort.
  void clearRouteOverride() {
    _routeSequenceOverride = null;
    _lastResequenceTime = null;
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
