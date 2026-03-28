import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import '../models/ai_action.dart';
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
        if (kIsWeb && baseUrl.contains('openrouter.ai'))
          'HTTP-Referer': Uri.base.origin,
        if (kIsWeb && baseUrl.contains('openrouter.ai'))
          'X-Title': 'OrderVista Dispatch',
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
    final message = (choices.first as Map<String, dynamic>)['message']
        as Map<String, dynamic>?;
    return message?['content'] as String? ?? 'No AI content.';
  }

  Future<String?> chat(
    List<Map<String, String>> messages, {
    String? systemPrompt,
  }) async {
    if (apiKey.isEmpty) return 'Missing AI API key.';

    final uri = Uri.parse('$baseUrl/chat/completions');
    final payloadMessages = <Map<String, String>>[];
    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      payloadMessages.add({'role': 'system', 'content': systemPrompt.trim()});
    }
    payloadMessages.addAll(messages);

    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        if (kIsWeb && baseUrl.contains('openrouter.ai'))
          'HTTP-Referer': Uri.base.origin,
        if (kIsWeb && baseUrl.contains('openrouter.ai'))
          'X-Title': 'OrderVista Dispatch',
      },
      body: jsonEncode({
        'model': model,
        'messages': payloadMessages,
        'temperature': 0.4,
        'max_tokens': 200,
      }),
    );

    if (response.statusCode != 200) {
      return 'AI request failed (${response.statusCode}).';
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = body['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return 'No AI response.';
    final message = (choices.first as Map<String, dynamic>)['message']
        as Map<String, dynamic>?;
    return message?['content'] as String? ?? 'No AI content.';
  }

  /// Returns a structured AI suggestion with an optional executable action.
  Future<AiAction> getAgenticSuggestion({
    required List<DeliveryTask> tasks,
    required bool isAvailable,
    required int pendingSyncCount,
  }) async {
    if (apiKey.isEmpty) {
      return const AiAction(suggestion: 'Missing API key.');
    }

    final pending = tasks.where((t) => t.status == 'pending').toList();
    final inTransit = tasks.where((t) => t.status == 'in-transit').toList();
    final delivered = tasks.where((t) => t.status == 'delivered').toList();
    final now = DateTime.now();
    final hour = now.hour;

    String timeContext;
    if (hour < 9) {
      timeContext = 'early morning';
    } else if (hour < 12) {
      timeContext = 'morning';
    } else if (hour < 17) {
      timeContext = 'afternoon';
    } else {
      timeContext = 'evening';
    }

    // Build task details for the top pending/in-transit tasks
    final taskDetails = StringBuffer();
    for (final t in pending.take(5)) {
      taskDetails.writeln(
        '  - ID: ${t.id}, Address: ${t.address}, Priority: ${t.priority}, Scheduled: ${t.scheduledAt ?? "unscheduled"}',
      );
    }
    for (final t in inTransit.take(3)) {
      taskDetails.writeln(
        '  - ID: ${t.id}, Address: ${t.address}, Status: in-transit',
      );
    }

    final prompt =
        '''You are an intelligent delivery dispatch assistant that can suggest AND execute actions.

Analyze the driver's current situation and return a JSON object with a suggestion and an action to execute.

AVAILABLE ACTIONS (pick the single best one):
- "start_next_pending"  → Begin the next pending delivery (set status to in-transit)
- "mark_delivered"      → Mark a specific in-transit task as delivered (requires task_id)
- "go_available"        → Set driver status to available
- "go_offline"          → Set driver status to offline
- "sync_pending"        → Trigger sync of offline-queued updates
- "refresh_tasks"       → Refresh the task list from server
- "none"                → No action needed, advisory suggestion only

CURRENT SITUATION:
- Time: $timeContext ($hour:00)
- Driver status: ${isAvailable ? 'Available' : 'Offline'}
- Pending deliveries: ${pending.length}
- In-transit deliveries: ${inTransit.length}
- Completed today: ${delivered.length}
- Queued offline updates: $pendingSyncCount
${taskDetails.isNotEmpty ? '\nTask details:\n$taskDetails' : ''}

RULES:
- If driver is offline and has pending tasks, suggest "go_available"
- If there are pending tasks but none in-transit, suggest "start_next_pending"
- If there are queued offline updates, suggest "sync_pending"
- For "mark_delivered", include the specific task_id
- Keep suggestion under 40 words

Respond with ONLY valid JSON (no markdown, no backticks):
{"suggestion": "...", "action": "...", "task_id": null}''';

    final uri = Uri.parse('$baseUrl/chat/completions');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          if (kIsWeb && baseUrl.contains('openrouter.ai'))
            'HTTP-Referer': Uri.base.origin,
          if (kIsWeb && baseUrl.contains('openrouter.ai'))
            'X-Title': 'OrderVista Dispatch',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are an agentic delivery assistant. Always respond with valid JSON only.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.2,
          'max_tokens': 150,
        }),
      );

      if (response.statusCode != 200) {
        return AiAction(
            suggestion: 'AI request failed (${response.statusCode}).');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = body['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        return const AiAction(suggestion: 'No AI response.');
      }

      final message = (choices.first as Map<String, dynamic>)['message']
          as Map<String, dynamic>?;
      final content = message?['content'] as String? ?? '';

      // Parse JSON from the response, handling potential markdown wrapping
      final jsonStr = _extractJson(content);
      if (jsonStr != null) {
        final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
        return AiAction.fromJson(parsed);
      }

      // Fallback: treat as plain-text advisory suggestion
      return AiAction(suggestion: content.trim());
    } catch (e) {
      debugPrint('Agentic AI error: $e');
      return AiAction(suggestion: 'AI suggestion unavailable.');
    }
  }

  /// Extracts a JSON object from a string that may be wrapped in markdown.
  static String? _extractJson(String text) {
    final trimmed = text.trim();
    // Try direct parse first
    if (trimmed.startsWith('{')) {
      return trimmed;
    }
    // Try extracting from markdown code block
    final match = RegExp(r'\{[^}]+\}').firstMatch(trimmed);
    return match?.group(0);
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
