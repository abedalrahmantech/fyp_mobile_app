import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../models/delivery_task.dart';
import '../../viewmodels/task_view_model.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskViewModel>().loadTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OrderVista Dispatch'),
        actions: const [
          _LastSyncedIndicator(),
        ],
      ),
      body: const _TaskListBody(),
    );
  }
}

class _TaskListBody extends StatelessWidget {
  const _TaskListBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskViewModel>(
      builder: (context, viewModel, _) {
        if (viewModel.isLoading && viewModel.tasks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = viewModel.tasks;

        return RefreshIndicator(
          onRefresh: () => viewModel.loadTasks(forceRefresh: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (viewModel.pendingSyncCount > 0)
                _PendingSyncBanner(
                  count: viewModel.pendingSyncCount,
                  onSync: () => viewModel.syncPendingDeliveries(),
                ),
              if (viewModel.errorMessage != null)
                _InlineNotice(
                  message: viewModel.errorMessage!,
                  usingDemoData: viewModel.usingDemoData,
                  isOffline: viewModel.isOffline,
                  lastCacheUpdate: viewModel.lastCacheUpdate,
                ),
              if (tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(
                    child: Text(
                      'No tasks available. Pull to refresh or check the dispatcher portal.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...tasks.map((task) => _TaskCard(task: task)),
            ],
          ),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final DeliveryTask task;

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.statusColor(task.status);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.id,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Chip(
                  label: Text(task.status.toUpperCase()),
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  labelStyle: theme.textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              task.address,
              style: theme.textTheme.bodyLarge,
            ),
            if (task.scheduledAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Scheduled: ${_formatDate(task.scheduledAt!)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: task.status.toLowerCase() == 'delivered'
                        ? null
                        : () => _handleMarkDelivered(context, task),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Mark as Delivered'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _promptProofCode(context, task),
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                  label: const Text('Scan / Code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMarkDelivered(
      BuildContext context, DeliveryTask task) async {
    final viewModel = context.read<TaskViewModel>();
    try {
      await viewModel.markAsDelivered(task);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task ${task.id} marked as delivered.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(viewModel.errorMessage ?? 'Failed to update task.')),
        );
      }
    }
  }

  Future<void> _promptProofCode(BuildContext context, DeliveryTask task) async {
    final controller = TextEditingController(text: task.proofCode);
    final viewModel = context.read<TaskViewModel>();

    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Confirm delivery for ${task.id}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter or scan the delivery code to confirm handoff.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Proof of delivery code',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (code == null) {
      return;
    }

    try {
      await viewModel.markAsDelivered(task, proofCode: code);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delivery code recorded for ${task.id}.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(viewModel.errorMessage ?? 'Failed to record code.')),
        );
      }
    }
  }
}

String _formatDate(DateTime value) {
  return DateFormat('MMM d • HH:mm').format(value.toLocal());
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.message,
    required this.usingDemoData,
    required this.isOffline,
    required this.lastCacheUpdate,
  });

  final String message;
  final bool usingDemoData;
  final bool isOffline;
  final DateTime? lastCacheUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = _buildDetails();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              details,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _buildDetails() {
    if (usingDemoData) {
      return '$message\nShowing sample tasks for demo purposes.';
    }

    if (isOffline) {
      final cacheLabel = lastCacheUpdate != null
          ? 'Using cached tasks from ${_formatDate(lastCacheUpdate!)}.'
          : 'Using cached tasks until connectivity returns.';
      return '$message\n$cacheLabel';
    }

    return message;
  }
}

class _LastSyncedIndicator extends StatelessWidget {
  const _LastSyncedIndicator();

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskViewModel>(
      builder: (context, viewModel, _) {
        final theme = Theme.of(context);
        final textTheme = theme.textTheme;
        final label = _buildLabel(viewModel);
        final color =
            viewModel.isOffline ? Colors.orange : textTheme.bodySmall?.color;

        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(color: color),
                textAlign: TextAlign.right,
              ),
              if (viewModel.isOffline)
                Text(
                  'Offline mode',
                  style: textTheme.labelSmall
                      ?.copyWith(color: Colors.orange.shade700),
                ),
            ],
          ),
        );
      },
    );
  }

  String _buildLabel(TaskViewModel viewModel) {
    if (viewModel.isLoading) {
      return 'Syncing…';
    }

    if (viewModel.lastSuccessfulSync != null) {
      return 'Last sync ${_formatDate(viewModel.lastSuccessfulSync!)}';
    }

    return 'Not synced yet';
  }
}

class _PendingSyncBanner extends StatelessWidget {
  const _PendingSyncBanner({required this.count, required this.onSync});

  final int count;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = count == 1
        ? '1 delivery queued — tap to sync now'
        : '$count deliveries queued — tap to sync now';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: ListTile(
        leading: const Icon(Icons.sync_problem, color: Colors.blueGrey),
        title: Text(label, style: theme.textTheme.bodyMedium),
        trailing: TextButton.icon(
          onPressed: onSync,
          icon: const Icon(Icons.sync),
          label: const Text('Sync'),
        ),
      ),
    );
  }
}
