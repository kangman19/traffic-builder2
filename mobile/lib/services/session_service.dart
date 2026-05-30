import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/network/api_error.dart';
import '../models/location.dart';
import '../models/monitoring_session.dart';
import '../models/traffic_condition.dart';

/// All HTTP calls that touch monitoring session state on the backend.
///
/// Every method returns a record containing either a result or an [ApiError].
/// The caller decides what to do on failure — this service never swallows errors.
class SessionService {
  static const String _tag = 'SessionService';

  Future<({MonitoringSession? session, ApiError? error})> createSession({
    required String userId,
    required AppLocation homeLocation,
    required AppLocation currentLocation,
    int frequencyMinutes = 10,
  }) async {
    try {
      final response = await ApiClient.backend.post('/session', data: {
        'userId': userId,
        'homeLocation': homeLocation.toJson(),
        'currentLocation': currentLocation.toJson(),
        'frequency': frequencyMinutes,
      });
      return (
        session: MonitoringSession.fromJson(response.data as Map<String, dynamic>),
        error: null,
      );
    } on DioException catch (e) {
      final err = _mapDioError(e, 'createSession');
      debugPrint(err.logMessage);
      return (session: null, error: err);
    }
  }

  Future<({MonitoringSession? session, ApiError? error})> getSession(
      String userId) async {
    try {
      final response = await ApiClient.backend.get('/session/$userId');
      return (
        session: MonitoringSession.fromJson(response.data as Map<String, dynamic>),
        error: null,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return (session: null, error: SessionNotFoundError(userId));
      }
      final err = _mapDioError(e, 'getSession');
      debugPrint(err.logMessage);
      return (session: null, error: err);
    }
  }

  Future<ApiError?> updateLocation(String userId, AppLocation location) async {
    try {
      await ApiClient.backend
          .put('/session/$userId/location', data: location.toJson());
      return null;
    } on DioException catch (e) {
      final err = _mapDioError(e, 'updateLocation');
      debugPrint(err.logMessage);
      return err;
    }
  }

  Future<({TrafficCondition? condition, ApiError? error})> getTraffic(
      String userId) async {
    try {
      final response = await ApiClient.backend.get('/traffic/$userId');
      return (
        condition: TrafficCondition.fromJson(response.data as Map<String, dynamic>),
        error: null,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // No data yet — not an error, just no first tick yet.
        return (condition: null, error: null);
      }
      final err = _mapDioError(e, 'getTraffic');
      debugPrint(err.logMessage);
      return (condition: null, error: err);
    }
  }

  Future<ApiError?> stopSession(String userId) async {
    try {
      await ApiClient.backend.delete('/session/$userId');
      return null;
    } on DioException catch (e) {
      final err = _mapDioError(e, 'stopSession');
      debugPrint(err.logMessage);
      return err;
    }
  }

  Future<ApiError?> updateSettings(
    String userId, {
    AppLocation? homeLocation,
    int? notificationFrequencyMinutes,
  }) async {
    final body = <String, dynamic>{};
    if (homeLocation != null) body['homeLocation'] = homeLocation.toJson();
    if (notificationFrequencyMinutes != null) {
      body['notificationFrequencyMinutes'] = notificationFrequencyMinutes;
    }
    if (body.isEmpty) return null;

    try {
      await ApiClient.backend.put('/session/$userId/settings', data: body);
      return null;
    } on DioException catch (e) {
      final err = _mapDioError(e, 'updateSettings');
      debugPrint(err.logMessage);
      return err;
    }
  }

  // ── Error mapping ──────────────────────────────────────────────────────

  ApiError _mapDioError(DioException e, String method) {
    final status = e.response?.statusCode;
    if (status == 429) return QuotaExceededError('$_tag.$method');
    return NetworkError(
      detail: '[$_tag.$method] ${e.message ?? "unknown"}',
      statusCode: status,
    );
  }
}
