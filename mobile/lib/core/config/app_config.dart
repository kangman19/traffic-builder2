/// Centralised build-time configuration for Traffic Builder.
///
/// Values are injected at compile time via --dart-define:
///
///   # Default: production Render server
///   flutter run
///
///   # Web / iOS Simulator / Desktop (local dev):
///   flutter run --dart-define=BACKEND_BASE_URL=http://localhost:3001/api \
///               --dart-define=BACKEND_SOCKET_URL=http://localhost:3001
///
///   # Android emulator (emulator loopback to host machine):
///   flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:3001/api \
///               --dart-define=BACKEND_SOCKET_URL=http://10.0.2.2:3001
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
    defaultValue: 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
  );

  // ── Backend server ────────────────────────────────────────────────────────

  /// HTTP base URL for the Express API.
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://traffic-builder2.onrender.com/api',
  );

  /// Socket.io base URL (no /api suffix).
  static const String backendSocketUrl = String.fromEnvironment(
    'BACKEND_SOCKET_URL',
    defaultValue: 'https://traffic-builder2.onrender.com',
  );
}
