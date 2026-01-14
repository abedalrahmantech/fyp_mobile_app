// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:meal_order_mini_app_u_i_template/data/ordervista_database.dart';
import 'package:meal_order_mini_app_u_i_template/models/delivery_task.dart';
import 'package:meal_order_mini_app_u_i_template/repositories/task_repository.dart';
import 'package:meal_order_mini_app_u_i_template/services/task_service.dart';
import 'package:meal_order_mini_app_u_i_template/viewmodels/task_view_model.dart';

class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository({this.shouldQueue = false});

  final bool shouldQueue;
  final StreamController<List<DeliveryTask>> _controller =
      StreamController.broadcast();
  int pending = 0;
  final OrderVistaDatabase _db = OrderVistaDatabase.inMemory();
  final TaskService _service = _FakeTaskService();

  void seed(List<DeliveryTask> tasks) {
    _controller.add(tasks);
  }

  @override
  OrderVistaDatabase get database => _db;

  @override
  TaskService get taskService => _service;

  @override
  String get companyId => 'test-company';

  @override
  String get driverId => 'test-driver';

  @override
  Stream<List<DeliveryTask>> watchTasks() => _controller.stream;

  @override
  Future<List<DeliveryTask>> refreshTasks() async {
    final tasks = [
      DeliveryTask(
        id: '1',
        address: '123 Demo St',
        status: 'pending',
        scheduledAt: DateTime.utc(2024, 1, 1, 12),
      ),
    ];
    _controller.add(tasks);
    return tasks;
  }

  @override
  Future<DeliverySyncResult> markAsDelivered(
    DeliveryTask task, {
    String? proofCode,
  }) async {
    if (shouldQueue) {
      pending = 1;
      _controller.add([
        task.copyWith(status: 'delivered', proofCode: proofCode),
      ]);
      return const DeliverySyncResult(synced: false, queued: true);
    }

    _controller.add([
      task.copyWith(status: 'delivered', proofCode: proofCode),
    ]);
    return const DeliverySyncResult(synced: true, queued: false);
  }

  @override
  List<DeliveryTask> demoTasks() => const [];

  @override
  Future<void> cacheTasks(List<DeliveryTask> tasks) async {}

  @override
  Future<int> pendingQueueCount() async => pending;

  @override
  Future<int> syncPendingDeliveries() async {
    pending = 0;
    return 1;
  }

  Future<void> close() async {
    await _controller.close();
    await _db.close();
  }
}

class _FakeTaskService implements TaskService {
  @override
  Future<void> completeTask(String taskId, {String? proofCode}) async {}

  @override
  List<DeliveryTask> demoTasks() => const [];

  @override
  Future<List<DeliveryTask>> fetchTasks() async => const [];
}

void main() {
  test('loadTasks populates tasks and resets offline flag', () async {
    final repo = _FakeTaskRepository();
    repo.seed(const []);
    final viewModel = TaskViewModel(taskRepository: repo);

    await viewModel.loadTasks();

    expect(viewModel.tasks, isNotEmpty);
    expect(viewModel.isOffline, isFalse);
    await repo.close();
  });

  test('markAsDelivered queues when offline and tracks pending count',
      () async {
    final repo = _FakeTaskRepository(shouldQueue: true);
    repo.seed([
      DeliveryTask(
        id: '1',
        address: '123 Demo St',
        status: 'pending',
        scheduledAt: DateTime.utc(2024, 1, 1, 12),
      ),
    ]);
    final viewModel = TaskViewModel(taskRepository: repo);

    final task = viewModel.tasks.isNotEmpty
        ? viewModel.tasks.first
        : DeliveryTask(
            id: '1',
            address: '123 Demo St',
            status: 'pending',
            scheduledAt: DateTime.utc(2024, 1, 1, 12),
          );

    await viewModel.markAsDelivered(task, proofCode: 'ABC');

    expect(viewModel.isOffline, isTrue);
    await viewModel.syncPendingDeliveries();
    expect(viewModel.pendingSyncCount, equals(0));
    await repo.close();
  });
}
