import 'package:dio/dio.dart';
import '../config/app_config.dart';

/// Three isolated Dio instances — one per external system.
///
/// Call [ApiClient.init] once in [main] after [AppConfig.load].
/// Each client has its own timeout, base URL, and headers so changes
/// to one endpoint never silently affect another.
class ApiClient {
  ApiClient._();

  static late final Dio _backend;
  static late final Dio _nominatim;
  static late final Dio _googleMaps;

  static void init() {
    _backend = Dio(
      BaseOptions(
        baseUrl: AppConfig.backendBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
      ),
    );

    _nominatim = Dio(
      BaseOptions(
        baseUrl: AppConfig.nominatimSearchEndpoint,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: const {
          'User-Agent': 'TrafficBuilder/2.0',
          'Accept': 'application/json',
        },
      ),
    );

    _googleMaps = Dio(
      BaseOptions(
        baseUrl: 'https://maps.googleapis.com',
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );
  }

  /// Backend Express + Socket.io server.
  static Dio get backend => _backend;

  /// Nominatim OpenStreetMap geocoding API.
  static Dio get nominatim => _nominatim;

  /// Google Maps APIs (Directions, etc.).
  static Dio get googleMaps => _googleMaps;
}
