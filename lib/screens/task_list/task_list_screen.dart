import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_theme.dart';
import '../../config/app_config.dart';
import '../../models/delivery_task.dart';
import '../../services/ai_service.dart';
import '../../services/mapbox_service.dart';
import '../../viewmodels/task_view_model.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  bool _aiLoading = false;

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
        actions: [
          IconButton(
            tooltip: 'AI summary',
            onPressed: _aiLoading ? null : _runAiSummary,
            icon: _aiLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bolt_outlined),
          ),
          const _LastSyncedIndicator(),
        ],
      ),
      body: const _TaskListBody(),
    );
  }

  Future<void> _runAiSummary() async {
    final viewModel = context.read<TaskViewModel>();
    final config = context.read<AppConfig>();

    if (config.openRouterApiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Set OPENROUTER_API_KEY in .env to use AI.')),
      );
      return;
    }

    setState(() => _aiLoading = true);
    try {
      final service = AiService(
        apiKey: config.openRouterApiKey,
        baseUrl: config.openRouterBaseUrl,
        model: config.openRouterModel,
      );
      final summary = await service.summarizeTasks(viewModel.tasks);
      service.dispose();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('AI Summary'),
            content:
                SingleChildScrollView(child: Text(summary ?? 'No summary.')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _aiLoading = false);
      }
    }
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
              const _EngineerCredit(),
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
    final config = context.read<AppConfig>();
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
            _TaskMapPreview(
              address: task.address,
              mapboxToken: config.mapboxAccessToken,
              countryCode: config.mapboxCountryCode,
              proximity: GeoPoint(
                lat: config.mapboxProximityLat,
                lng: config.mapboxProximityLng,
              ),
            ),
            const SizedBox(height: 12),
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

class _EngineerCredit extends StatelessWidget {
  const _EngineerCredit();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        'Built by Abed Al Rahman • City University of Hong Kong',
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.blueGrey),
      ),
    );
  }
}

class _TaskMapPreview extends StatefulWidget {
  const _TaskMapPreview({
    required this.address,
    required this.mapboxToken,
    required this.countryCode,
    required this.proximity,
  });

  final String address;
  final String mapboxToken;
  final String countryCode;
  final GeoPoint proximity;

  @override
  State<_TaskMapPreview> createState() => _TaskMapPreviewState();
}

class _TaskMapPreviewState extends State<_TaskMapPreview> {
  Future<GeoPoint?>? _future;
  MapboxService? _service;

  @override
  void initState() {
    super.initState();
    if (widget.mapboxToken.isNotEmpty) {
      _service = MapboxService(
        widget.mapboxToken,
        countryCode: widget.countryCode,
        proximity: widget.proximity,
      );
      _future = _service!.forwardGeocode(widget.address);
    }
  }

  @override
  void dispose() {
    _service?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mapboxToken.isEmpty) {
      return const _MapPlaceholder(message: 'Mapbox token missing.');
    }

    return FutureBuilder<GeoPoint?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _MapPlaceholder(message: 'Loading map...');
        }

        if (snapshot.hasError) {
          return const _MapPlaceholder(message: 'Map unavailable.');
        }

        final point = snapshot.data;
        if (point == null) {
          return const _MapPlaceholder(
              message: 'No location found for this address.');
        }

        final url = _service!.staticMapUrl(point);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openInMaps(point),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open in Maps'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openInMaps(GeoPoint point) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${point.lat},${point.lng}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 180,
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
