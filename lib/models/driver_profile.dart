class DriverProfile {
  const DriverProfile({
    required this.companyId,
    required this.driverId,
    required this.role,
  });

  final String companyId;
  final String driverId;
  final String role;

  bool get isDriver => role == 'driver';
}
