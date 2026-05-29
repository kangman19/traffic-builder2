import 'package:dio/dio.dart';
import '../models/location.dart';
import '../models/monitoring_session.dart';
import '../models/traffic_condition.dart';

// On Android emulator use 10.0.2.2; swap to your LAN IP for a real device.
const String kBaseUrl = 'http://10.0.2.2:3001/api';

class PlaceResult {
  final String displayName;
  final double lat;
  final double lon;

  const PlaceResult({required this.displayName, required this.lat, required this.lon});

  factory PlaceResult.fromJson(Map<String, dynamic> json) => PlaceResult(
        displayName: json['display_name'] as String,
        lat: double.parse(json['lat'] as String),
        lon: double.parse(json['lon'] as String),
      );
}

class ApiService {
  final Dio _dio = Dio(BaseOptions(baseUrl: kBaseUrl, connectTimeout: const Duration(seconds: 10)));

  Future<bool> checkHealth() async {
    try {
      final res = await _dio.get('/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<MonitoringSession> createSession({
    required String userId,
    required AppLocation homeLocation,
    required AppLocation currentLocation,
    int threshold = 20,
    int frequency = 10,
  }) async {
    final res = await _dio.post('/session', data: {
      'userId': userId,
      'homeLocation': homeLocation.toJson(),
      'currentLocation': currentLocation.toJson(),
      'threshold': threshold,
      'frequency': frequency,
    });
    return MonitoringSession.fromJson(res.data as Map<String, dynamic>);
  }

  Future<MonitoringSession?> getSession(String userId) async {
    try {
      final res = await _dio.get('/session/$userId');
      return MonitoringSession.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> updateLocation(String userId, AppLocation location) async {
    await _dio.put('/session/$userId/location', data: location.toJson());
  }

  Future<TrafficCondition?> getTraffic(String userId) async {
    try {
      final res = await _dio.get('/traffic/$userId');
      return TrafficCondition.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> stopSession(String userId) async {
    await _dio.delete('/session/$userId');
  }

  Future<void> updateSettings(
    String userId, {
    AppLocation? homeLocation,
    int? notificationThreshold,
    int? notificationFrequencyMinutes,
  }) async {
    await _dio.put('/session/$userId/settings', data: {
      'homeLocation': homeLocation?.toJson(),
      'notificationThreshold': notificationThreshold,
      'notificationFrequencyMinutes': notificationFrequencyMinutes,
    }..removeWhere((_, v) => v == null));
  }

  Future<List<PlaceResult>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final res = await _dio.get('/places/search', queryParameters: {'q': query});
      final list = res.data as List<dynamic>;
      return list.map((e) => PlaceResult.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
