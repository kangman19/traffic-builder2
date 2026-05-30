/// Centralised build-time configuration for Traffic Builder.
///
/// Values are injected at compile time via --dart-define:
///   flutter run \
///     --dart-define=BACKEND_BASE_URL=http://192.168.1.50:3001/api \
///     --dart-define=BACKEND_SOCKET_URL=http://192.168.1.50:3001
///
/// Defaults work out-of-the-box for the Android emulator (10.0.2.2 is the
/// emulator's loopback alias for the host machine's localhost).
///
/// No secrets live here. The Google Maps API key belongs exclusively in
/// server/.env — it never touches the Flutter app.
class AppConfig {
  AppConfig._();

  // ── Nominatim geocoding ───────────────────────────────────────────────────

  static const String nominatimSearchEndpoint = String.fromEnvironment(
    'NOMINATIM_SEARCH_ENDPOINT',
    defaultValue: 'https://nominatim.openstreetmap.org',
  );

  // ── OpenStreetMap tiles ───────────────────────────────────────────────────

  static const String openStreetMapTileEndpoint = String.fromEnvironment(
    'OPEN_STREET_MAP_TILE_ENDPOINT',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  // ── Backend server ────────────────────────────────────────────────────────

  /// HTTP base URL for the Express API.
  /// Default: Android emulator → host machine localhost:3001.
  /// Real device: pass --dart-define=BACKEND_BASE_URL=http://192.168.1.x:3001/api
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://10.0.2.2:3001/api',
  );

  /// Socket.io base URL (no /api suffix).
  static const String backendSocketUrl = String.fromEnvironment(
    'BACKEND_SOCKET_URL',
    defaultValue: 'http://10.0.2.2:3001',
  );
}
