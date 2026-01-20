import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/driver_profile.dart';

class DriverProfileService {
  DriverProfileService(this._client);

  final SupabaseClient _client;

  Future<DriverProfile?> fetchCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    final row = await _client
        .from('company_members')
        .select('id, company_id, role, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return DriverProfile(
      driverId: row['id']?.toString() ?? '',
      companyId: row['company_id']?.toString() ?? '',
      role: row['role']?.toString() ?? '',
    );
  }
}
