import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../core/config/app_config.dart';
import '../core/network/api_error.dart';
import '../models/location.dart';
import '../models/traffic_condition.dart';
import '../models/traffic_update.dart';
import '../services/session_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/address_search.dart';
import '../widgets/frequency_selector.dart';
import '../widgets/traffic_status_card.dart';
import '../widgets/traffic_map.dart';
import '../widgets/notifications_list.dart';

const String kUserId = 'user123';
const List<int> kFrequencyOptions = [5, 10, 20];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _sessionSvc  = SessionService();
  final _locationSvc = LocationService();

  AppLocation?      _currentLocation;
  AppLocation?      _homeLocation;
  TrafficCondition? _latestCondition;
  bool _monitoring   = false;
  bool _connecting   = false;
  bool _bgConnected  = false;
  int  _frequencyMinutes = 5;

  final List<NotificationEntry> _notifications = [];

  // Subscriptions to background service IPC streams.
  StreamSubscription<Map<String, dynamic>?>? _updateSub;
  StreamSubscription<Map<String, dynamic>?>? _statusSub;

  @override
  void initState() {
    super.initState();
    _detectLocation();
    _stopStaleService();
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _detectLocation() async {
    final loc = await _locationSvc.getCurrentLocation();
    if (mounted) setState(() => _currentLocation = loc);
  }

  // If the service was left running from a previous session (e.g. app killed
  // while monitoring), stop it so the UI starts in a clean state.
  Future<void> _stopStaleService() async {
    if (await FlutterBackgroundService().isRunning()) {
      FlutterBackgroundService().invoke('stop');
    }
  }

  // ── Session lifecycle ─────────────────────────────────────────────────────

  Future<void> _startMonitoring() async {
    if (_currentLocation == null) {
      _showError('GPS unavailable. Enable location and try again.');
      return;
    }
    if (_homeLocation == null) {
      _showError('Set your home location first.');
      return;
    }

    setState(() => _connecting = true);

    debugPrint('[Dashboard] Starting monitoring — target: ${AppConfig.backendBaseUrl}');
    final serverReachable = await _sessionSvc.checkHealth();
    if (!serverReachable) {
      setState(() => _connecting = false);
      _showError('Server unreachable at ${AppConfig.backendBaseUrl}\nRun: cd server && yarn dev');
      return;
    }

    final (:session, :error) = await _sessionSvc.createSession(
      userId: kUserId,
      homeLocation: _homeLocation!,
      currentLocation: _currentLocation!,
      frequencyMinutes: _frequencyMinutes,
    );

    if (error != null || session == null) {
      setState(() => _connecting = false);
      _showError(_friendlyError(error));
      return;
    }
    debugPrint('[Dashboard] Session created — starting background service');

    // Subscribe to background service events before starting so we don't miss
    // the first update.
    final bgService = FlutterBackgroundService();
    _updateSub = bgService.on('trafficUpdate').listen(_onBgUpdate);
    _statusSub = bgService.on('socketStatus').listen(_onSocketStatus);

    // Start the foreground service and pass it the config.
    await bgService.startService();
    bgService.invoke('start', {
      'userId'          : kUserId,
      'socketUrl'       : AppConfig.backendSocketUrl,
      'frequencyMinutes': _frequencyMinutes,
    });

    _locationSvc.startTracking((loc) {
      setState(() => _currentLocation = loc);
      _sessionSvc.updateLocation(kUserId, loc);
    });

    setState(() { _monitoring = true; _connecting = false; });
  }

  Future<void> _stopMonitoring() async {
    FlutterBackgroundService().invoke('stop');
    _updateSub?.cancel();
    _statusSub?.cancel();
    await _sessionSvc.stopSession(kUserId);
    _locationSvc.stopTracking();
    setState(() {
      _monitoring  = false;
      _bgConnected = false;
      _latestCondition = null;
    });
  }

  // ── Background service callbacks ──────────────────────────────────────────

  void _onBgUpdate(Map<String, dynamic>? data) {
    if (data == null || !mounted) return;

    final condition = TrafficCondition(
      duration          : (data['duration']          as num).toInt(),
      durationInTraffic : (data['durationInTraffic'] as num).toInt(),
      distance          : (data['distance']          as num).toInt(),
      status            : TrafficStatusX.fromString(data['status'] as String),
      timestamp         : DateTime.parse(data['timestamp'] as String),
      eta               : DateTime.parse(data['eta']       as String),
    );

    TrafficNotification? notification;
    if (data.containsKey('notifType')) {
      notification = TrafficNotification(
        type      : data['notifType']  as String,
        currentETA: data['notifETA']   as String,
        delay     : data['notifDelay'] as String,
      );
    }

    setState(() {
      _latestCondition = condition;
      if (notification != null) {
        _notifications.insert(
          0,
          NotificationEntry(time: DateTime.now(), notification: notification),
        );
      }
    });
  }

  void _onSocketStatus(Map<String, dynamic>? data) {
    if (data == null || !mounted) return;
    setState(() => _bgConnected = data['connected'] as bool? ?? false);
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  void _onFrequencyChanged(int value) {
    setState(() => _frequencyMinutes = value);
    if (_monitoring) {
      _sessionSvc.updateSettings(kUserId, notificationFrequencyMinutes: value);
      FlutterBackgroundService().invoke(
        'updateFrequency',
        {'frequencyMinutes': value},
      );
    }
  }

  void _onHomeSelected(AppLocation loc) {
    setState(() => _homeLocation = loc);
    if (_monitoring) {
      _sessionSvc.updateSettings(kUserId, homeLocation: loc);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _friendlyError(ApiError? e) {
    if (e == null) return 'Failed to start monitoring.';
    return switch (e) {
      MissingApiKeyError()                             => 'API key not configured.',
      AuthDeniedError()                                => 'API key rejected — check server/.env.',
      QuotaExceededError()                             => 'API quota exceeded. Try later.',
      NetworkError(statusCode: final c) when c != null => 'Server returned HTTP $c — check server console.',
      NetworkError()                                   => 'No response from ${AppConfig.backendBaseUrl}',
      ParseError()                                     => 'Unexpected server response — check server console.',
      SessionNotFoundError()                           => 'Session not found.',
    };
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    _statusSub?.cancel();
    _locationSvc.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionLabel('The Bando'),
            const SizedBox(height: 8),
            AddressSearch(
              current: _homeLocation,
              onSelected: _onHomeSelected,
            ),
            const SizedBox(height: 20),
            _SectionLabel('How eager are we today?'),
            const SizedBox(height: 8),
            FrequencySelector(
              selected: _frequencyMinutes,
              options: kFrequencyOptions,
              onChanged: _onFrequencyChanged,
            ),
            const SizedBox(height: 20),
            TrafficStatusCard(condition: _latestCondition),
            const SizedBox(height: 20),
            _SectionLabel('MAP VIEW'),
            const SizedBox(height: 8),
            TrafficMap(
              currentLocation: _currentLocation,
              homeLocation: _homeLocation,
              trafficStatus: _latestCondition?.status,
              onCurrentLocationChanged: (loc) =>
                  setState(() => _currentLocation = loc),
              onHomeLocationChanged: _onHomeSelected,
            ),
            if (_notifications.isNotEmpty) ...[
              const SizedBox(height: 20),
              _SectionLabel('RECENT ALERTS'),
              const SizedBox(height: 8),
              Container(
                decoration: AppTheme.cardDecoration(),
                child: NotificationsList(entries: _notifications),
              ),
            ],
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.background,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('TRAFFIC BUILDER'),
          const SizedBox(width: 8),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _monitoring
                  ? (_bgConnected ? AppTheme.accent : Colors.orange)
                  : AppTheme.textMuted,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _connecting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.accent,
                  ),
                )
              : _StartStopButton(
                  monitoring: _monitoring,
                  onStart: _startMonitoring,
                  onStop: _stopMonitoring,
                ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTheme.labelStyle);
}

class _StartStopButton extends StatelessWidget {
  final bool monitoring;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _StartStopButton({
    required this.monitoring,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: monitoring ? onStop : onStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: monitoring ? AppTheme.accentDim : AppTheme.accent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          monitoring ? 'STOP' : 'START',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
