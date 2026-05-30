import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/network/api_error.dart';
import '../models/location.dart';
import '../models/traffic_condition.dart';

// ── Result types ───────────────────────────────────────────────────────────

/// Route data returned from a successful Directions API call.
class DirectionsRouteData {
  /// Normal travel time in seconds (no traffic).
  final int durationSeconds;

  /// Travel time with current traffic in seconds.
  final int durationInTrafficSeconds;

  /// Route distance in metres.
  final int distanceMetres;

  /// Calculated traffic status based on the congestion multiplier.
  final TrafficStatus status;

  /// Encoded polyline string (Google format) for drawing the real road path.
  /// Null when the response omits overview_polyline.
  final String? encodedPolyline;

  final DateTime timestamp;
  final DateTime eta;

  const DirectionsRouteData({
    required this.durationSeconds,
    required this.durationInTrafficSeconds,
    required this.distanceMetres,
    required this.status,
    required this.encodedPolyline,
    required this.timestamp,
    required this.eta,
  });

  String get etaFormatted => '${(durationInTrafficSeconds / 60).round()} mins';
  String get normalFormatted => '${(durationSeconds / 60).round()} mins';
  String get delayFormatted {
    final delaySec = durationInTrafficSeconds - durationSeconds;
    return delaySec <= 0 ? 'On time' : '+${(delaySec / 60).round()} mins';
  }
}

// ── Service ────────────────────────────────────────────────────────────────

/// Client-side Google Directions API integration.
///
/// The backend server handles ETA monitoring independently (see server/src/directionsService.ts).
/// This service is reserved for future client-side queries only — e.g. fetching the real
/// road polyline to draw on the map instead of a straight line.
///
/// SECURITY NOTE: The API key must NOT come from the bundled .env file. APK contents
/// are readable by anyone with apktool. When this service is activated, supply the key
/// via a server-side proxy, Android Keystore, or Firebase Remote Config — never hardcoded
/// or bundled. The key field below is intentionally left as a constructor parameter so
/// the caller controls the source.
///
/// Returns a typed record so the caller always handles both success and error branches.
class DirectionsService {
  static const String _tag = 'DirectionsService';
  static const String _directionsPath = '/maps/api/directions/json';

  /// [apiKey] must be injected by the caller from a secure source.
  /// Pass an empty string to get a [MissingApiKeyError] immediately.
  final String apiKey;

  const DirectionsService({required this.apiKey});

  Future<({DirectionsRouteData? data, ApiError? error})> fetchRoute({
    required AppLocation origin,
    required AppLocation destination,
  }) async {
    if (apiKey.trim().isEmpty) {
      debugPrint('[$_tag] apiKey is empty — skipping fetch');
      return (
        data: null,
        error: const MissingApiKeyError('Google Maps Directions'),
      );
    }

    try {
      final response = await ApiClient.googleMaps.get(
        _directionsPath,
        queryParameters: {
          'origin': '${origin.lat},${origin.long}',
          'destination': '${destination.lat},${destination.long}',
          'departure_time': 'now',
          'traffic_model': 'best_guess',
          'key': apiKey,
        },
      );

      return _parseResponse(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        final err = QuotaExceededError(_tag);
        debugPrint(err.logMessage);
        return (data: null, error: err);
      }
      final err = NetworkError(
        detail: '$_tag — ${e.message ?? "unknown"}',
        statusCode: e.response?.statusCode,
      );
      debugPrint(err.logMessage);
      return (data: null, error: err);
    } catch (e) {
      final err = NetworkError(detail: '$_tag — $e');
      debugPrint(err.logMessage);
      return (data: null, error: err);
    }
  }

  // ── Response parsing ─────────────────────────────────────────────────────

  ({DirectionsRouteData? data, ApiError? error}) _parseResponse(
      Map<String, dynamic> body) {
    final apiStatus = body['status'] as String?;

    if (apiStatus == 'REQUEST_DENIED') {
      final detail = body['error_message'] as String? ?? 'REQUEST_DENIED';
      final err = AuthDeniedError(service: _tag, detail: detail);
      debugPrint(err.logMessage);
      return (data: null, error: err);
    }

    if (apiStatus == 'OVER_DAILY_LIMIT' || apiStatus == 'OVER_QUERY_LIMIT') {
      final err = QuotaExceededError(_tag);
      debugPrint(err.logMessage);
      return (data: null, error: err);
    }

    if (apiStatus != 'OK') {
      final err = ParseError(field: 'status', detail: 'Unexpected: $apiStatus');
      debugPrint(err.logMessage);
      return (data: null, error: err);
    }

    final routes = body['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      return (
        data: null,
        error: ParseError(field: 'routes', detail: 'Array is empty or missing'),
      );
    }

    final firstRoute = routes.first as Map<String, dynamic>;
    final legs = firstRoute['legs'] as List<dynamic>?;
    if (legs == null || legs.isEmpty) {
      return (
        data: null,
        error: ParseError(field: 'routes[0].legs', detail: 'Array is empty or missing'),
      );
    }

    final leg = legs.first as Map<String, dynamic>;

    final durationSec = _extractInt(leg, 'duration.value');
    final durationInTrafficSec =
        _extractInt(leg, 'duration_in_traffic.value') ?? durationSec;
    final distanceM = _extractInt(leg, 'distance.value');

    if (durationSec == null || distanceM == null) {
      return (
        data: null,
        error: ParseError(
          field: 'leg.duration / leg.distance',
          detail:
              'duration=$durationSec, durationInTraffic=$durationInTrafficSec, distance=$distanceM',
        ),
      );
    }

    final polyline =
        (firstRoute['overview_polyline'] as Map<String, dynamic>?)?['points']
            as String?;

    final multiplier = durationInTrafficSec! / durationSec;
    final now = DateTime.now();

    debugPrint(
      '[$_tag] Route fetched — '
      '${(durationInTrafficSec / 60).round()} min in traffic, '
      '${(distanceM / 1000).toStringAsFixed(1)} km, '
      'status=${_statusFromMultiplier(multiplier).name}'
    );

    return (
      data: DirectionsRouteData(
        durationSeconds: durationSec,
        durationInTrafficSeconds: durationInTrafficSec,
        distanceMetres: distanceM,
        status: _statusFromMultiplier(multiplier),
        encodedPolyline: polyline,
        timestamp: now,
        eta: now.add(Duration(seconds: durationInTrafficSec)),
      ),
      error: null,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  int? _extractInt(Map<String, dynamic> map, String dotPath) {
    final parts = dotPath.split('.');
    dynamic current = map;
    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else {
        return null;
      }
    }
    return (current as num?)?.toInt();
  }

  TrafficStatus _statusFromMultiplier(double multiplier) {
    if (multiplier < 1.3) return TrafficStatus.calm;
    if (multiplier <= 1.8) return TrafficStatus.bookey;
    return TrafficStatus.ggs;
  }
}
