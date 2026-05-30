/// Typed error hierarchy for all network calls in Traffic Builder.
///
/// Using a sealed class means every callsite is forced to handle every
/// error variant — no silent swallows of unknown error states.
sealed class ApiError {
  const ApiError();

  /// Whether this error requires human intervention (key config) vs
  /// being transient (network flap, parsing issue).
  bool get isFatal;

  /// Short label suitable for Logcat filtering.
  String get logTag;

  /// Full message for debugPrint output.
  String get logMessage;
}

// ── Concrete variants ──────────────────────────────────────────────────────

final class MissingApiKeyError extends ApiError {
  final String service;
  const MissingApiKeyError(this.service);

  @override
  bool get isFatal => true;

  @override
  String get logTag => 'MissingApiKey';

  @override
  String get logMessage => '[ApiError:$logTag] API key not configured for $service';
}

final class AuthDeniedError extends ApiError {
  final String service;
  final String detail;
  const AuthDeniedError({required this.service, required this.detail});

  @override
  bool get isFatal => true;

  @override
  String get logTag => 'AuthDenied';

  @override
  String get logMessage =>
      '[ApiError:$logTag] $service rejected key — $detail';
}

final class QuotaExceededError extends ApiError {
  final String service;
  const QuotaExceededError(this.service);

  @override
  bool get isFatal => true;

  @override
  String get logTag => 'QuotaExceeded';

  @override
  String get logMessage => '[ApiError:$logTag] Quota exceeded for $service';
}

final class NetworkError extends ApiError {
  final String detail;
  final int? statusCode;
  const NetworkError({required this.detail, this.statusCode});

  @override
  bool get isFatal => false;

  @override
  String get logTag => 'NetworkError';

  @override
  String get logMessage =>
      '[ApiError:$logTag] ${statusCode != null ? "HTTP $statusCode — " : ""}$detail';
}

final class ParseError extends ApiError {
  final String field;
  final String detail;
  const ParseError({required this.field, required this.detail});

  @override
  bool get isFatal => false;

  @override
  String get logTag => 'ParseError';

  @override
  String get logMessage => '[ApiError:$logTag] Failed to parse "$field" — $detail';
}

final class SessionNotFoundError extends ApiError {
  final String userId;
  const SessionNotFoundError(this.userId);

  @override
  bool get isFatal => false;

  @override
  String get logTag => 'SessionNotFound';

  @override
  String get logMessage => '[ApiError:$logTag] No active session for user $userId';
}
