import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
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

      final profile = await _client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      _role = profile?['role']?.toString();
      if (_role != 'admin') {
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

  Future<void> _createTask() async {
    final config = context.read<AppConfig>();
    final address = _addressController.text.trim();
    final driverId = _driverController.text.trim();

    if (address.isEmpty || driverId.isEmpty) {
      setState(() => _error = 'Address and driver ID are required.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
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

  @override
  Widget build(BuildContext context) {
    final session = _client.auth.currentSession;
    final user = _client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OrderVista Admin'),
        actions: [
          if (session != null)
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _loadRoleAndTasks,
              icon: const Icon(Icons.refresh),
            ),
          if (session != null)
            TextButton(
              onPressed: _signOut,
              child: const Text('Sign out'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  _InlineMessage(
                    message: _error!,
                    color: Colors.orange.shade100,
                  ),
                if (session == null) _buildSignInCard(),
                if (session != null && _role == null)
                  _InlineMessage(
                    message:
                        'No profile found for ${user?.email ?? 'user'}. Run the SQL setup for profiles/roles.',
                    color: Colors.orange.shade100,
                  ),
                if (session != null && _role != null && _role != 'admin')
                  _InlineMessage(
                    message:
                        'Signed in as ${user?.email}. Role=$_role. Admin access required.',
                    color: Colors.red.shade100,
                  ),
                if (session != null && _role == 'admin') ...[
                  _buildTaskForm(),
                  const SizedBox(height: 24),
                  _buildTaskList(),
                  const SizedBox(height: 24),
                  _buildCsvImport(),
                  const SizedBox(height: 24),
                  _buildRouteSequencer(),
                  const SizedBox(height: 24),
                  _buildRouteOverview(),
                  const SizedBox(height: 24),
                  _buildProofReview(),
                ],
              ],
            ),
    );
  }

  Widget _buildSignInCard() {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Sign In',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _signIn,
              icon: const Icon(Icons.login),
              label: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Task',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: '1 Harbourfront Horizon, Kowloon Bay',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _driverController,
              decoration: const InputDecoration(
                labelText: 'Driver ID (UUID)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status,
              items: _statusOptions
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _status = value ?? 'pending'),
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            const SizedBox(height: 12),
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
            ElevatedButton.icon(
              onPressed: _loading ? null : _createTask,
              icon: const Icon(Icons.add),
              label: const Text('Create task'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList() {
    if (_tasks.isEmpty) {
      return const Text('No tasks found.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Tasks',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ..._tasks.map(
          (task) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(task['address']?.toString() ?? 'Unknown address'),
            subtitle: Text(
              'Driver: ${task['driver_id'] ?? '-'} • Status: ${task['status'] ?? '-'}',
            ),
            trailing: Text(
              task['scheduled_start'] != null
                  ? DateFormat('MMM d • HH:mm')
                      .format(DateTime.parse(task['scheduled_start']).toLocal())
                  : 'Unscheduled',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCsvImport() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CSV Import (Dispatcher)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload a CSV with columns: address, driver_id (optional), status (optional), scheduled_start (optional), lat, lng (optional).',
            ),
            const SizedBox(height: 12),
            if (_csvMessage != null)
              _InlineMessage(
                message: _csvMessage!,
                color: Colors.blue.shade50,
              ),
            ElevatedButton.icon(
              onPressed: _csvLoading ? null : _pickCsvAndImport,
              icon: _csvLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: const Text('Upload CSV'),
            ),
          ],
        ),
      ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Baseline Route Sequencer (Nearest-Next)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Generates a simple route order for pending tasks and persists it to routes + route_tasks.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _routeDriverController,
              decoration: const InputDecoration(
                labelText: 'Driver ID filter (optional)',
                hintText: 'UUID to sequence only that driver’s tasks',
              ),
            ),
            const SizedBox(height: 12),
            if (_routeMessage != null)
              _InlineMessage(
                message: _routeMessage!,
                color: Colors.blue.shade50,
              ),
            ElevatedButton.icon(
              onPressed: _routeLoading ? null : _generateBaselineRoute,
              icon: _routeLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.alt_route),
              label: const Text('Generate baseline route'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Routes & Stop Order',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh routes',
                  onPressed: _routesLoading ? null : _refreshRoutes,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_routesMessage != null)
              _InlineMessage(
                message: _routesMessage!,
                color: Colors.blue.shade50,
              ),
            if (_routesLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_routes.isEmpty)
              const Text('No routes found yet.')
            else
              ..._routes.map(_buildRouteCard),
          ],
        ),
      ),
    );
  }

  Widget _buildProofReview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Proof of Delivery Review',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh PoD',
                  onPressed: _podLoading ? null : _refreshPod,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_podMessage != null)
              _InlineMessage(
                message: _podMessage!,
                color: Colors.blue.shade50,
              ),
            if (_podLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_podRecords.isEmpty)
              const Text('No proof records found yet.')
            else
              ..._podRecords.map(_buildPodCard),
          ],
        ),
      ),
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
              labelText: 'Driver ID (UUID)',
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

      final routeInsert = await _client
          .from('routes')
          .insert({
            'company_id': config.companyId,
            'driver_id':
                driverFilter.isNotEmpty ? driverFilter : ordered.first.driverId,
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
