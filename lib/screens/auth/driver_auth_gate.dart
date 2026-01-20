import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../bootstrap/app_bootstrap.dart';
import '../../models/driver_profile.dart';
import '../../services/driver_profile_service.dart';
import '../../viewmodels/task_view_model.dart';
import '../task_list/task_list_screen.dart';
import 'driver_login_screen.dart';

class DriverAuthGate extends StatefulWidget {
  const DriverAuthGate({required this.bootstrap, super.key});

  final AppBootstrap bootstrap;

  @override
  State<DriverAuthGate> createState() => _DriverAuthGateState();
}

class _DriverAuthGateState extends State<DriverAuthGate> {
  late final DriverProfileService _profileService =
      DriverProfileService(Supabase.instance.client);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const DriverLoginScreen();
        }

        return FutureBuilder<DriverProfile?>(
          future: _profileService.fetchCurrentProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = profileSnapshot.data;
            if (profile == null || profile.companyId.isEmpty) {
              return _buildBlocked('No company membership found.');
            }

            if (!profile.isDriver) {
              return _buildBlocked('Account is not a driver role.');
            }

            return MultiProvider(
              providers: [
                Provider<DriverProfile>.value(value: profile),
                ChangeNotifierProvider<TaskViewModel>(
                  create: (_) => widget.bootstrap.createTaskViewModelForDriver(
                    companyId: profile.companyId,
                    driverId: profile.driverId,
                  ),
                ),
              ],
              child: const TaskListScreen(),
            );
          },
        );
      },
    );
  }

  Widget _buildBlocked(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('Access blocked')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
