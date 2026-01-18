import 'dart:convert';

import 'package:http/http.dart' as http;

class GeoPoint {
  const GeoPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

class MapboxService {
  MapboxService(
    this.accessToken, {
    this.countryCode,
    this.proximity,
  }) : _client = http.Client();

  final String accessToken;
  final String? countryCode;
  final GeoPoint? proximity;
  final http.Client _client;

  Future<GeoPoint?> forwardGeocode(String query) async {
    if (query.trim().isEmpty || accessToken.isEmpty) {
      return null;
    }

    final encoded = Uri.encodeComponent(query);
    final buffer = StringBuffer(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json?limit=1',
    );

    if (countryCode != null && countryCode!.isNotEmpty) {
      buffer.write('&country=${countryCode!.toLowerCase()}');
    }

    if (proximity != null) {
      buffer.write('&proximity=${proximity!.lng},${proximity!.lat}');
    }

    buffer.write('&access_token=$accessToken');

    final uri = Uri.parse(buffer.toString());

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = body['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      return null;
    }

    final first = features.first as Map<String, dynamic>;
    final center = first['center'] as List<dynamic>?;
    if (center == null || center.length < 2) {
      return null;
    }

    final lng = (center[0] as num).toDouble();
    final lat = (center[1] as num).toDouble();
    return GeoPoint(lat: lat, lng: lng);
  }

  String staticMapUrl(GeoPoint point) {
    // Simple static map with a pin at the task location.
    final marker = 'pin-s-l+285A98(${point.lng},${point.lat})';
    final center = '${point.lng},${point.lat},14';
    return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/$marker/$center/600x320@2x?access_token=$accessToken';
  }

  void dispose() {
    _client.close();
  }
}
