/// Represents a structured action suggested by the AI assistant.
enum AiActionType {
  startNextPending,
  markDelivered,
  goAvailable,
  goOffline,
  syncPending,
  refreshTasks,
  none,
}

class AiAction {
  const AiAction({
    required this.suggestion,
    this.actionType = AiActionType.none,
    this.taskId,
  });

  final String suggestion;
  final AiActionType actionType;
  final String? taskId;

  bool get isActionable => actionType != AiActionType.none;

  String get actionLabel {
    switch (actionType) {
      case AiActionType.startNextPending:
        return 'Start Delivery';
      case AiActionType.markDelivered:
        return 'Mark Delivered';
      case AiActionType.goAvailable:
        return 'Go Available';
      case AiActionType.goOffline:
        return 'Go Offline';
      case AiActionType.syncPending:
        return 'Sync Now';
      case AiActionType.refreshTasks:
        return 'Refresh';
      case AiActionType.none:
        return '';
    }
  }

  static AiActionType _parseType(String? raw) {
    if (raw == null) return AiActionType.none;
    switch (raw.trim().toLowerCase()) {
      case 'start_next_pending':
        return AiActionType.startNextPending;
      case 'mark_delivered':
        return AiActionType.markDelivered;
      case 'go_available':
        return AiActionType.goAvailable;
      case 'go_offline':
        return AiActionType.goOffline;
      case 'sync_pending':
        return AiActionType.syncPending;
      case 'refresh_tasks':
        return AiActionType.refreshTasks;
      default:
        return AiActionType.none;
    }
  }

  static AiAction fromJson(Map<String, dynamic> json) {
    return AiAction(
      suggestion:
          (json['suggestion'] as String?)?.trim() ?? 'No suggestion available.',
      actionType: _parseType(json['action'] as String?),
      taskId: json['task_id'] as String?,
    );
  }
}
