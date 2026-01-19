import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';

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
  final _statusOptions = const ['pending', 'in-transit', 'delivered'];

  DateTime? _scheduledAt;
  String _status = 'pending';
  bool _loading = false;
  String? _error;
  String? _role;
  List<Map<String, dynamic>> _tasks = const [];

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
