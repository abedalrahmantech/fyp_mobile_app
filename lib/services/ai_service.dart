import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/delivery_task.dart';

class AiService {
  AiService({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String baseUrl;
  final String model;
  final http.Client _client;

  Future<String?> summarizeTasks(List<DeliveryTask> tasks) async {
    if (apiKey.isEmpty) return 'Missing OpenRouter API key.';

    final uri = Uri.parse('$baseUrl/chat/completions');
    final prompt = _buildPrompt(tasks);

    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': 'You summarize delivery tasks concisely.',
          },
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.3,
        'max_tokens': 160,
      }),
    );

    if (response.statusCode != 200) {
      return 'AI request failed (${response.statusCode}).';
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = body['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return 'No AI response.';
    final message = (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
    return message?['content'] as String? ?? 'No AI content.';
  }

  String _buildPrompt(List<DeliveryTask> tasks) {
    if (tasks.isEmpty) {
      return 'There are no delivery tasks.';
    }

    final buffer = StringBuffer(
      'Summarize these delivery tasks in Hong Kong:\n',
    );
    for (final task in tasks.take(20)) {
      buffer.writeln(
        '- ${task.id}: ${task.address} • status=${task.status} • scheduled=${task.scheduledAt ?? 'unscheduled'}',
      );
    }
    if (tasks.length > 20) {
      buffer.writeln('(+${tasks.length - 20} more tasks not listed)');
    }
    buffer.writeln('Provide 2-3 bullets with counts and any at-risk items.');
    return buffer.toString();
  }

  void dispose() {
    _client.close();
  }
}
