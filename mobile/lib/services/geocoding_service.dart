import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/network/api_error.dart';
import '../models/location.dart';

// ── Result type ────────────────────────────────────────────────────────────

class GeocodingResult {
  final String displayName;
  final AppLocation location;

  const GeocodingResult({required this.displayName, required this.location});

  factory GeocodingResult.fromNominatimJson(Map<String, dynamic> json) {
    final latStr = json['lat'] as String?;
    final lonStr = json['lon'] as String?;
    final display = json['display_name'] as String?;

    if (latStr == null || lonStr == null || display == null) {
      throw FormatException('Nominatim result missing lat/lon/display_name: $json');
    }

    return GeocodingResult(
      displayName: display,
      location: AppLocation(lat: double.parse(latStr), long: double.parse(lonStr)),
    );
  }

  /// First three comma-separated address components — readable but compact.
  String get shortName => displayName.split(',').take(3).join(', ');
}

// ── Service ────────────────────────────────────────────────────────────────

/// Calls Nominatim directly from the device — no server dependency.
/// Works before monitoring is started, and requires no API key.
class GeocodingService {
  static const String _tag = 'GeocodingService';

  Future<({List<GeocodingResult> results, ApiError? error})> searchPlaces(
      String query) async {
    if (query.trim().isEmpty) return (results: <GeocodingResult>[], error: null);

    try {
      final response = await ApiClient.nominatim.get(
        '/search',
        queryParameters: {
          'format': 'json',
          'q': query.trim(),
          'limit': 5,
        },
      );

      final raw = response.data as List<dynamic>;
      final results = raw
          .map((e) =>
              GeocodingResult.fromNominatimJson(e as Map<String, dynamic>))
          .toList();

      debugPrint('[$_tag] "${query.trim()}" → ${results.length} results');
      return (results: results, error: null);
    } on DioException catch (e) {
      final err = NetworkError(
        detail: '[$_tag] ${e.message ?? "network error"}',
        statusCode: e.response?.statusCode,
      );
      debugPrint(err.logMessage);
      return (results: <GeocodingResult>[], error: err);
    } on FormatException catch (e) {
      final err = ParseError(field: 'nominatim_result', detail: e.message);
      debugPrint(err.logMessage);
      return (results: <GeocodingResult>[], error: err);
    }
  }
}
