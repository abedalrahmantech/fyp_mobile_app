import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/delivery_task.dart';
import 'app_logger.dart';

class TaskApiException implements Exception {
  TaskApiException(this.message);

  final String message;

  @override
  String toString() => 'TaskApiException: $message';
}

class TaskService {
  TaskService({
    required SupabaseClient client,
    required String companyId,
    required String driverId,
  })  : _client = client,
        _companyId = companyId,
        _driverId = driverId;

  final SupabaseClient _client;
  final String _companyId;
  final String _driverId;

  Future<List<DeliveryTask>> fetchTasks() async {
    _assertConfiguration();
    final correlationId = AppLogger.newCorrelationId();
    AppLogger.event(
      'tasks.fetch.start',
      correlationId: correlationId,
      data: {'companyId': _companyId, 'driverId': _driverId},
    );
    try {
      final result = await _client
          .from('tasks')
          .select()
          .eq('company_id', _companyId)
          .eq('driver_id', _driverId)
          .order('scheduled_start', ascending: true);

      final rows = result as List<dynamic>;
      AppLogger.event(
        'tasks.fetch.success',
        correlationId: correlationId,
        data: {'count': rows.length},
      );
      return rows.map((row) => _mapRow(row as Map<String, dynamic>)).toList();
    } on PostgrestException catch (error) {
      AppLogger.event(
        'tasks.fetch.error',
        level: 'error',
        correlationId: correlationId,
        data: {'message': error.message, 'code': error.code},
      );
      throw TaskApiException(
        error.message.isNotEmpty
            ? error.message
            : 'Supabase error (${error.code}).',
      );
    } catch (error) {
      AppLogger.event(
        'tasks.fetch.error',
        level: 'error',
        correlationId: correlationId,
        data: {'error': error.toString()},
      );
      throw TaskApiException('Unexpected Supabase error: $error');
    }
  }

  Future<void> completeTask(
    String taskId, {
    String? proofCode,
  }) async {
    _assertConfiguration();
    final correlationId = AppLogger.newCorrelationId();
    AppLogger.event(
      'tasks.complete.start',
      correlationId: correlationId,
      data: {'taskId': taskId},
    );
    final payload = <String, dynamic>{
      'status': 'delivered',
      if (proofCode != null && proofCode.isNotEmpty) 'proof_code': proofCode,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await _client
          .from('tasks')
          .update(payload)
          .eq('company_id', _companyId)
          .eq('driver_id', _driverId)
          .eq('id', taskId)
          .select('id')
          .maybeSingle();

      if (response == null) {
        throw TaskApiException('Task $taskId was not found for this driver.');
      }
      AppLogger.event(
        'tasks.complete.success',
        correlationId: correlationId,
        data: {'taskId': taskId},
      );
    } on PostgrestException catch (error) {
      AppLogger.event(
        'tasks.complete.error',
        level: 'error',
        correlationId: correlationId,
        data: {'message': error.message, 'code': error.code},
      );
      throw TaskApiException(
        error.message.isNotEmpty
            ? error.message
            : 'Supabase error (${error.code}).',
      );
    } catch (error) {
      AppLogger.event(
        'tasks.complete.error',
        level: 'error',
        correlationId: correlationId,
        data: {'error': error.toString()},
      );
      throw TaskApiException('Unexpected Supabase error: $error');
    }
  }

  Future<void> saveProofOfDelivery(
    String taskId, {
    String? proofCode,
    String? photoUrl,
  }) async {
    _assertConfiguration();
    final correlationId = AppLogger.newCorrelationId();
    AppLogger.event(
      'tasks.pod.start',
      correlationId: correlationId,
      data: {'taskId': taskId},
    );
    final payload = <String, dynamic>{
      if (proofCode != null && proofCode.isNotEmpty) 'proof_code': proofCode,
      if (photoUrl != null && photoUrl.isNotEmpty) 'proof_photo_url': photoUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (payload.length == 1) {
      throw TaskApiException('Proof code or photo URL is required.');
    }

    try {
      final response = await _client
          .from('tasks')
          .update(payload)
          .eq('company_id', _companyId)
          .eq('driver_id', _driverId)
          .eq('id', taskId)
          .select('id')
          .maybeSingle();

      if (response == null) {
        throw TaskApiException('Task $taskId was not found for this driver.');
      }

      if (photoUrl != null && photoUrl.isNotEmpty) {
        await _client.from('media_artifacts').insert({
          'company_id': _companyId,
          'task_id': taskId,
          'driver_id': _driverId,
          'type': 'photo',
          'storage_path': photoUrl,
        });
      }
      AppLogger.event(
        'tasks.pod.success',
        correlationId: correlationId,
        data: {'taskId': taskId, 'photoSaved': photoUrl?.isNotEmpty == true},
      );
    } on PostgrestException catch (error) {
      AppLogger.event(
        'tasks.pod.error',
        level: 'error',
        correlationId: correlationId,
        data: {'message': error.message, 'code': error.code},
      );
      throw TaskApiException(
        error.message.isNotEmpty
            ? error.message
            : 'Supabase error (${error.code}).',
      );
    } catch (error) {
      AppLogger.event(
        'tasks.pod.error',
        level: 'error',
        correlationId: correlationId,
        data: {'error': error.toString()},
      );
      throw TaskApiException('Unexpected Supabase error: $error');
    }
  }

  List<DeliveryTask> demoTasks() => DeliveryTask.sampleTasks();

  void _assertConfiguration() {
    if (_companyId.isEmpty || _driverId.isEmpty) {
      throw TaskApiException(
        'Supabase company/driver identifiers are not configured.',
      );
    }
  }

  DeliveryTask _mapRow(Map<String, dynamic> row) {
    return DeliveryTask(
      id: row['id']?.toString() ?? '',
      address: row['address']?.toString() ?? 'Unknown address',
      status: row['status']?.toString() ?? 'pending',
      scheduledAt: _parseDate(row['scheduled_start']),
      priority: (row['priority'] as num?)?.toInt() ?? 0,
      proofCode: row['proof_code']?.toString(),
      proofPhotoUrl: row['proof_photo_url']?.toString(),
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    return DateTime.tryParse(value.toString())?.toLocal();
  }
}
