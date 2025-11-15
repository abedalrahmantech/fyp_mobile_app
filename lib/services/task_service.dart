import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/delivery_task.dart';

class TaskApiException implements Exception {
  TaskApiException(this.message);

  final String message;

  @override
  String toString() => 'TaskApiException: $message';
}

class TaskService {
  TaskService({http.Client? httpClient, String? baseUrl})
      : _client = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? _defaultBaseUrl;

  static const String _defaultBaseUrl = 'http://localhost:3000';

  final http.Client _client;
  final String _baseUrl;

  Uri _resolve(String path) => Uri.parse('$_baseUrl$path');

  /// Fetches tasks from the backend. Throws [TaskApiException] on failure.
  Future<List<DeliveryTask>> fetchTasks() async {
    final response = await _client.get(_resolve('/tasks'));
    if (response.statusCode != 200) {
      throw TaskApiException(
        'Unable to load tasks (status ${response.statusCode}).',
      );
    }

    try {
      final List<dynamic> payload = jsonDecode(response.body) as List<dynamic>;
      return payload
          .map((e) => DeliveryTask.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw TaskApiException('Unexpected response format: $error');
    }
  }

  /// Marks a task as complete by calling the backend.
  Future<void> completeTask(
    String taskId, {
    String? proofCode,
  }) async {
    final response = await _client.post(
      _resolve('/tasks/complete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
        {
          'taskId': taskId,
          if (proofCode != null && proofCode.isNotEmpty) 'proofCode': proofCode,
        },
      ),
    );

    if (response.statusCode != 200) {
      throw TaskApiException(
        'Failed to update task $taskId (status ${response.statusCode}).',
      );
    }
  }

  /// Provides sample data for offline demos or early iterations.
  List<DeliveryTask> demoTasks() => DeliveryTask.sampleTasks();
}
