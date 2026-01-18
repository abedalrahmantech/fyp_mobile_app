class AppConfig {
  AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.companyId,
    required this.driverId,
    required this.mapboxAccessToken,
    required this.mapboxCountryCode,
    required this.mapboxProximityLat,
    required this.mapboxProximityLng,
    required this.telemetryEndpoint,
    required this.dispatchPortalUrl,
    required this.environment,
    required this.logLevel,
    this.restApiBaseUrl,
  });

  factory AppConfig.fromEnv() {
    return AppConfig(
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      companyId: const String.fromEnvironment(
        'ORDERVISTA_COMPANY_ID',
        defaultValue: '',
      ),
      driverId: const String.fromEnvironment(
        'ORDERVISTA_DRIVER_ID',
        defaultValue: '',
      ),
      mapboxAccessToken: const String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
      mapboxCountryCode: const String.fromEnvironment(
        'MAPBOX_COUNTRY_CODE',
        defaultValue: 'hk',
      ),
      mapboxProximityLat: _parseDouble(
        const String.fromEnvironment('MAPBOX_PROXIMITY_LAT',
            defaultValue: '22.3375'),
        fallback: 22.3375,
      ),
      mapboxProximityLng: _parseDouble(
        const String.fromEnvironment('MAPBOX_PROXIMITY_LNG',
            defaultValue: '114.1750'),
        fallback: 114.1750,
      ),
      telemetryEndpoint: const String.fromEnvironment(
        'ORDERVISTA_TELEMETRY_ENDPOINT',
        defaultValue: '',
      ),
      dispatchPortalUrl: const String.fromEnvironment(
        'ORDERVISTA_DISPATCH_PORTAL_URL',
        defaultValue: '',
      ),
      environment: const String.fromEnvironment(
        'ORDERVISTA_ENV',
        defaultValue: 'development',
      ),
      logLevel: const String.fromEnvironment(
        'ORDERVISTA_LOG_LEVEL',
        defaultValue: 'info',
      ),
      restApiBaseUrl: const String.fromEnvironment(
        'ORDERVISTA_API_BASE_URL',
        defaultValue: 'http://localhost:3000',
      ),
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String companyId;
  final String driverId;
  final String mapboxAccessToken;
  final String mapboxCountryCode;
  final double mapboxProximityLat;
  final double mapboxProximityLng;
  final String telemetryEndpoint;
  final String dispatchPortalUrl;
  final String environment;
  final String logLevel;
  final String? restApiBaseUrl;

  bool get isProduction => environment.toLowerCase() == 'production';

  AppConfig copyWith({
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? companyId,
    String? driverId,
    String? mapboxAccessToken,
    String? mapboxCountryCode,
    double? mapboxProximityLat,
    double? mapboxProximityLng,
    String? telemetryEndpoint,
    String? dispatchPortalUrl,
    String? environment,
    String? logLevel,
    String? restApiBaseUrl,
  }) {
    return AppConfig(
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
      companyId: companyId ?? this.companyId,
      driverId: driverId ?? this.driverId,
      mapboxAccessToken: mapboxAccessToken ?? this.mapboxAccessToken,
      mapboxCountryCode: mapboxCountryCode ?? this.mapboxCountryCode,
      mapboxProximityLat: mapboxProximityLat ?? this.mapboxProximityLat,
      mapboxProximityLng: mapboxProximityLng ?? this.mapboxProximityLng,
      telemetryEndpoint: telemetryEndpoint ?? this.telemetryEndpoint,
      dispatchPortalUrl: dispatchPortalUrl ?? this.dispatchPortalUrl,
      environment: environment ?? this.environment,
      logLevel: logLevel ?? this.logLevel,
      restApiBaseUrl: restApiBaseUrl ?? this.restApiBaseUrl,
    );
  }
}

double _parseDouble(String input, {required double fallback}) {
  final parsed = double.tryParse(input);
  return parsed ?? fallback;
}
