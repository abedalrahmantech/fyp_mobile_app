import 'package:flutter/foundation.dart';

class AppLogger {
  static String newCorrelationId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  static void event(
    String name, {
    String level = 'info',
    String? correlationId,
    Map<String, dynamic>? data,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final corr = correlationId == null ? '' : ' corr=$correlationId';
    final payload = data == null ? '' : ' ${data.toString()}';
    debugPrint('[$timestamp][$level] $name$corr$payload');
  }
}
