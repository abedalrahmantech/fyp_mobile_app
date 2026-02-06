import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/app_theme.dart';
import '../../config/app_config.dart';
import '../../models/driver_profile.dart';
import '../../models/delivery_task.dart';
import '../../services/ai_service.dart';
import '../../services/mapbox_service.dart';
import '../../viewmodels/task_view_model.dart';
import 'barcode_scanner_sheet.dart';

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

  // Driver availability state
  bool _isAvailable = false;
  bool _availabilityLoading = false;

  // Admin messages state
  List<_AdminMessage> _adminMessages = const [];
  int _unreadMessageCount = 0;

  // Agentic AI notification state
  String? _aiSuggestion;
  bool _aiSuggestionLoading = false;
  DateTime? _lastAiSuggestionTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskViewModel>().loadTasks();
      _loadDriverStatus();
      _loadAdminMessages();
      _loadAiSuggestion(); // Load proactive AI suggestion
    });
  }

  Future<void> _loadDriverStatus() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      final config = context.read<AppConfig>();
      final member = await client
          .from('company_members')
          .select('is_available')
          .eq('user_id', user.id)
          .eq('company_id', config.companyId)
          .maybeSingle();

      if (member != null && mounted) {
        setState(() {
          _isAvailable = member['is_available'] == true;
        });
      }
    } catch (e) {
      debugPrint('Failed to load driver status: $e');
    }
  }

  Future<void> _toggleAvailability() async {
    setState(() => _availabilityLoading = true);
    try {
      final client = Supabase.instance.client;
      final newStatus = !_isAvailable;

      // Try RPC first, then fallback to direct update
      try {
        await client.rpc('update_driver_status', params: {
          'p_is_available': newStatus,
        });
      } catch (e) {
        // Fallback: direct update
        final user = client.auth.currentUser;
        if (user == null) throw Exception('Not authenticated');

        final config = context.read<AppConfig>();
        await client
            .from('company_members')
            .update({'is_available': newStatus})
            .eq('user_id', user.id)
            .eq('company_id', config.companyId);
      }

      if (mounted) {
        setState(() => _isAvailable = newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'You are now available for deliveries'
                  : 'You are now offline',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _availabilityLoading = false);
      }
    }
  }

  Future<void> _loadAdminMessages() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      final config = context.read<AppConfig>();

      // Get driver's member ID
      final member = await client
          .from('company_members')
          .select('id')
          .eq('user_id', user.id)
          .eq('company_id', config.companyId)
          .maybeSingle();

      if (member == null) return;
      final driverId = member['id']?.toString();
      if (driverId == null) return;

      // Fetch messages for this driver (direct or broadcast)
      final response = await client
          .from('chat_messages')
          .select('id, sender_id, message, is_broadcast, read_at, created_at')
          .eq('company_id', config.companyId)
          .or('recipient_id.eq.$driverId,is_broadcast.eq.true')
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        final messages = (response as List).map((row) {
          final map = row as Map<String, dynamic>;
          return _AdminMessage(
            id: map['id']?.toString() ?? '',
            senderId: map['sender_id']?.toString() ?? '',
            message: map['message']?.toString() ?? '',
            isBroadcast: map['is_broadcast'] == true,
            isRead: map['read_at'] != null,
            createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                DateTime.now(),
          );
        }).toList();

        setState(() {
          _adminMessages = messages;
          _unreadMessageCount = messages.where((m) => !m.isRead).length;
        });
      }
    } catch (e) {
      debugPrint('Failed to load admin messages: $e');
    }
  }

  void _openAdminMessagesDrawer() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _AdminMessagesSheet(
        messages: _adminMessages,
        onMarkRead: _markMessagesRead,
        onRefresh: _loadAdminMessages,
      ),
    );
  }

  Future<void> _markMessagesRead() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      final config = context.read<AppConfig>();

      // Get driver's member ID
      final member = await client
          .from('company_members')
          .select('id')
          .eq('user_id', user.id)
          .eq('company_id', config.companyId)
          .maybeSingle();

      if (member == null) return;
      final driverId = member['id']?.toString();
      if (driverId == null) return;

      // Mark messages as read
      await client
          .from('chat_messages')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('company_id', config.companyId)
          .eq('recipient_id', driverId)
          .isFilter('read_at', null);

      setState(() => _unreadMessageCount = 0);
    } catch (e) {
      debugPrint('Failed to mark messages read: $e');
    }
  }

  // ==========================================================================
  // Agentic AI Proactive Suggestions
  // ==========================================================================
  Future<void> _loadAiSuggestion() async {
    // Only refresh if more than 5 minutes since last suggestion
    if (_lastAiSuggestionTime != null &&
        DateTime.now().difference(_lastAiSuggestionTime!) <
            const Duration(minutes: 5)) {
      return;
    }

    final config = context.read<AppConfig>();
    if (config.openRouterApiKey.isEmpty) return;

    final viewModel = context.read<TaskViewModel>();
    final tasks = viewModel.tasks;
    if (tasks.isEmpty) return;

    setState(() => _aiSuggestionLoading = true);

    try {
      final service = AiService(
        apiKey: config.openRouterApiKey,
        baseUrl: config.openRouterBaseUrl,
        model: config.openRouterModel,
      );

      // Build context for AI
      final pendingCount = tasks.where((t) => t.status == 'pending').length;
      final inTransitCount =
          tasks.where((t) => t.status == 'in-transit').length;
      final deliveredCount = tasks.where((t) => t.status == 'delivered').length;
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

      final prompt =
          '''You are a helpful delivery route assistant. Based on the current status, provide ONE short, actionable suggestion (max 50 words) to help the driver be more efficient.

Current status:
- Time: $timeContext
- Pending deliveries: $pendingCount
- In-transit: $inTransitCount
- Completed today: $deliveredCount
- Driver availability: ${_isAvailable ? 'Available' : 'Offline'}

Respond with just the suggestion, no formatting or preamble.''';

      final response = await service.chat([
        {'role': 'user', 'content': prompt}
      ]);
      service.dispose();

      if (mounted && response != null && !response.contains('failed')) {
        setState(() {
          _aiSuggestion = response.trim();
          _lastAiSuggestionTime = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Failed to load AI suggestion: $e');
    } finally {
      if (mounted) {
        setState(() => _aiSuggestionLoading = false);
      }
    }
  }

  void _dismissAiSuggestion() {
    setState(() => _aiSuggestion = null);
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
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: _availabilityLoading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Switch(
                  value: _isAvailable,
                  onChanged: (_) => _toggleAvailability(),
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.grey,
                ),
        ),
        actions: [
          // Admin messages with badge
          Stack(
            children: [
              IconButton(
                tooltip: 'Messages from admin',
                onPressed: _openAdminMessagesDrawer,
                icon: const Icon(Icons.notifications_outlined),
              ),
              if (_unreadMessageCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadMessageCount > 9 ? '9+' : '$_unreadMessageCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Admin portal',
            onPressed: () => context.push('/admin'),
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                setState(() {});
              }
            },
            icon: const Icon(Icons.logout),
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
      body: Column(
        children: [
          // AI Proactive Suggestion Card
          if (_aiSuggestion != null)
            _AiSuggestionCard(
              suggestion: _aiSuggestion!,
              onDismiss: _dismissAiSuggestion,
              onRefresh: _loadAiSuggestion,
            ),
          if (_aiSuggestionLoading) const LinearProgressIndicator(),
          const Expanded(child: _TaskListBody()),
        ],
      ),
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
            if (task.proofPhotoUrl != null &&
                task.proofPhotoUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'PoD Photo: ${task.proofPhotoUrl}',
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final scanned = await showModalBottomSheet<String>(
                      context: dialogContext,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (_) => const BarcodeScannerSheet(),
                    );
                    if (scanned != null && scanned.isNotEmpty) {
                      codeController.text = scanned;
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                  label: const Text('Scan QR/Barcode'),
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 80,
                    );
                    if (image != null) {
                      photoController.text = image.path;
                    }
                  },
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Capture photo'),
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
  bool _autoEnabled = false;
  Timer? _autoTimer;
  GeoPoint? _autoTargetPoint;

  @override
  void dispose() {
    _autoTimer?.cancel();
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
              initialValue: _selectedTaskId,
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _working ? null : () => _toggleLiveTelemetry(config),
                    icon: Icon(
                      _autoEnabled ? Icons.stop_circle : Icons.play_circle,
                    ),
                    label: Text(
                      _autoEnabled
                          ? 'Stop live telemetry'
                          : 'Start live telemetry',
                    ),
                  ),
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

    await _sendTelemetryForLocation(config, location, source: 'manual');
  }

  Future<void> _toggleLiveTelemetry(AppConfig config) async {
    if (_autoEnabled) {
      _autoTimer?.cancel();
      setState(() {
        _autoEnabled = false;
        _message = 'Live telemetry stopped.';
      });
      return;
    }

    if (kIsWeb) {
      setState(() =>
          _message = 'Live telemetry requires a mobile device (not web).');
      return;
    }

    final driverProfile = context.read<DriverProfile?>();
    final companyId = driverProfile?.companyId ?? config.companyId;
    final driverId = driverProfile?.driverId ?? config.driverId;
    if (companyId.isEmpty || driverId.isEmpty) {
      setState(() => _message = 'Driver profile missing (company/driver id).');
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _message = 'Location services are disabled.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _message = 'Location permission denied.');
      return;
    }

    final task = _selectedTask();
    if (task == null) {
      setState(() => _message = 'Select a task first.');
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
      _autoTargetPoint = await mapbox.forwardGeocode(task.address);
      if (_autoTargetPoint == null) {
        setState(() => _message = 'No location found for ${task.address}.');
        return;
      }

      _autoEnabled = true;
      _autoTimer?.cancel();
      _autoTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _tickLiveTelemetry(config),
      );
      setState(() => _message = 'Live telemetry started.');
      await _tickLiveTelemetry(config);
    } catch (e) {
      setState(() => _message = 'Live telemetry failed: $e');
    } finally {
      mapbox.dispose();
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _tickLiveTelemetry(AppConfig config) async {
    if (!_autoEnabled) return;
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      final location = GeoPoint(
        lat: position.latitude,
        lng: position.longitude,
      );
      await _sendTelemetryForLocation(config, location, source: 'auto');

      if (_autoTargetPoint != null) {
        final distance = _haversineMeters(location, _autoTargetPoint!);
        if (distance <= 200) {
          setState(() => _message =
              'Auto: within ${distance.toStringAsFixed(0)}m of ${_selectedTaskId ?? ''}. Suggest arrival.');
        }
      }
    } catch (e) {
      setState(() => _message = 'Live telemetry error: $e');
    }
  }

  Future<void> _sendTelemetryForLocation(
    AppConfig config,
    GeoPoint location, {
    required String source,
  }) async {
    final driverProfile = context.read<DriverProfile?>();
    final companyId = driverProfile?.companyId ?? config.companyId;
    final driverId = driverProfile?.driverId ?? config.driverId;
    if (companyId.isEmpty || driverId.isEmpty) {
      setState(() => _message = 'Driver profile missing (company/driver id).');
      return;
    }

    setState(() {
      _working = true;
      _message = null;
    });

    try {
      final payload = {
        'company_id': companyId,
        'driver_id': driverId,
        'location': 'SRID=4326;POINT(${location.lng} ${location.lat})',
        'source': source,
        'payload': {
          'task_id': _selectedTaskId,
          'note': source == 'auto'
              ? 'auto telemetry (foreground)'
              : 'manual telemetry stub',
        },
      };
      await Supabase.instance.client.from('telemetry_events').insert(payload);
      if (source == 'manual') {
        setState(
            () => _message = 'Telemetry sent for ${_selectedTaskId ?? 'task'}');
      }
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

class _AiSuggestionCard extends StatelessWidget {
  const _AiSuggestionCard({
    required this.suggestion,
    required this.onDismiss,
    required this.onRefresh,
  });

  final String suggestion;
  final VoidCallback onDismiss;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade50,
            Colors.blue.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.deepPurple,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Suggestion',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  suggestion,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          Column(
            children: [
              InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 18, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: onRefresh,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.refresh, size: 18, color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
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

// ===========================================================================
// Admin Messages
// ===========================================================================

class _AdminMessage {
  const _AdminMessage({
    required this.id,
    required this.senderId,
    required this.message,
    required this.isBroadcast,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String message;
  final bool isBroadcast;
  final bool isRead;
  final DateTime createdAt;
}

class _AdminMessagesSheet extends StatelessWidget {
  const _AdminMessagesSheet({
    required this.messages,
    required this.onMarkRead,
    required this.onRefresh,
  });

  final List<_AdminMessage> messages;
  final VoidCallback onMarkRead;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Messages from Admin',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      onMarkRead();
                      onRefresh();
                    },
                    child: const Text('Mark all read'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Text(
                        'No messages yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: msg.isRead
                                ? Colors.grey.shade50
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: msg.isRead
                                  ? Colors.grey.shade200
                                  : Colors.blue.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    msg.isBroadcast
                                        ? Icons.campaign
                                        : Icons.person,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    msg.isBroadcast
                                        ? 'Broadcast'
                                        : 'Direct message',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    DateFormat('MMM d • HH:mm')
                                        .format(msg.createdAt.toLocal()),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                msg.message,
                                style: const TextStyle(fontSize: 15),
                              ),
                              if (!msg.isRead)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'NEW',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
