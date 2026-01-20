import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  bool _chatLoading = false;
  final List<_ChatMessage> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskViewModel>().loadTasks();
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OrderVista Dispatch'),
        actions: [
          IconButton(
            tooltip: 'Admin portal',
            onPressed: () => context.push('/admin'),
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
          IconButton(
            tooltip: 'AI chat',
            onPressed: _chatLoading ? null : _openAiChat,
            icon: const Icon(Icons.chat_bubble_outline),
          ),
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

  Future<void> _openAiChat() async {
    if (_chatMessages.isEmpty) {
      _chatMessages.add(const _ChatMessage(
        role: 'assistant',
        content: 'Hi! Ask me about your pending deliveries or next steps.',
      ));
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'AI Chat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 320,
                    child: ListView.builder(
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, index) {
                        final message = _chatMessages[index];
                        final isUser = message.role == 'user';
                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? Colors.blue.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(message.content),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          decoration: const InputDecoration(
                            hintText: 'Ask about tasks, timing, or priorities…',
                            border: OutlineInputBorder(),
                          ),
                          minLines: 1,
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _chatLoading
                            ? null
                            : () => _sendChat(setModalState),
                        icon: _chatLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendChat(StateSetter setModalState) async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    final viewModel = context.read<TaskViewModel>();
    final config = context.read<AppConfig>();

    if (config.openRouterApiKey.isEmpty) {
      setModalState(() {
        _chatMessages.add(const _ChatMessage(
          role: 'assistant',
          content: 'AI key missing. Set DEEPSEEK_API_KEY in .env.',
        ));
      });
      return;
    }

    setState(() => _chatLoading = true);
    setModalState(() {});

    try {
      _chatMessages.add(_ChatMessage(role: 'user', content: text));
      _chatController.clear();
      setModalState(() {});

      final service = AiService(
        apiKey: config.openRouterApiKey,
        baseUrl: config.openRouterBaseUrl,
        model: config.openRouterModel,
      );

      final systemPrompt = _buildChatSystemPrompt(viewModel.tasks);
      final response = await service.chat(
        _chatMessages
            .map((m) => {'role': m.role, 'content': m.content})
            .toList(),
        systemPrompt: systemPrompt,
      );
      service.dispose();

      _chatMessages.add(_ChatMessage(
        role: 'assistant',
        content: response ?? 'No response.',
      ));
      setModalState(() {});
    } catch (e) {
      _chatMessages.add(_ChatMessage(
        role: 'assistant',
        content: 'AI error: $e',
      ));
      setModalState(() {});
    } finally {
      if (mounted) {
        setState(() => _chatLoading = false);
        setModalState(() {});
      }
    }
  }

  String _buildChatSystemPrompt(List<DeliveryTask> tasks) {
    final buffer = StringBuffer(
      'You are a dispatch assistant helping a delivery worker. '
      'Provide concise, actionable guidance. Current tasks:\n',
    );
    if (tasks.isEmpty) {
      buffer.write('No tasks assigned.');
      return buffer.toString();
    }

    for (final task in tasks.take(10)) {
      buffer.writeln(
        '- ${task.id}: ${task.address} (status=${task.status})',
      );
    }
    return buffer.toString();
  }
}

class _ChatMessage {
  const _ChatMessage({required this.role, required this.content});

  final String role;
  final String content;
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
              _TelemetryPanel(tasks: tasks),
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
                  label: const Text('Proof of Delivery'),
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
    final codeController = TextEditingController(text: task.proofCode);
    final photoController =
        TextEditingController(text: task.proofPhotoUrl ?? '');
    final viewModel = context.read<TaskViewModel>();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Confirm delivery for ${task.id}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Save proof code and photo metadata for this task.'),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Proof of delivery code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: photoController,
                decoration: const InputDecoration(
                  labelText: 'Photo URL (or storage path)',
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
              onPressed: () => Navigator.of(dialogContext).pop({
                'code': codeController.text.trim(),
                'photo': photoController.text.trim(),
              }),
              child: const Text('Save PoD'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      codeController.dispose();
      photoController.dispose();
      return;
    }

    final code = result['code'];
    final photoUrl = result['photo'];
    if ((code == null || code.isEmpty) &&
        (photoUrl == null || photoUrl.isEmpty)) {
      codeController.dispose();
      photoController.dispose();
      return;
    }

    try {
      await viewModel.saveProofOfDelivery(
        task,
        proofCode: code,
        photoUrl: photoUrl,
      );
      codeController.dispose();
      photoController.dispose();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Proof saved for ${task.id}.')),
        );
      }
    } catch (_) {
      codeController.dispose();
      photoController.dispose();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(viewModel.errorMessage ?? 'Failed to save proof.')),
        );
      }
    }
  }
}

class _TelemetryPanel extends StatefulWidget {
  const _TelemetryPanel({required this.tasks});

  final List<DeliveryTask> tasks;

  @override
  State<_TelemetryPanel> createState() => _TelemetryPanelState();
}

class _TelemetryPanelState extends State<_TelemetryPanel> {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  String? _selectedTaskId;
  String? _message;
  bool _working = false;

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    final tasks = widget.tasks;

    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    _selectedTaskId ??= tasks.first.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Telemetry & Geofence (Manual Stub)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter a location to simulate a device update and check proximity to a task.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: '22.3027',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      hintText: '114.1772',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedTaskId,
              items: tasks
                  .map(
                    (task) => DropdownMenuItem(
                      value: task.id,
                      child: Text('${task.id} • ${task.address}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedTaskId = value),
              decoration: const InputDecoration(labelText: 'Target task'),
            ),
            const SizedBox(height: 12),
            if (_message != null)
              _InlineNotice(
                message: _message!,
                usingDemoData: false,
                isOffline: false,
                lastCacheUpdate: null,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _working ? null : () => _checkProximity(config),
                    icon: _working
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.place_outlined),
                    label: const Text('Check proximity'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _working ? null : () => _sendTelemetry(config),
                  icon: const Icon(Icons.near_me_outlined),
                  label: const Text('Send telemetry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkProximity(AppConfig config) async {
    final task = _selectedTask();
    if (task == null) {
      setState(() => _message = 'Select a task first.');
      return;
    }

    final location = _parseLocation();
    if (location == null) {
      setState(() => _message = 'Enter valid latitude and longitude.');
      return;
    }

    if (config.mapboxAccessToken.isEmpty) {
      setState(() => _message = 'MAPBOX_ACCESS_TOKEN is required.');
      return;
    }

    setState(() {
      _working = true;
      _message = null;
    });

    final mapbox = MapboxService(
      config.mapboxAccessToken,
      countryCode: config.mapboxCountryCode,
      proximity: GeoPoint(
        lat: config.mapboxProximityLat,
        lng: config.mapboxProximityLng,
      ),
    );

    try {
      final taskPoint = await mapbox.forwardGeocode(task.address);
      if (taskPoint == null) {
        setState(() => _message = 'No location found for ${task.address}.');
        return;
      }
      final distance = _haversineMeters(location, taskPoint);
      if (distance <= 200) {
        setState(() => _message =
            'Within ${distance.toStringAsFixed(0)}m of ${task.id}. Suggest arrival.');
      } else {
        setState(() =>
            _message = '${distance.toStringAsFixed(0)}m away from ${task.id}.');
      }
    } catch (e) {
      setState(() => _message = 'Proximity check failed: $e');
    } finally {
      mapbox.dispose();
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _sendTelemetry(AppConfig config) async {
    final location = _parseLocation();
    if (location == null) {
      setState(() => _message = 'Enter valid latitude and longitude.');
      return;
    }

    if (config.companyId.isEmpty || config.driverId.isEmpty) {
      setState(
          () => _message = 'ORDERVISTA_COMPANY_ID and DRIVER_ID required.');
      return;
    }

    setState(() {
      _working = true;
      _message = null;
    });

    try {
      final payload = {
        'company_id': config.companyId,
        'driver_id': config.driverId,
        'location': 'SRID=4326;POINT(${location.lng} ${location.lat})',
        'source': 'manual',
        'payload': {
          'task_id': _selectedTaskId,
          'note': 'manual telemetry stub',
        },
      };
      await Supabase.instance.client.from('telemetry_events').insert(payload);
      setState(
          () => _message = 'Telemetry sent for ${_selectedTaskId ?? 'task'}');
    } catch (e) {
      setState(() => _message = 'Telemetry send failed: $e');
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  DeliveryTask? _selectedTask() {
    final id = _selectedTaskId;
    if (id == null) return null;
    return widget.tasks
        .firstWhere((task) => task.id == id, orElse: () => widget.tasks.first);
  }

  GeoPoint? _parseLocation() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) return null;
    return GeoPoint(lat: lat, lng: lng);
  }

  double _haversineMeters(GeoPoint a, GeoPoint b) {
    const radius = 6371000.0;
    final lat1 = _toRadians(a.lat);
    final lat2 = _toRadians(b.lat);
    final dLat = _toRadians(b.lat - a.lat);
    final dLng = _toRadians(b.lng - a.lng);

    final h =
        pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLng / 2), 2);
    return 2 * radius * asin(sqrt(h));
  }

  double _toRadians(double value) => value * pi / 180.0;
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
