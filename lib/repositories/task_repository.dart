import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/ordervista_database.dart';
import '../models/delivery_task.dart';
import '../services/task_service.dart';

class TaskRepository {
  TaskRepository({
    required this.database,
    required this.taskService,
    required this.companyId,
    required this.driverId,
  });

  static const int _maxAttempts = 5;

  final OrderVistaDatabase database;
  final TaskService taskService;
  final String companyId;
  final String driverId;

  Stream<List<DeliveryTask>> watchTasks() {
    final query = database.select(database.driftTasks)
      ..orderBy([
        (tbl) => OrderingTerm(
              expression: tbl.updatedAt,
              mode: OrderingMode.desc,
            ),
      ]);

    return query.watch().map(
          (rows) => rows.map(_mapRowToDeliveryTask).toList(),
        );
  }

  Future<List<DeliveryTask>> refreshTasks() async {
    final remoteTasks = await taskService.fetchTasks();
    await _replaceCache(remoteTasks);
    return remoteTasks;
  }

  Future<void> cacheTasks(List<DeliveryTask> tasks) async {
    await _replaceCache(tasks);
  }

  Future<int> pendingQueueCount() async {
    final rows = await (database.select(database.driftSyncQueue)
          ..where((row) => row.status.equals('pending')))
        .get();
    return rows.length;
  }

  Future<DeliverySyncResult> markAsDelivered(
    DeliveryTask task, {
    String? proofCode,
  }) async {
    try {
      await taskService.completeTask(task.id, proofCode: proofCode);
      await _applyLocalDelivery(task.id, proofCode: proofCode);
      return const DeliverySyncResult(synced: true, queued: false);
    } catch (_) {
      await _enqueueDeliveryCompletion(task, proofCode: proofCode);
      await _applyLocalDelivery(task.id, proofCode: proofCode);
      return const DeliverySyncResult(synced: false, queued: true);
    }
  }

  List<DeliveryTask> demoTasks() => taskService.demoTasks();

  DriftTasksCompanion _mapDeliveryTaskToCompanion(DeliveryTask task) {
    return DriftTasksCompanion(
      id: Value(task.id),
      companyId: Value(companyId.isNotEmpty ? companyId : 'demo-company'),
      address: Value(task.address),
      status: Value(task.status),
      notes: const Value.absent(),
      proofCode: Value(task.proofCode),
      proofPhotoUrl: const Value.absent(),
      scheduledStart: Value(task.scheduledAt),
      scheduledEnd: const Value.absent(),
      updatedAt: Value(task.scheduledAt ?? DateTime.now().toUtc()),
    );
  }

  DeliveryTask _mapRowToDeliveryTask(DriftTask row) {
    return DeliveryTask(
      id: row.id,
      address: row.address,
      status: row.status,
      scheduledAt: row.scheduledStart,
      proofCode: row.proofCode,
    );
  }

  Future<void> _applyLocalDelivery(
    String taskId, {
    String? proofCode,
  }) async {
    await (database.update(database.driftTasks)
          ..where((row) => row.id.equals(taskId)))
        .write(
      DriftTasksCompanion(
        status: const Value('delivered'),
        proofCode: Value(proofCode),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> _enqueueDeliveryCompletion(
    DeliveryTask task, {
    String? proofCode,
  }) async {
    final payload = jsonEncode({
      'taskId': task.id,
      if (proofCode != null && proofCode.isNotEmpty) 'proofCode': proofCode,
    });

    await database.into(database.driftSyncQueue).insert(
          DriftSyncQueueCompanion.insert(
            companyId: companyId,
            driverId: driverId,
            actionType: 'task_complete',
            payloadJson: payload,
          ),
        );
  }

  Future<int> syncPendingDeliveries() async {
    final pending = await (database.select(database.driftSyncQueue)
          ..where((row) => row.status.equals('pending'))
          ..orderBy([(row) => OrderingTerm(expression: row.id)]))
        .get();

    var syncedCount = 0;
    for (final item in pending) {
      if (!_backoffElapsed(item.lastAttemptAt, item.attempts)) {
        continue;
      }

      try {
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final taskId = payload['taskId']?.toString();
        final proofCode = payload['proofCode']?.toString();
        if (taskId == null || taskId.isEmpty) {
          await _markQueueItemFailed(item.id, item.attempts, permanent: true);
          continue;
        }

        await taskService.completeTask(taskId, proofCode: proofCode);
        await _applyLocalDelivery(taskId, proofCode: proofCode);
        await _deleteQueueItem(item.id);
        syncedCount++;
      } catch (_) {
        await _markQueueItemFailed(item.id, item.attempts);
      }
    }

    return syncedCount;
  }

  Future<void> _deleteQueueItem(int id) async {
    await (database.delete(database.driftSyncQueue)
          ..where((row) => row.id.equals(id)))
        .go();
  }

  bool _backoffElapsed(DateTime? lastAttemptAt, int attempts) {
    if (lastAttemptAt == null) {
      return true;
    }

    final now = DateTime.now().toUtc();
    final backoff = _backoffForAttempts(attempts);
    return now.difference(lastAttemptAt) >= backoff;
  }

  Duration _backoffForAttempts(int attempts) {
    const scheduleSeconds = [0, 10, 30, 60, 120];
    final index = attempts.clamp(0, scheduleSeconds.length - 1);
    return Duration(seconds: scheduleSeconds[index]);
  }

  Future<void> _markQueueItemFailed(int id, int attempts,
      {bool permanent = false}) async {
    final nextAttempts = permanent ? _maxAttempts : attempts + 1;
    final status =
        permanent || nextAttempts >= _maxAttempts ? 'failed' : 'pending';
    await (database.update(database.driftSyncQueue)
          ..where((row) => row.id.equals(id)))
        .write(
      DriftSyncQueueCompanion(
        status: Value(status),
        attempts: Value(nextAttempts),
        lastAttemptAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> _replaceCache(List<DeliveryTask> tasks) async {
    await database.transaction(() async {
      await database.delete(database.driftRouteTasks).go();
      await database.delete(database.driftRoutes).go();
      await database.delete(database.driftTasks).go();

      if (tasks.isEmpty) {
        return;
      }

      await database.batch((batch) {
        batch.insertAllOnConflictUpdate(
          database.driftTasks,
          tasks.map(_mapDeliveryTaskToCompanion).toList(),
        );
      });
    });
  }
}

class DeliverySyncResult {
  const DeliverySyncResult({required this.synced, required this.queued});

  final bool synced;
  final bool queued;
}
