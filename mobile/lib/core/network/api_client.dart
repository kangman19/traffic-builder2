import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class ApiClient {
  ApiClient._();

  static late final Dio _backend;
  static late final Dio _nominatim;
  static late final Dio _googleMaps;

  static void init() {
    // IMPORTANT: baseUrl MUST end with '/' so that Dart's Uri.resolve treats
    // relative paths (e.g. 'session') as children, not siblings.
    // Without the trailing slash, '/session' is an absolute host-relative path
    // and Uri.resolve strips the '/api' segment entirely:
    //   'http://10.0.2.2:3001/api'  + '/session' → http://10.0.2.2:3001/session  ✗
    //   'http://10.0.2.2:3001/api/' +  'session'  → http://10.0.2.2:3001/api/session ✓
    final backendBase = _trailingSlash(AppConfig.backendBaseUrl);

    debugPrint('[ApiClient] Backend base URL: $backendBase');

    _backend = Dio(
      BaseOptions(
        baseUrl: backendBase,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
      ),
    );

    // Log every request and response so failures are visible in logcat
    // without needing a proxy tool.
    _backend.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: false,
        responseHeader: false,
        error: true,
        logPrint: (obj) => debugPrint('[Backend] $obj'),
      ),
    );

    _nominatim = Dio(
      BaseOptions(
        baseUrl: _trailingSlash(AppConfig.nominatimSearchEndpoint),
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
        baseUrl: 'https://maps.googleapis.com/',
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );
  }

  static String _trailingSlash(String url) =>
      url.endsWith('/') ? url : '$url/';

  static Dio get backend   => _backend;
  static Dio get nominatim => _nominatim;
  static Dio get googleMaps => _googleMaps;
}
