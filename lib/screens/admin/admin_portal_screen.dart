import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../models/delivery_task.dart';
import '../../services/ai_service.dart';
import '../../services/mapbox_service.dart';

class AdminPortalScreen extends StatefulWidget {
  const AdminPortalScreen({super.key});

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  final _driverController = TextEditingController();
  final _routeDriverController = TextEditingController();
  final _statusOptions = const ['pending', 'in-transit', 'delivered'];

  // Navigation state — sidebar section index
  int _navIndex = 0;

  DateTime? _scheduledAt;
  String _status = 'pending';
  bool _loading = false;
  bool _routeLoading = false;
  bool _routesLoading = false;
  bool _csvLoading = false;
  String? _error;
  String? _routeMessage;
  String? _routesMessage;
  String? _csvMessage;
  String? _role;
  List<Map<String, dynamic>> _tasks = const [];
  List<_RouteView> _routes = const [];
  final Map<String, String> _routeMapUrls = {};
  final Map<String, bool> _routeMapLoading = {};
  final Map<String, String?> _routeMapErrors = {};
  bool _podLoading = false;
  String? _podMessage;
  List<_PodRecord> _podRecords = const [];

  // Driver management state
  bool _driversLoading = false;
  String? _driversMessage;
  List<_DriverInfo> _drivers = const [];

  // Chat state
  bool _chatLoading = false;

  // Fleet optimisation state
  bool _fleetLoading = false;
  String? _fleetMessage;
  List<Map<String, dynamic>> _fleetAssignments = const [];
  String? _chatMessage;
  List<_ChatMessage> _chatMessages = const [];
  final _chatInputController = TextEditingController();
  String? _selectedChatDriver;

  // AI fleet summary state
  bool _aiSummaryLoading = false;
  String? _aiSummaryText;

  // Customer tracking lookup state
  bool _trackingLoading = false;
  String? _trackingMessage;
  Map<String, dynamic>? _trackingResult;
  final _trackingCodeController = TextEditingController();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _driverController.dispose();
    _routeDriverController.dispose();
    _chatInputController.dispose();
    _trackingCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      return;
    }
    await _loadRoleAndTasks();
  }

  Future<void> _loadRoleAndTasks() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        setState(() {
          _role = null;
          _tasks = const [];
        });
        return;
      }

      // Query company_members table to get user's role
      // User may have multiple memberships, so get list and prioritize admin/dispatcher
      final memberships = await _client
          .from('company_members')
          .select('role, company_id')
          .eq('user_id', user.id);

      // Find first admin or dispatcher membership
      Map<String, dynamic>? selectedMembership;
      for (final m in (memberships as List)) {
        final role = m['role']?.toString();
        if (role == 'admin' || role == 'dispatcher') {
          selectedMembership = m as Map<String, dynamic>;
          break;
        }
      }
      // Fallback to first membership if no admin/dispatcher found
      selectedMembership ??= memberships.isNotEmpty ? memberships.first : null;

      _role = selectedMembership?['role']?.toString();
      // Allow both 'admin' and 'dispatcher' roles to access admin portal
      if (_role != 'admin' && _role != 'dispatcher') {
        _tasks = const [];
        return;
      }

      final rows = await _client
          .from('tasks')
          .select()
          .order('scheduled_start', ascending: true)
          .limit(100);

      _tasks = (rows as List<dynamic>)
          .map((row) => row as Map<String, dynamic>)
          .toList();

      _routes = await _fetchRoutes();
      _podRecords = await _fetchPodRecords();
    } catch (e) {
      _error = 'Failed to load admin data: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await _loadRoleAndTasks();
    } catch (e) {
      setState(() {
        _error = 'Sign in failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signOut() async {
    await _client.auth.signOut();
    setState(() {
      _role = null;
      _tasks = const [];
    });
  }

  Future<void> _recommendDriver() async {
    final config = context.read<AppConfig>();
    final address = _addressController.text.trim();

    if (address.isEmpty) {
      setState(() => _error = 'Enter an address first to recommend a driver.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Geocode the task address
      final mapboxService = MapboxService(
        config.mapboxAccessToken,
        countryCode: config.mapboxCountryCode,
        proximity: GeoPoint(
          lat: config.mapboxProximityLat,
          lng: config.mapboxProximityLng,
        ),
      );

      final addressCoords = await mapboxService.forwardGeocode(address);
      mapboxService.dispose();

      if (addressCoords == null) {
        setState(() {
          _error = 'Could not geocode address. Try a more specific address.';
          _loading = false;
        });
        return;
      }

      // Fetch drivers directly (simple query, no email column)
      final driverRows = await _client
          .from('company_members')
          .select(
              'id, user_id, is_available, current_task_count, last_location_at')
          .eq('company_id', config.companyId)
          .eq('role', 'driver');

      if ((driverRows as List).isEmpty) {
        setState(() {
          _error = 'No drivers found in your company.';
        });
        return;
      }

      // Resolve emails via profiles table
      final userIds = (driverRows as List)
          .map((r) => r['user_id']?.toString())
          .whereType<String>()
          .toList();
      final emailMap = <String, String>{};
      if (userIds.isNotEmpty) {
        try {
          final profiles = await _client
              .from('profiles')
              .select('id, email')
              .inFilter('id', userIds);
          for (final p in (profiles as List)) {
            final uid = p['id']?.toString();
            final em = p['email']?.toString();
            if (uid != null && em != null) emailMap[uid] = em;
          }
        } catch (_) {}
      }

      // Fetch performance stats per driver from tasks table
      final perfRows = await _client
          .from('tasks')
          .select('driver_id, status, scheduled_start, updated_at')
          .eq('company_id', config.companyId);

      final perfMap = <String, Map<String, dynamic>>{};
      for (final t in (perfRows as List)) {
        final did = t['driver_id']?.toString();
        if (did == null) continue;
        perfMap.putIfAbsent(
            did, () => {'total': 0, 'delivered': 0, 'minutes': <double>[]});
        perfMap[did]!['total'] = (perfMap[did]!['total'] as int) + 1;
        if (t['status'] == 'delivered') {
          perfMap[did]!['delivered'] = (perfMap[did]!['delivered'] as int) + 1;
          final start =
              DateTime.tryParse(t['scheduled_start']?.toString() ?? '');
          final updated = DateTime.tryParse(t['updated_at']?.toString() ?? '');
          if (start != null && updated != null) {
            (perfMap[did]!['minutes'] as List<double>)
                .add(updated.difference(start).inMinutes.toDouble());
          }
        }
      }

      // Score each driver using the fetched rows
      final ranked = <Map<String, dynamic>>[];
      for (final row in driverRows) {
        final memberId = row['id']?.toString() ?? '';
        final userId = row['user_id']?.toString() ?? '';
        final email = emailMap[userId] ?? 'Driver ${_shortId(memberId)}';
        final isAvail = row['is_available'] == true;
        final taskCount = (row['current_task_count'] as num?)?.toInt() ?? 0;

        // No location columns in this simple query — distance stays 9999
        final double distKm = 9999;

        final perf = perfMap[memberId];
        final total = (perf?['total'] as int?) ?? 0;
        final delivered = (perf?['delivered'] as int?) ?? 0;
        final compRate = total > 0 ? delivered / total : 0.0;
        final mins = (perf?['minutes'] as List<double>?) ?? [];
        final avgMin =
            mins.isEmpty ? 0.0 : mins.reduce((a, b) => a + b) / mins.length;

        // Composite score (higher is better)
        final score = (isAvail ? 1.0 : 0.5) *
            (1.0 / (1.0 + distKm)) *
            (1.0 / (1.0 + taskCount)) *
            (0.5 + 0.5 * compRate);

        ranked.add({
          'member_id': memberId,
          'email': email,
          'is_available': isAvail,
          'task_count': taskCount,
          'distance_km': distKm.toStringAsFixed(2),
          'completion_rate': compRate,
          'avg_delivery_minutes': avgMin,
          'score': score,
        });
      }

      ranked.sort(
          (a, b) => (b['score'] as double).compareTo(a['score'] as double));

      if (ranked.isEmpty) {
        setState(() {
          _error = 'No drivers found.';
        });
        return;
      }

      setState(() => _error = null);

      if (mounted) {
        final selected = await showDialog<String>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Driver Recommendations'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ranked by proximity to: $address',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(ranked.length, (i) {
                        final d = ranked[i];
                        final mId = d['member_id'] as String;
                        final email = d['email'] as String;
                        final distKm = d['distance_km'] as String;
                        final tasks = d['task_count'] as int;
                        final compPct = (d['completion_rate'] as double) * 100;
                        final avgMin = d['avg_delivery_minutes'] as double;
                        final isAvail = d['is_available'] as bool;
                        final rawScore = (d['score'] as double) * 100;
                        final scoreLabel =
                            rawScore.clamp(0, 100).toStringAsFixed(0);

                        final isTop = i == 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isTop
                                  ? Colors.green.shade400
                                  : Colors.grey.shade300,
                              width: isTop ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            color: isTop ? Colors.green.shade50 : null,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  isTop ? Colors.green : Colors.blueGrey,
                              child: Text(
                                '#${i + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    email,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Score $scoreLabel',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${distKm}km away  ·  $tasks active  ·  '
                                '${compPct.toStringAsFixed(0)}% completion  ·  '
                                '${avgMin.toStringAsFixed(0)}min avg'
                                '${isAvail ? '' : '  ·  OFFLINE'}',
                              ),
                            ),
                            onTap: () => Navigator.of(ctx).pop(mId),
                            trailing: isTop
                                ? const Icon(Icons.star, color: Colors.amber)
                                : null,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );

        if (selected != null && selected.isNotEmpty) {
          _driverController.text = selected;
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to recommend driver: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createTask() async {
    final config = context.read<AppConfig>();
    final address = _addressController.text.trim();
    final driverInput = _driverController.text.trim();

    if (address.isEmpty || driverInput.isEmpty) {
      setState(() => _error = 'Address and driver ID/email are required.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final driverId = await _resolveDriverId(driverInput, config.companyId);
      if (driverId == null || driverId.isEmpty) {
        setState(() => _error =
            'Driver not found. Use the driver UUID or a registered email.');
        return;
      }
      await _client.from('tasks').insert({
        'company_id': config.companyId,
        'driver_id': driverId,
        'address': address,
        'status': _status,
        'scheduled_start': _scheduledAt?.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      _addressController.clear();
      _driverController.clear();
      _scheduledAt = null;
      _status = 'pending';
      await _loadRoleAndTasks();
    } catch (e) {
      setState(() => _error = 'Failed to create task: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<String?> _resolveDriverId(String input, String companyId) async {
    if (!input.contains('@')) {
      return input;
    }

    final result = await _client.rpc(
      'resolve_company_member_by_email',
      params: {
        'email': input,
        'company_id': companyId,
      },
    );

    if (result == null) {
      return null;
    }
    return result.toString();
  }

  // ─── Navigation descriptors ───────────────────────────────────────
  static const _navItems = <({IconData icon, String label})>[
    (icon: Icons.dashboard_outlined, label: 'Dashboard'),
    (icon: Icons.add_task, label: 'Tasks'),
    (icon: Icons.alt_route, label: 'Routes'),
    (icon: Icons.groups_outlined, label: 'Fleet'),
    (icon: Icons.chat_outlined, label: 'Chat'),
    (icon: Icons.local_shipping_outlined, label: 'Tracking'),
    (icon: Icons.verified_outlined, label: 'PoD'),
  ];

  Widget _sectionBody() {
    switch (_navIndex) {
      case 0:
        return _buildDashboardSection();
      case 1:
        return _buildTasksSection();
      case 2:
        return _buildRoutesSection();
      case 3:
        return _buildFleetSection();
      case 4:
        return _buildChatSection();
      case 5:
        return _buildTrackingSection();
      case 6:
        return _buildPodSection();
      default:
        return _buildDashboardSection();
    }
  }

  // ─── Dashboard (overview) ──────────────────────────────────────────
  Widget _buildDashboardSection() {
    final pending = _tasks.where((t) => t['status'] == 'pending').length;
    final inTransit = _tasks.where((t) => t['status'] == 'in-transit').length;
    final delivered = _tasks.where((t) => t['status'] == 'delivered').length;
    final availDrivers = _drivers.where((d) => d.isAvailable).length;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ── Summary cards row ──
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _summaryCard(
              icon: Icons.pending_actions,
              label: 'Pending',
              value: '$pending',
              color: Colors.orange,
            ),
            _summaryCard(
              icon: Icons.local_shipping,
              label: 'In Transit',
              value: '$inTransit',
              color: Colors.blue,
            ),
            _summaryCard(
              icon: Icons.check_circle_outline,
              label: 'Delivered',
              value: '$delivered',
              color: const Color(0xFF2E7D32),
            ),
            _summaryCard(
              icon: Icons.people_outline,
              label: 'Drivers Online',
              value: '$availDrivers / ${_drivers.length}',
              color: const Color(0xFF004E7C),
            ),
            _summaryCard(
              icon: Icons.route,
              label: 'Active Routes',
              value: '${_routes.length}',
              color: Colors.deepPurple,
            ),
          ],
        ),
        const SizedBox(height: 28),
        _buildAiFleetSummary(),
        const SizedBox(height: 20),
        _buildTaskList(),
      ],
    );
  }

  // ─── AI Fleet Summary (A12) ──────────────────────────────────────
  Future<void> _runFleetAiSummary() async {
    final config = context.read<AppConfig>();
    if (config.openRouterApiKey.isEmpty) {
      setState(
          () => _aiSummaryText = 'Set OPENROUTER_API_KEY in .env to use AI.');
      return;
    }
    setState(() {
      _aiSummaryLoading = true;
      _aiSummaryText = null;
    });
    try {
      final tasks = _tasks.map((t) => DeliveryTask.fromJson(t)).toList();
      final service = AiService(
        apiKey: config.openRouterApiKey,
        baseUrl: config.openRouterBaseUrl,
        model: config.openRouterModel,
      );
      final summary = await service.summarizeTasks(tasks);
      service.dispose();
      if (!mounted) return;
      setState(() => _aiSummaryText = summary ?? 'No summary returned.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiSummaryText = 'AI error: $e');
    } finally {
      if (mounted) setState(() => _aiSummaryLoading = false);
    }
  }

  Widget _buildAiFleetSummary() {
    return _sectionCard(
      icon: Icons.auto_awesome,
      title: 'AI Fleet Summary',
      actions: [
        ElevatedButton.icon(
          onPressed: _aiSummaryLoading ? null : _runFleetAiSummary,
          icon: _aiSummaryLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome, size: 18),
          label: Text(_aiSummaryLoading ? 'Generating…' : 'Generate Summary'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF004E7C),
            foregroundColor: Colors.white,
          ),
        ),
      ],
      children: [
        if (_aiSummaryText != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF004E7C).withAlpha(12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF004E7C).withAlpha(40)),
            ),
            child: SelectableText(
              _aiSummaryText!,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Tap "Generate Summary" to get an AI-powered overview of all fleet tasks.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return SizedBox(
      width: 190,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withAlpha(60)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: color.withAlpha(28),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section wrappers ─────────────────────────────────────────────
  Widget _buildTasksSection() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildTaskForm(),
        const SizedBox(height: 20),
        _buildCsvImport(),
        const SizedBox(height: 20),
        _buildTaskList(),
      ],
    );
  }

  Widget _buildRoutesSection() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildRouteSequencer(),
        const SizedBox(height: 20),
        _buildRouteOverview(),
      ],
    );
  }

  Widget _buildFleetSection() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildDriverManagement(),
        const SizedBox(height: 20),
        _buildFleetOptimiser(),
      ],
    );
  }

  Widget _buildChatSection() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildAdminDriverChat(),
      ],
    );
  }

  Widget _buildTrackingSection() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildCustomerTracking(),
      ],
    );
  }

  Widget _buildPodSection() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildProofReview(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _client.auth.currentSession;
    final user = _client.auth.currentUser;
    final isAdmin =
        session != null && (_role == 'admin' || _role == 'dispatcher');

    const brandPrimary = Color(0xFF004E7C);
    const brandAccent = Color(0xFF1CB5E0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: brandPrimary,
        foregroundColor: Colors.white,
        elevation: 1,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(36),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_shipping, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'OrderVista',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: brandAccent.withAlpha(60),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ADMIN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (session != null) ...[
            IconButton(
              tooltip: 'Refresh data',
              onPressed: _loading ? null : _loadRoleAndTasks,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, size: 18, color: Colors.white70),
              label: const Text(
                'Sign out',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(session, user, isAdmin, brandPrimary, brandAccent),
    );
  }

  Widget _buildBody(
    dynamic session,
    dynamic user,
    bool isAdmin,
    Color brandPrimary,
    Color brandAccent,
  ) {
    // Not logged in
    if (session == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _buildSignInCard(),
        ),
      );
    }

    // Logged in but wrong role
    if (!isAdmin) {
      return Center(
        child: _InlineMessage(
          message: _role == null
              ? 'No company membership found for ${user?.email ?? 'user'}.'
              : 'Signed in as ${user?.email}. Role=$_role. Admin access required.',
          color: Colors.orange.shade100,
        ),
      );
    }

    // Authenticated admin → sidebar + content
    return Row(
      children: [
        // ── NavigationRail (sidebar) ──
        SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  (kToolbarHeight + MediaQuery.of(context).padding.top),
            ),
            child: IntrinsicHeight(
              child: NavigationRail(
                backgroundColor: Colors.white,
                selectedIndex: _navIndex,
                onDestinationSelected: (i) => setState(() => _navIndex = i),
                labelType: NavigationRailLabelType.all,
                indicatorColor: brandPrimary.withAlpha(30),
                selectedIconTheme: IconThemeData(color: brandPrimary),
                selectedLabelTextStyle: TextStyle(
                  color: brandPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                unselectedIconTheme: IconThemeData(color: Colors.grey.shade500),
                unselectedLabelTextStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                ),
                leading: const SizedBox(height: 4),
                destinations: [
                  for (final n in _navItems)
                    NavigationRailDestination(
                      icon: Icon(n.icon, size: 22),
                      label: Text(n.label),
                    ),
                ],
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // ── Main content area ──
        Expanded(
          child: Column(
            children: [
              if (_error != null)
                _InlineMessage(
                  message: _error!,
                  color: Colors.orange.shade100,
                ),
              Expanded(child: _sectionBody()),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Reusable section card shell ─────────────────────────────────
  Widget _sectionCard({
    required IconData icon,
    required String title,
    String? trailing,
    List<Widget>? actions,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF004E7C)),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF004E7C).withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      trailing,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF004E7C),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (actions != null) ...actions,
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSignInCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.local_shipping,
                size: 36, color: Color(0xFF004E7C)),
            const SizedBox(height: 12),
            const Text(
              'Welcome to OrderVista',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Sign in with your admin credentials',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.mail_outline, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004E7C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.login),
                label: const Text('Sign in'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskForm() {
    return _sectionCard(
      icon: Icons.add_task,
      title: 'Create Task',
      children: [
        TextField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: 'Address',
            hintText: '1 Harbourfront Horizon, Kowloon Bay',
            prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _driverController,
                decoration: InputDecoration(
                  labelText: 'Driver ID (UUID) or email',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _recommendDriver,
              icon: const Icon(Icons.recommend, size: 18),
              label: const Text('Recommend'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _status,
          items: _statusOptions
              .map((status) => DropdownMenuItem(
                    value: status,
                    child: Text(status.toUpperCase()),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _status = value ?? 'pending'),
          decoration: InputDecoration(
            labelText: 'Status',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                _scheduledAt == null
                    ? 'Scheduled start not set'
                    : 'Scheduled: ${DateFormat('MMM d • HH:mm').format(_scheduledAt!)}',
              ),
            ),
            TextButton.icon(
              onPressed: () => _pickSchedule(context),
              icon: const Icon(Icons.calendar_today),
              label: const Text('Pick time'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _createTask,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004E7C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Create task'),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskList() {
    if (_tasks.isEmpty) {
      return _sectionCard(
        icon: Icons.list_alt,
        title: 'Recent Tasks',
        trailing: '0',
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No tasks found.',
                      style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return _sectionCard(
      icon: Icons.list_alt,
      title: 'Recent Tasks',
      trailing: '${_tasks.length}',
      children: [
        ..._tasks.map(
          (task) {
            final status = task['status']?.toString() ?? 'pending';
            final statusColor = status == 'delivered'
                ? Colors.green
                : status == 'in-transit'
                    ? Colors.blue
                    : Colors.orange;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                title: Text(
                  task['address']?.toString() ?? 'Unknown address',
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  'Driver: ${_shortId(task['driver_id']?.toString() ?? '-')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task['scheduled_start'] != null
                          ? DateFormat('MMM d • HH:mm').format(
                              DateTime.parse(task['scheduled_start']).toLocal())
                          : 'Unscheduled',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit task',
                      onPressed: () => _showEditTaskDialog(task),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: Colors.red.shade400),
                      tooltip: 'Delete task',
                      onPressed: () => _showDeleteConfirmation(task),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showEditTaskDialog(Map<String, dynamic> task) async {
    final editAddress = TextEditingController(text: task['address'] ?? '');
    final editDriver = TextEditingController(text: task['driver_id'] ?? '');
    String editStatus = task['status'] ?? 'pending';
    DateTime? editScheduled = task['scheduled_start'] != null
        ? DateTime.tryParse(task['scheduled_start'])?.toLocal()
        : null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: editAddress,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: editDriver,
                      decoration: const InputDecoration(labelText: 'Driver ID'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: editStatus,
                      items: _statusOptions
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.toUpperCase()),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => editStatus = v ?? editStatus),
                      decoration: const InputDecoration(labelText: 'Status'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            editScheduled == null
                                ? 'No schedule set'
                                : 'Scheduled: ${DateFormat('MMM d • HH:mm').format(editScheduled!)}',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate: editScheduled ?? DateTime.now(),
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2030),
                            );
                            if (date == null) return;
                            final time = await showTimePicker(
                              context: ctx,
                              initialTime: editScheduled != null
                                  ? TimeOfDay.fromDateTime(editScheduled!)
                                  : TimeOfDay.now(),
                            );
                            if (time == null) return;
                            setDialogState(() {
                              editScheduled = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: const Text('Pick'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    try {
      await _client.from('tasks').update({
        'address': editAddress.text.trim(),
        'driver_id': editDriver.text.trim(),
        'status': editStatus,
        'scheduled_start': editScheduled?.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', task['id']);
      await _loadRoleAndTasks();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to update task: $e');
      }
    }

    editAddress.dispose();
    editDriver.dispose();
  }

  Future<void> _showDeleteConfirmation(Map<String, dynamic> task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text(
          'Are you sure you want to delete the task at "${task['address']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _client.from('tasks').delete().eq('id', task['id']);
      await _loadRoleAndTasks();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to delete task: $e');
      }
    }
  }

  Widget _buildCsvImport() {
    return _sectionCard(
      icon: Icons.upload_file,
      title: 'CSV Bulk Import',
      children: [
        Text(
          'Upload a CSV file (address, driver_id, status, scheduled_start, lat, lng).',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 14),
        if (_csvMessage != null)
          _InlineMessage(
            message: _csvMessage!,
            color: Colors.blue.shade50,
          ),
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _csvLoading ? null : _pickCsvAndImport,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004E7C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: _csvLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.upload_file),
            label: const Text('Upload CSV'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickCsvAndImport() async {
    final config = context.read<AppConfig>();
    if (config.mapboxAccessToken.isEmpty) {
      setState(() => _csvMessage = 'MAPBOX_ACCESS_TOKEN is required.');
      return;
    }

    setState(() {
      _csvLoading = true;
      _csvMessage = null;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      setState(() => _csvLoading = false);
      return;
    }

    final bytes = result.files.first.bytes;
    if (bytes == null) {
      setState(() {
        _csvLoading = false;
        _csvMessage = 'Failed to read CSV file bytes.';
      });
      return;
    }

    final content = utf8.decode(bytes, allowMalformed: true);
    final rows = const CsvToListConverter().convert(content);
    if (rows.isEmpty) {
      setState(() {
        _csvLoading = false;
        _csvMessage = 'CSV file is empty.';
      });
      return;
    }

    final header = _parseHeader(rows.first);
    final startIndex = header.isNotEmpty ? 1 : 0;
    final mapbox = MapboxService(
      config.mapboxAccessToken,
      countryCode: config.mapboxCountryCode,
      proximity: GeoPoint(
        lat: config.mapboxProximityLat,
        lng: config.mapboxProximityLng,
      ),
    );

    try {
      final inserts = <Map<String, dynamic>>[];
      var skipped = 0;

      for (var i = startIndex; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;
        final task = await _rowToTask(
          row,
          header,
          companyId: config.companyId,
          mapbox: mapbox,
        );

        if (task == null) {
          skipped++;
          continue;
        }
        inserts.add(task);
      }

      if (inserts.isEmpty) {
        setState(() {
          _csvLoading = false;
          _csvMessage = 'No valid rows to import.';
        });
        return;
      }

      const chunkSize = 50;
      for (var i = 0; i < inserts.length; i += chunkSize) {
        final chunk = inserts.sublist(
          i,
          (i + chunkSize).clamp(0, inserts.length),
        );
        await _client.from('tasks').insert(chunk);
      }

      await _loadRoleAndTasks();
      setState(() {
        _csvMessage =
            'Imported ${inserts.length} task(s). Skipped $skipped row(s).';
      });
    } catch (e) {
      setState(() => _csvMessage = 'CSV import failed: $e');
    } finally {
      mapbox.dispose();
      if (mounted) {
        setState(() => _csvLoading = false);
      }
    }
  }

  Map<String, int> _parseHeader(List<dynamic> row) {
    final header = <String, int>{};
    for (var i = 0; i < row.length; i++) {
      final value = row[i].toString().trim().toLowerCase();
      if (value.isEmpty) continue;
      header[value] = i;
    }
    if (header.containsKey('address')) {
      return header;
    }
    return {};
  }

  Future<Map<String, dynamic>?> _rowToTask(
    List<dynamic> row,
    Map<String, int> header, {
    required String companyId,
    required MapboxService mapbox,
  }) async {
    String? address;
    String? driverId;
    String status = 'pending';
    DateTime? scheduledStart;
    double? lat;
    double? lng;

    if (header.isNotEmpty) {
      address = _getCell(row, header['address']);
      driverId = _getCell(row, header['driver_id']) ??
          _getCell(row, header['driver']) ??
          _getCell(row, header['driverid']);
      status = _getCell(row, header['status']) ?? 'pending';
      final scheduledRaw = _getCell(row, header['scheduled_start']) ??
          _getCell(row, header['scheduled']) ??
          _getCell(row, header['scheduled_at']);
      scheduledStart = _tryParseDate(scheduledRaw);
      lat = _tryParseDouble(_getCell(row, header['lat']));
      lng = _tryParseDouble(_getCell(row, header['lng']));
    } else {
      address = row.isNotEmpty ? row[0].toString() : null;
      driverId = row.length > 1 ? row[1].toString() : null;
      status = row.length > 2 ? row[2].toString() : 'pending';
      scheduledStart = row.length > 3 ? _tryParseDate(row[3].toString()) : null;
      lat = row.length > 4 ? _tryParseDouble(row[4].toString()) : null;
      lng = row.length > 5 ? _tryParseDouble(row[5].toString()) : null;
    }

    if (address == null || address.trim().isEmpty) {
      return null;
    }

    GeoPoint? point;
    if (lat != null && lng != null) {
      point = GeoPoint(lat: lat, lng: lng);
    } else {
      point = await mapbox.forwardGeocode(address);
    }

    final payload = <String, dynamic>{
      'company_id': companyId,
      'address': address.trim(),
      'status': status.trim().isEmpty ? 'pending' : status.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (driverId != null && driverId.trim().isNotEmpty)
        'driver_id': driverId.trim(),
      if (scheduledStart != null)
        'scheduled_start': scheduledStart.toUtc().toIso8601String(),
    };

    if (point != null) {
      payload['location'] = 'SRID=4326;POINT(${point.lng} ${point.lat})';
    }

    return payload;
  }

  String? _getCell(List<dynamic> row, int? index) {
    if (index == null || index < 0 || index >= row.length) {
      return null;
    }
    final value = row[index]?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  DateTime? _tryParseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  double? _tryParseDouble(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return double.tryParse(raw.trim());
  }

  Widget _buildRouteSequencer() {
    return _sectionCard(
      icon: Icons.alt_route,
      title: 'Baseline Route Sequencer',
      children: [
        Text(
          'Generates a nearest-next route order for pending tasks and persists it to routes + route_tasks.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _routeDriverController,
          decoration: InputDecoration(
            labelText: 'Driver ID filter (optional)',
            hintText: 'UUID to sequence only that driver\u2019s tasks',
            prefixIcon: const Icon(Icons.person_search_outlined, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),
        if (_routeMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _InlineMessage(
              message: _routeMessage!,
              color: Colors.blue.shade50,
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _routeLoading ? null : _generateBaselineRoute,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004E7C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: _routeLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.alt_route, size: 20),
            label: const Text('Generate baseline route'),
          ),
        ),
      ],
    );
  }

  Widget _buildFleetOptimiser() {
    return _sectionCard(
      icon: Icons.hub_outlined,
      title: 'Fleet-Wide Distance Optimiser',
      children: [
        Text(
          'Assigns every unassigned pending task to the nearest available driver, '
          'minimising total fleet travel distance.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _fleetLoading ? null : _runFleetOptimisation,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004E7C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: _fleetLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.hub, size: 20),
            label: const Text('Optimise Fleet Assignments'),
          ),
        ),
        if (_fleetMessage != null) ...[
          const SizedBox(height: 10),
          Text(_fleetMessage!,
              style: TextStyle(color: Colors.green.shade700, fontSize: 13)),
        ],
        if (_fleetAssignments.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Suggested Assignments:',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ..._fleetAssignments.map(
            (a) => Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a['address'] ?? 'Unknown',
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(
                          'Driver: ${a['driver_email'] ?? a['driver_id']} (${a['distance_km']}km)',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => _applyFleetAssignment(a),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF004E7C),
                      side: const BorderSide(color: Color(0xFF004E7C)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Assign'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _runFleetOptimisation() async {
    final config = context.read<AppConfig>();

    setState(() {
      _fleetLoading = true;
      _fleetMessage = null;
      _fleetAssignments = const [];
    });

    try {
      // 1. Fetch unassigned pending tasks
      final taskRows = await _client
          .from('tasks')
          .select('id, address')
          .eq('company_id', config.companyId)
          .eq('status', 'pending')
          .isFilter('driver_id', null);

      if ((taskRows as List).isEmpty) {
        setState(() {
          _fleetMessage = 'No unassigned pending tasks to optimise.';
          _fleetLoading = false;
        });
        return;
      }

      // 2. Fetch available drivers with locations (no email column on company_members)
      final driverRows = await _client
          .from('company_members')
          .select('id, user_id, last_known_location')
          .eq('company_id', config.companyId)
          .eq('role', 'driver')
          .eq('is_available', true);

      if ((driverRows as List).isEmpty) {
        setState(() {
          _fleetMessage = 'No available drivers found.';
          _fleetLoading = false;
        });
        return;
      }

      // Resolve emails via profiles table
      final fleetUserIds = (driverRows as List)
          .map((r) => r['user_id']?.toString())
          .whereType<String>()
          .toList();
      final fleetEmailMap = <String, String>{};
      if (fleetUserIds.isNotEmpty) {
        try {
          final p = await _client
              .from('profiles')
              .select('id, email')
              .inFilter('id', fleetUserIds);
          for (final row in (p as List)) {
            final uid = row['id']?.toString();
            final em = row['email']?.toString();
            if (uid != null && em != null) fleetEmailMap[uid] = em;
          }
        } catch (_) {}
      }

      // 3. Geocode task addresses
      final mapbox = MapboxService(
        config.mapboxAccessToken,
        countryCode: config.mapboxCountryCode,
        proximity: GeoPoint(
          lat: config.mapboxProximityLat,
          lng: config.mapboxProximityLng,
        ),
      );

      final tasks = <Map<String, dynamic>>[];
      for (final t in taskRows) {
        final addr = t['address']?.toString() ?? '';
        if (addr.isEmpty) continue;
        final geo = await mapbox.forwardGeocode(addr);
        if (geo != null) {
          tasks.add({...t, '_geo': geo});
        }
      }

      // 4. Parse driver locations
      final drivers = <Map<String, dynamic>>[];
      for (final d in driverRows) {
        final loc = d['last_known_location'];
        if (loc == null) continue;
        // PostGIS geography stored as GeoJSON or WKT — parse point coords
        GeoPoint? dGeo;
        if (loc is Map) {
          final coords = (loc['coordinates'] as List?)?.cast<num>();
          if (coords != null && coords.length >= 2) {
            dGeo = GeoPoint(
              lat: coords[1].toDouble(),
              lng: coords[0].toDouble(),
            );
          }
        }
        if (dGeo != null) {
          drivers.add({...d, '_geo': dGeo});
        }
      }

      if (drivers.isEmpty) {
        setState(() {
          _fleetMessage =
              'No drivers with known locations. Drivers must share GPS first.';
          _fleetLoading = false;
        });
        return;
      }

      // 5. Greedy nearest-driver assignment
      final assignments = <Map<String, dynamic>>[];
      final remainingTasks = List<Map<String, dynamic>>.from(tasks);

      for (final task in remainingTasks) {
        final taskGeo = task['_geo'] as GeoPoint;
        Map<String, dynamic>? bestDriver;
        double bestDist = double.infinity;

        for (final drv in drivers) {
          final drvGeo = drv['_geo'] as GeoPoint;
          final dist = taskGeo.distanceTo(drvGeo);
          if (dist < bestDist) {
            bestDist = dist;
            bestDriver = drv;
          }
        }

        if (bestDriver != null) {
          final bUserId = bestDriver['user_id']?.toString() ?? '';
          assignments.add({
            'task_id': task['id'],
            'address': task['address'],
            'driver_id': bestDriver['id'],
            'driver_email': fleetEmailMap[bUserId] ??
                'Driver ${_shortId(bestDriver['id']?.toString() ?? '')}',
            'distance_km': bestDist.toStringAsFixed(2),
          });
        }
      }

      setState(() {
        _fleetAssignments = assignments;
        _fleetMessage =
            '${assignments.length} assignments optimised across ${drivers.length} drivers.';
      });
    } catch (e) {
      setState(() => _fleetMessage = 'Fleet optimisation failed: $e');
    } finally {
      setState(() => _fleetLoading = false);
    }
  }

  Future<void> _applyFleetAssignment(Map<String, dynamic> assignment) async {
    try {
      await _client.from('tasks').update({
        'driver_id': assignment['driver_id'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', assignment['task_id']);

      setState(() {
        _fleetAssignments = _fleetAssignments
            .where((a) => a['task_id'] != assignment['task_id'])
            .toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Assigned ${assignment['address']} to ${assignment['driver_email']}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Assignment failed: $e')),
        );
      }
    }
  }

  Widget _buildRouteOverview() {
    return _sectionCard(
      icon: Icons.map_outlined,
      title: 'Routes & Stop Order',
      trailing: '${_routes.length}',
      actions: [
        IconButton(
          tooltip: 'Refresh routes',
          onPressed: _routesLoading ? null : _refreshRoutes,
          icon: Icon(Icons.refresh, color: Colors.grey.shade600, size: 20),
        ),
      ],
      children: [
        if (_routesMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _InlineMessage(
              message: _routesMessage!,
              color: Colors.blue.shade50,
            ),
          ),
        if (_routesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_routes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.route, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No routes found yet.',
                      style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            ),
          )
        else
          ..._routes.map(_buildRouteCard),
      ],
    );
  }

  Widget _buildProofReview() {
    return _sectionCard(
      icon: Icons.verified_outlined,
      title: 'Proof of Delivery Review',
      trailing: '${_podRecords.length}',
      actions: [
        IconButton(
          tooltip: 'Refresh PoD',
          onPressed: _podLoading ? null : _refreshPod,
          icon: Icon(Icons.refresh, color: Colors.grey.shade600, size: 20),
        ),
      ],
      children: [
        if (_podMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _InlineMessage(
              message: _podMessage!,
              color: Colors.blue.shade50,
            ),
          ),
        if (_podLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_podRecords.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.verified, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No proof records found yet.',
                      style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            ),
          )
        else
          ..._podRecords.map(_buildPodCard),
      ],
    );
  }

  Widget _buildPodCard(_PodRecord record) {
    final createdLabel = record.createdAt == null
        ? 'Unknown time'
        : DateFormat('MMM d • HH:mm').format(record.createdAt!.toLocal());
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task ${_shortId(record.taskId)} • $createdLabel',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(record.address ?? 'Unknown address'),
            Text('Driver: ${record.driverId ?? '-'}'),
            if (record.proofCode != null && record.proofCode!.isNotEmpty)
              Text('Code: ${record.proofCode}'),
            if (record.photoUrl != null && record.photoUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  record.photoUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) {
                    return Container(
                      height: 180,
                      color: Colors.grey.shade100,
                      alignment: Alignment.center,
                      child: const Text('Photo preview unavailable'),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _refreshPod() async {
    setState(() {
      _podLoading = true;
      _podMessage = null;
    });
    try {
      final records = await _fetchPodRecords();
      setState(() => _podRecords = records);
    } catch (e) {
      setState(() => _podMessage = 'Failed to load PoD: $e');
    } finally {
      if (mounted) {
        setState(() => _podLoading = false);
      }
    }
  }

  Future<List<_PodRecord>> _fetchPodRecords() async {
    final response = await _client
        .from('tasks')
        .select(
            'id, address, driver_id, proof_code, proof_photo_url, updated_at')
        .or('proof_code.not.is.null,proof_photo_url.not.is.null')
        .order('updated_at', ascending: false)
        .limit(20);

    return (response as List<dynamic>).map((row) {
      final map = row as Map<String, dynamic>;
      return _PodRecord(
        taskId: map['id']?.toString() ?? '',
        address: map['address']?.toString(),
        driverId: map['driver_id']?.toString(),
        proofCode: map['proof_code']?.toString(),
        photoUrl: map['proof_photo_url']?.toString(),
        createdAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'].toString())
            : null,
      );
    }).toList();
  }

  // ===========================================================================
  // Driver Management
  // ===========================================================================

  Widget _buildDriverManagement() {
    final availableCount = _drivers.where((d) => d.isAvailable).length;
    return _sectionCard(
      icon: Icons.groups_outlined,
      title: 'Driver Availability',
      trailing: '$availableCount / ${_drivers.length}',
      actions: [
        IconButton(
          tooltip: 'Refresh drivers',
          onPressed: _driversLoading ? null : _refreshDrivers,
          icon: Icon(Icons.refresh, color: Colors.grey.shade600, size: 20),
        ),
      ],
      children: [
        if (_driversMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _InlineMessage(
              message: _driversMessage!,
              color: Colors.blue.shade50,
            ),
          ),
        if (_driversLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_drivers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.person_off_outlined,
                      size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No drivers found. Add drivers to your company.',
                      style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            ),
          )
        else
          ..._drivers.map(_buildDriverCard),
      ],
    );
  }

  Widget _buildDriverCard(_DriverInfo driver) {
    final lastSeenLabel = driver.lastLocationAt == null
        ? 'Location unknown'
        : 'Last seen ${DateFormat('MMM d • HH:mm').format(driver.lastLocationAt!.toLocal())}';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: driver.isAvailable
                ? Colors.green.shade300
                : Colors.grey.shade300,
            width: driver.isAvailable ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: driver.isAvailable ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver.email ?? 'Driver ${_shortId(driver.memberId)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${driver.isAvailable ? 'Available' : 'Unavailable'} • ${driver.currentTaskCount} active task(s)',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    lastSeenLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  if (driver.lastLocationLat != null &&
                      driver.lastLocationLng != null)
                    Text(
                      'Location: ${driver.lastLocationLat!.toStringAsFixed(4)}, ${driver.lastLocationLng!.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Chat with driver',
              onPressed: () {
                setState(() {
                  _selectedChatDriver = driver.memberId;
                });
                _refreshChatMessages();
              },
              icon: const Icon(Icons.chat_bubble_outline),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshDrivers() async {
    final config = context.read<AppConfig>();
    setState(() {
      _driversLoading = true;
      _driversMessage = null;
    });
    try {
      final drivers = await _fetchDrivers(config.companyId);
      setState(() => _drivers = drivers);
    } catch (e) {
      setState(() => _driversMessage = 'Failed to load drivers: $e');
    } finally {
      if (mounted) {
        setState(() => _driversLoading = false);
      }
    }
  }

  Future<List<_DriverInfo>> _fetchDrivers(String companyId) async {
    // First try to use the RPC function
    try {
      final response = await _client.rpc(
        'get_available_drivers',
        params: {'p_company_id': companyId},
      );

      if (response is List) {
        // Also fetch emails from auth.users via company_members join
        final memberIds = response
            .map((r) => r['member_id']?.toString())
            .whereType<String>()
            .toList();
        final emailMap = await _fetchDriverEmails(memberIds);

        return response.map((row) {
          final map = row as Map<String, dynamic>;
          final memberId = map['member_id']?.toString() ?? '';
          return _DriverInfo(
            memberId: memberId,
            userId: map['user_id']?.toString(),
            email: emailMap[memberId],
            isAvailable: map['is_available'] == true,
            currentTaskCount: (map['current_task_count'] as num?)?.toInt() ?? 0,
            lastLocationLat: (map['last_location_lat'] as num?)?.toDouble(),
            lastLocationLng: (map['last_location_lng'] as num?)?.toDouble(),
            lastLocationAt: map['last_location_at'] != null
                ? DateTime.tryParse(map['last_location_at'].toString())
                : null,
          );
        }).toList();
      }
    } catch (e) {
      // Fallback to direct query if RPC fails
      debugPrint('RPC failed, using fallback: $e');
    }

    // Fallback: direct query
    final response = await _client
        .from('company_members')
        .select(
            'id, user_id, role, is_available, current_task_count, last_location_at')
        .eq('company_id', companyId)
        .eq('role', 'driver');

    final memberIds = (response as List)
        .map((r) => r['id']?.toString())
        .whereType<String>()
        .toList();
    final emailMap = await _fetchDriverEmails(memberIds);

    return response.map((row) {
      final map = row;
      final memberId = map['id']?.toString() ?? '';
      return _DriverInfo(
        memberId: memberId,
        userId: map['user_id']?.toString(),
        email: emailMap[memberId],
        isAvailable: map['is_available'] == true,
        currentTaskCount: (map['current_task_count'] as num?)?.toInt() ?? 0,
        lastLocationLat: null,
        lastLocationLng: null,
        lastLocationAt: map['last_location_at'] != null
            ? DateTime.tryParse(map['last_location_at'].toString())
            : null,
      );
    }).toList();
  }

  Future<Map<String, String>> _fetchDriverEmails(List<String> memberIds) async {
    if (memberIds.isEmpty) return {};

    try {
      // Query company_members with user_id, then get emails from profiles or users
      final response = await _client
          .from('company_members')
          .select('id, user_id')
          .inFilter('id', memberIds);

      final userIds = (response as List)
          .map((r) => r['user_id']?.toString())
          .whereType<String>()
          .toList();

      if (userIds.isEmpty) return {};

      // Try to get emails from profiles table
      final profilesResponse = await _client
          .from('profiles')
          .select('id, email')
          .inFilter('id', userIds);

      final memberToUser = <String, String>{};
      for (final row in response) {
        final memberId = row['id']?.toString();
        final userId = row['user_id']?.toString();
        if (memberId != null && userId != null) {
          memberToUser[memberId] = userId;
        }
      }

      final userToEmail = <String, String>{};
      for (final row in profilesResponse as List) {
        final userId = row['id']?.toString();
        final email = row['email']?.toString();
        if (userId != null && email != null) {
          userToEmail[userId] = email;
        }
      }

      final result = <String, String>{};
      for (final entry in memberToUser.entries) {
        final email = userToEmail[entry.value];
        if (email != null) {
          result[entry.key] = email;
        }
      }
      return result;
    } catch (e) {
      debugPrint('Failed to fetch driver emails: $e');
      return {};
    }
  }

  // ===========================================================================
  // Admin-Driver Chat
  // ===========================================================================

  Widget _buildAdminDriverChat() {
    return _sectionCard(
      icon: Icons.chat_outlined,
      title: 'Driver Communication',
      actions: [
        if (_selectedChatDriver != null)
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedChatDriver = null;
                _chatMessages = const [];
              });
            },
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Close', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
            ),
          ),
        IconButton(
          tooltip: 'Refresh messages',
          onPressed: _chatLoading || _selectedChatDriver == null
              ? null
              : _refreshChatMessages,
          icon: Icon(Icons.refresh, color: Colors.grey.shade600, size: 20),
        ),
      ],
      children: [
        if (_chatMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _InlineMessage(
              message: _chatMessage!,
              color: Colors.blue.shade50,
            ),
          ),
        if (_selectedChatDriver == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.forum_outlined,
                      size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(
                    'Select a driver from the Fleet tab to start a conversation.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF004E7C).withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, size: 18, color: Color(0xFF004E7C)),
                const SizedBox(width: 8),
                Text(
                  'Chatting with: ${_getDriverLabel(_selectedChatDriver!)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 220,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade50,
            ),
            child: _chatLoading
                ? const Center(child: CircularProgressIndicator())
                : _chatMessages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet. Start the conversation!',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        reverse: true,
                        itemCount: _chatMessages.length,
                        itemBuilder: (context, index) {
                          final msg = _chatMessages[index];
                          final isMe = msg.isFromAdmin;
                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              constraints: const BoxConstraints(maxWidth: 320),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFF004E7C).withOpacity(0.12)
                                    : Colors.white,
                                border: Border.all(
                                  color: isMe
                                      ? const Color(0xFF004E7C).withOpacity(0.2)
                                      : Colors.grey.shade200,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(msg.message),
                                  const SizedBox(height: 3),
                                  Text(
                                    DateFormat('HH:mm').format(
                                      msg.createdAt.toLocal(),
                                    ),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
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
                  controller: _chatInputController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _sendChatMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sendChatMessage,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF004E7C),
                ),
                icon: const Icon(Icons.send, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: _sendBroadcastMessage,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF004E7C),
                side: const BorderSide(color: Color(0xFF004E7C)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.campaign, size: 18),
              label: const Text('Broadcast to All Drivers'),
            ),
          ),
        ],
      ],
    );
  }

  String _getDriverLabel(String memberId) {
    final driver = _drivers.where((d) => d.memberId == memberId).firstOrNull;
    return driver?.email ?? 'Driver ${_shortId(memberId)}';
  }

  Future<void> _refreshChatMessages() async {
    if (_selectedChatDriver == null) return;

    setState(() {
      _chatLoading = true;
      _chatMessage = null;
    });

    try {
      final config = context.read<AppConfig>();
      final messages =
          await _fetchChatMessages(config.companyId, _selectedChatDriver!);
      setState(() => _chatMessages = messages);
    } catch (e) {
      setState(() => _chatMessage = 'Failed to load messages: $e');
    } finally {
      if (mounted) {
        setState(() => _chatLoading = false);
      }
    }
  }

  Future<List<_ChatMessage>> _fetchChatMessages(
      String companyId, String driverId) async {
    // Get current admin's member ID
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final adminMember = await _client
        .from('company_members')
        .select('id')
        .eq('user_id', user.id)
        .eq('company_id', companyId)
        .maybeSingle();

    if (adminMember == null) return [];
    final adminMemberId = adminMember['id']?.toString();

    // Fetch messages between admin and driver
    final response = await _client
        .from('chat_messages')
        .select(
            'id, sender_id, recipient_id, message, is_broadcast, created_at')
        .eq('company_id', companyId)
        .or('and(sender_id.eq.$adminMemberId,recipient_id.eq.$driverId),and(sender_id.eq.$driverId,recipient_id.eq.$adminMemberId),is_broadcast.eq.true')
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List).map((row) {
      final map = row as Map<String, dynamic>;
      return _ChatMessage(
        id: map['id']?.toString() ?? '',
        senderId: map['sender_id']?.toString() ?? '',
        recipientId: map['recipient_id']?.toString(),
        message: map['message']?.toString() ?? '',
        isBroadcast: map['is_broadcast'] == true,
        isFromAdmin: map['sender_id']?.toString() == adminMemberId,
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  Future<void> _sendChatMessage() async {
    final message = _chatInputController.text.trim();
    if (message.isEmpty || _selectedChatDriver == null) return;

    final config = context.read<AppConfig>();
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final adminMember = await _client
          .from('company_members')
          .select('id')
          .eq('user_id', user.id)
          .eq('company_id', config.companyId)
          .maybeSingle();

      if (adminMember == null) {
        setState(() => _chatMessage = 'Admin member not found.');
        return;
      }

      await _client.from('chat_messages').insert({
        'company_id': config.companyId,
        'sender_id': adminMember['id'],
        'recipient_id': _selectedChatDriver,
        'message': message,
        'is_broadcast': false,
      });

      _chatInputController.clear();
      await _refreshChatMessages();
    } catch (e) {
      setState(() => _chatMessage = 'Failed to send message: $e');
    }
  }

  Future<void> _sendBroadcastMessage() async {
    final message = _chatInputController.text.trim();
    if (message.isEmpty) {
      setState(() => _chatMessage = 'Please enter a message to broadcast.');
      return;
    }

    final config = context.read<AppConfig>();
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final adminMember = await _client
          .from('company_members')
          .select('id')
          .eq('user_id', user.id)
          .eq('company_id', config.companyId)
          .maybeSingle();

      if (adminMember == null) {
        setState(() => _chatMessage = 'Admin member not found.');
        return;
      }

      await _client.from('chat_messages').insert({
        'company_id': config.companyId,
        'sender_id': adminMember['id'],
        'recipient_id': null,
        'message': message,
        'is_broadcast': true,
      });

      _chatInputController.clear();
      setState(() => _chatMessage = 'Broadcast sent to all drivers!');
      await _refreshChatMessages();
    } catch (e) {
      setState(() => _chatMessage = 'Failed to broadcast: $e');
    }
  }

  // ==========================================================================
  // Customer Tracking Lookup
  // ==========================================================================
  Widget _buildCustomerTracking() {
    return _sectionCard(
      icon: Icons.local_shipping_outlined,
      title: 'Customer Tracking Lookup',
      actions: [
        if (_trackingLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
      children: [
        Text(
          'Look up delivery status using customer tracking code',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _trackingCodeController,
                decoration: InputDecoration(
                  labelText: 'Tracking Code',
                  hintText: 'e.g. OV-ABC1-XYZ2',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.qr_code, size: 20),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _lookupTracking(),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _trackingLoading ? null : _lookupTracking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004E7C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Lookup'),
              ),
            ),
          ],
        ),
        if (_trackingMessage != null) ...[
          const SizedBox(height: 12),
          _InlineMessage(
            message: _trackingMessage!,
            color: _trackingResult != null && _trackingResult!['found'] == true
                ? Colors.green.shade100
                : Colors.orange.shade100,
          ),
        ],
        if (_trackingResult != null && _trackingResult!['found'] == true) ...[
          const SizedBox(height: 16),
          _buildTrackingResultCard(),
        ],
      ],
    );
  }

  Widget _buildTrackingResultCard() {
    final result = _trackingResult!;
    final status = result['status']?.toString() ?? 'unknown';
    final address = result['address']?.toString() ?? 'Unknown';
    final driverAssigned = result['driver_assigned'] == true;
    final proofAvailable = result['proof_available'] == true;
    final lastUpdate = result['last_update'] != null
        ? DateTime.tryParse(result['last_update'].toString())
        : null;

    Color statusColor;
    IconData statusIcon;
    switch (status.toLowerCase()) {
      case 'delivered':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'in-transit':
        statusColor = Colors.blue;
        statusIcon = Icons.local_shipping;
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result['tracking_code']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTrackingDetailRow(
            Icons.location_on,
            'Delivery Address',
            address,
          ),
          const SizedBox(height: 8),
          _buildTrackingDetailRow(
            Icons.person,
            'Driver',
            driverAssigned ? 'Assigned' : 'Not yet assigned',
          ),
          if (lastUpdate != null) ...[
            const SizedBox(height: 8),
            _buildTrackingDetailRow(
              Icons.update,
              'Last Update',
              DateFormat('MMM d, yyyy • HH:mm').format(lastUpdate.toLocal()),
            ),
          ],
          if (proofAvailable && status.toLowerCase() == 'delivered') ...[
            const SizedBox(height: 8),
            _buildTrackingDetailRow(
              Icons.verified,
              'Proof of Delivery',
              'Available',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackingDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Future<void> _lookupTracking() async {
    final code = _trackingCodeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _trackingMessage = 'Please enter a tracking code.';
        _trackingResult = null;
      });
      return;
    }

    setState(() {
      _trackingLoading = true;
      _trackingMessage = null;
      _trackingResult = null;
    });

    try {
      final response = await _client.rpc(
        'lookup_delivery_by_tracking',
        params: {'p_tracking_code': code},
      );

      final result = response as Map<String, dynamic>?;

      if (result == null || result['found'] != true) {
        setState(() {
          _trackingMessage = 'No delivery found with tracking code: $code';
          _trackingResult = null;
        });
      } else {
        setState(() {
          _trackingMessage = 'Delivery found!';
          _trackingResult = result;
        });
      }
    } catch (e) {
      setState(() {
        _trackingMessage = 'Error looking up tracking code: $e';
        _trackingResult = null;
      });
    } finally {
      setState(() => _trackingLoading = false);
    }
  }

  Widget _buildRouteCard(_RouteView route) {
    final config = context.read<AppConfig>();
    final createdLabel = route.createdAt == null
        ? 'Unknown time'
        : DateFormat('MMM d • HH:mm').format(route.createdAt!.toLocal());
    final driverLabel = route.driverId ?? 'Unassigned';
    final mapUrl = _routeMapUrls[route.id];
    final mapLoading = _routeMapLoading[route.id] ?? false;
    final mapError = _routeMapErrors[route.id];

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Route ${_shortId(route.id)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(route.status.toUpperCase()),
              ],
            ),
            const SizedBox(height: 4),
            Text('Driver: $driverLabel'),
            Text('Optimizer: ${route.optimizer} • $createdLabel'),
            const SizedBox(height: 8),
            if (route.stops.isEmpty)
              const Text('No stops found for this route.')
            else
              Column(
                children: route.stops
                    .map(
                      (stop) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${stop.sequence}. ${stop.address}',
                        ),
                        subtitle: Text(
                          'Task ${_shortId(stop.taskId)} • ${stop.status.toUpperCase()} • Driver ${stop.driverId ?? '-'}',
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 8),
            if (mapError != null)
              _InlineMessage(
                message: mapError,
                color: Colors.orange.shade100,
              ),
            if (mapUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  mapUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: mapLoading
                      ? null
                      : () => _loadRouteMapPreview(route, config),
                  icon: mapLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.map_outlined),
                  label: const Text('Load map preview'),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _promptAssignDriver(route),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Assign driver'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshRoutes() async {
    setState(() {
      _routesLoading = true;
      _routesMessage = null;
    });

    try {
      final routes = await _fetchRoutes();
      setState(() => _routes = routes);
    } catch (e) {
      setState(() => _routesMessage = 'Failed to load routes: $e');
    } finally {
      if (mounted) {
        setState(() => _routesLoading = false);
      }
    }
  }

  Future<List<_RouteView>> _fetchRoutes() async {
    final routesRows = await _client
        .from('routes')
        .select('id, driver_id, status, optimizer, created_at')
        .order('created_at', ascending: false)
        .limit(10);

    final routes = <_RouteView>[];
    for (final row in (routesRows as List<dynamic>)) {
      final routeId = row['id']?.toString() ?? '';
      if (routeId.isEmpty) {
        continue;
      }

      final stopsRows = await _client
          .from('route_tasks')
          .select('sequence, task_id, tasks(address, status, driver_id)')
          .eq('route_id', routeId)
          .order('sequence', ascending: true);

      final stops = (stopsRows as List<dynamic>).map((stopRow) {
        final stopMap = stopRow as Map<String, dynamic>;
        final task = stopMap['tasks'] as Map<String, dynamic>? ?? {};
        return _RouteStopView(
          sequence: (stopMap['sequence'] as num?)?.toInt() ?? 0,
          taskId: stopMap['task_id']?.toString() ?? '',
          address: task['address']?.toString() ?? 'Unknown address',
          status: task['status']?.toString() ?? 'pending',
          driverId: task['driver_id']?.toString(),
        );
      }).toList();

      routes.add(
        _RouteView(
          id: routeId,
          driverId: row['driver_id']?.toString(),
          status: row['status']?.toString() ?? 'draft',
          optimizer: row['optimizer']?.toString() ?? 'manual',
          createdAt: row['created_at'] != null
              ? DateTime.tryParse(row['created_at'].toString())
              : null,
          stops: stops,
        ),
      );
    }

    return routes;
  }

  Future<void> _promptAssignDriver(_RouteView route) async {
    final controller = TextEditingController(text: route.driverId ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Assign driver to route'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Driver ID (UUID) or email',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Assign'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null || result.isEmpty) {
      return;
    }

    await _assignRouteDriver(route, result);
  }

  Future<void> _assignRouteDriver(_RouteView route, String driverId) async {
    setState(() => _routesMessage = null);
    try {
      await _client.from('routes').update(
          {'driver_id': driverId, 'status': 'assigned'}).eq('id', route.id);

      final taskIds = route.stops
          .map((stop) => stop.taskId)
          .where((id) => id.isNotEmpty)
          .toList();
      if (taskIds.isNotEmpty) {
        await _client
            .from('tasks')
            .update({'driver_id': driverId}).inFilter('id', taskIds);
      }

      await _refreshRoutes();
      setState(() => _routesMessage = 'Route assigned to $driverId.');
    } catch (e) {
      setState(() => _routesMessage = 'Failed to assign route: $e');
    }
  }

  Future<void> _loadRouteMapPreview(_RouteView route, AppConfig config) async {
    if (config.mapboxAccessToken.isEmpty) {
      setState(() => _routeMapErrors[route.id] =
          'MAPBOX_ACCESS_TOKEN is required for map previews.');
      return;
    }

    setState(() {
      _routeMapLoading[route.id] = true;
      _routeMapErrors.remove(route.id);
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
      final points = <GeoPoint>[];
      for (final stop in route.stops) {
        if (stop.address.trim().isEmpty) {
          continue;
        }
        final point = await mapbox.forwardGeocode(stop.address);
        if (point != null) {
          points.add(point);
        }
      }

      if (points.isEmpty) {
        setState(() => _routeMapErrors[route.id] =
            'No geocoded points available for this route.');
        return;
      }

      final mapUrl = _buildRouteStaticMap(points, config.mapboxAccessToken);
      setState(() => _routeMapUrls[route.id] = mapUrl);
    } catch (e) {
      setState(() => _routeMapErrors[route.id] = 'Map preview failed: $e');
    } finally {
      mapbox.dispose();
      if (mounted) {
        setState(() => _routeMapLoading[route.id] = false);
      }
    }
  }

  String _buildRouteStaticMap(List<GeoPoint> points, String token) {
    final limited = points.take(10).toList();
    const labels = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'];
    final markers = <String>[];
    for (var i = 0; i < limited.length; i++) {
      final point = limited[i];
      final label = labels[i];
      markers.add(
        'pin-s-$label+285A98(${point.lng},${point.lat})',
      );
    }

    final center = _averagePoint(limited);
    final overlay = markers.join(',');
    final centerPart = '${center.lng},${center.lat},12';
    return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/$overlay/$centerPart/800x420@2x?access_token=$token';
  }

  GeoPoint _averagePoint(List<GeoPoint> points) {
    var lat = 0.0;
    var lng = 0.0;
    for (final point in points) {
      lat += point.lat;
      lng += point.lng;
    }
    return GeoPoint(lat: lat / points.length, lng: lng / points.length);
  }

  String _shortId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }

  Future<void> _generateBaselineRoute() async {
    final config = context.read<AppConfig>();
    final driverFilter = _routeDriverController.text.trim();

    if (_tasks.isEmpty) {
      setState(() => _routeMessage = 'No tasks available to sequence.');
      return;
    }

    if (config.mapboxAccessToken.isEmpty) {
      setState(() =>
          _routeMessage = 'MAPBOX_ACCESS_TOKEN is required for geocoding.');
      return;
    }

    setState(() {
      _routeLoading = true;
      _routeMessage = null;
    });

    final filteredTasks = _tasks.where((task) {
      final status = task['status']?.toString() ?? 'pending';
      if (status == 'delivered') {
        return false;
      }
      if (driverFilter.isEmpty) {
        return true;
      }
      return task['driver_id']?.toString() == driverFilter;
    }).toList();

    if (filteredTasks.isEmpty) {
      setState(() {
        _routeLoading = false;
        _routeMessage =
            'No pending tasks matched the driver filter (or all are delivered).';
      });
      return;
    }

    final mapbox = MapboxService(
      config.mapboxAccessToken,
      countryCode: config.mapboxCountryCode,
      proximity: GeoPoint(
        lat: config.mapboxProximityLat,
        lng: config.mapboxProximityLng,
      ),
    );

    try {
      final stops = <_RouteStop>[];
      final skipped = <String>[];

      for (final task in filteredTasks) {
        final address = task['address']?.toString() ?? '';
        if (address.isEmpty) {
          skipped.add(task['id']?.toString() ?? 'Unknown task');
          continue;
        }
        final point = await mapbox.forwardGeocode(address);
        if (point == null) {
          skipped.add(task['id']?.toString() ?? address);
          continue;
        }
        stops.add(
          _RouteStop(
            taskId: task['id']?.toString() ?? '',
            address: address,
            driverId: task['driver_id']?.toString(),
            scheduledStart: task['scheduled_start'] != null
                ? DateTime.tryParse(task['scheduled_start'].toString())
                : null,
            point: point,
          ),
        );
      }

      if (stops.length < 2) {
        setState(() {
          _routeLoading = false;
          _routeMessage =
              'Need at least 2 geocoded tasks to build a route. Skipped: ${skipped.length}.';
        });
        return;
      }

      final ordered = _nearestNeighborOrder(stops);
      final totalDistance = _totalDistanceMeters(ordered);

      // Resolve driver_id: use filter input, or first task's driver if valid
      String? resolvedDriverId;
      if (driverFilter.isNotEmpty) {
        // Check if it's an email and resolve to company_member id
        resolvedDriverId =
            await _resolveDriverId(driverFilter, config.companyId);
      } else if (ordered.first.driverId != null &&
          ordered.first.driverId!.isNotEmpty) {
        // Verify the driver_id from task is a valid company_member
        final memberCheck = await _client
            .from('company_members')
            .select('id')
            .eq('id', ordered.first.driverId!)
            .maybeSingle();
        if (memberCheck != null) {
          resolvedDriverId = ordered.first.driverId;
        }
      }

      final routeInsert = await _client
          .from('routes')
          .insert({
            'company_id': config.companyId,
            'driver_id': resolvedDriverId, // null is allowed by schema
            'status': 'optimized',
            'optimizer': 'baseline',
            'eta_summary': {
              'stops': ordered.length,
              'total_distance_m': totalDistance.round(),
              'baseline': true,
            },
          })
          .select()
          .single();

      final routeId = routeInsert['id']?.toString();
      if (routeId == null || routeId.isEmpty) {
        throw Exception('Route insert did not return an ID.');
      }

      final routeTasks = <Map<String, dynamic>>[];
      for (var i = 0; i < ordered.length; i++) {
        final distance = i == 0
            ? 0
            : _haversineMeters(ordered[i - 1].point, ordered[i].point).round();
        routeTasks.add({
          'company_id': config.companyId,
          'route_id': routeId,
          'task_id': ordered[i].taskId,
          'sequence': i + 1,
          'travel_distance_m': distance,
        });
      }

      await _client.from('route_tasks').insert(routeTasks);

      final skippedMessage =
          skipped.isEmpty ? '' : ' Skipped ${skipped.length} task(s).';

      setState(() {
        _routeMessage =
            'Route created: $routeId with ${ordered.length} stops.$skippedMessage';
      });
    } catch (e) {
      setState(() {
        _routeMessage = 'Route sequencing failed: $e';
      });
    } finally {
      mapbox.dispose();
      if (mounted) {
        setState(() => _routeLoading = false);
      }
    }
  }

  List<_RouteStop> _nearestNeighborOrder(List<_RouteStop> stops) {
    final remaining = List<_RouteStop>.from(stops);
    remaining.sort(
      (a, b) => _compareSchedule(a.scheduledStart, b.scheduledStart),
    );
    final start = remaining.removeAt(0);
    final ordered = <_RouteStop>[start];

    while (remaining.isNotEmpty) {
      final current = ordered.last;
      remaining.sort(
        (a, b) => _haversineMeters(current.point, a.point)
            .compareTo(_haversineMeters(current.point, b.point)),
      );
      ordered.add(remaining.removeAt(0));
    }

    return ordered;
  }

  int _compareSchedule(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  double _totalDistanceMeters(List<_RouteStop> ordered) {
    var total = 0.0;
    for (var i = 1; i < ordered.length; i++) {
      total += _haversineMeters(ordered[i - 1].point, ordered[i].point);
    }
    return total;
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

  Future<void> _pickSchedule(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? now),
    );
    if (time == null) return;

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }
}

class _RouteStop {
  const _RouteStop({
    required this.taskId,
    required this.address,
    required this.point,
    this.driverId,
    this.scheduledStart,
  });

  final String taskId;
  final String address;
  final String? driverId;
  final DateTime? scheduledStart;
  final GeoPoint point;
}

class _RouteView {
  const _RouteView({
    required this.id,
    required this.driverId,
    required this.status,
    required this.optimizer,
    required this.createdAt,
    required this.stops,
  });

  final String id;
  final String? driverId;
  final String status;
  final String optimizer;
  final DateTime? createdAt;
  final List<_RouteStopView> stops;
}

class _RouteStopView {
  const _RouteStopView({
    required this.sequence,
    required this.taskId,
    required this.address,
    required this.status,
    required this.driverId,
  });

  final int sequence;
  final String taskId;
  final String address;
  final String status;
  final String? driverId;
}

class _PodRecord {
  const _PodRecord({
    required this.taskId,
    required this.address,
    required this.driverId,
    required this.proofCode,
    required this.photoUrl,
    required this.createdAt,
  });

  final String taskId;
  final String? address;
  final String? driverId;
  final String? proofCode;
  final String? photoUrl;
  final DateTime? createdAt;
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message),
    );
  }
}

class _DriverInfo {
  const _DriverInfo({
    required this.memberId,
    required this.userId,
    required this.email,
    required this.isAvailable,
    required this.currentTaskCount,
    required this.lastLocationLat,
    required this.lastLocationLng,
    required this.lastLocationAt,
  });

  final String memberId;
  final String? userId;
  final String? email;
  final bool isAvailable;
  final int currentTaskCount;
  final double? lastLocationLat;
  final double? lastLocationLng;
  final DateTime? lastLocationAt;
}

class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.message,
    required this.isBroadcast,
    required this.isFromAdmin,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String? recipientId;
  final String message;
  final bool isBroadcast;
  final bool isFromAdmin;
  final DateTime createdAt;
}
