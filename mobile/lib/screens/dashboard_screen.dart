import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/api_error.dart';
import '../models/location.dart';
import '../models/traffic_condition.dart';
import '../models/traffic_update.dart';
import '../services/session_service.dart';
import '../services/socket_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../widgets/traffic_status_card.dart';
import '../widgets/traffic_map.dart';
import '../widgets/notifications_list.dart';
import '../widgets/settings_panel.dart';

const String kUserId = 'user123';
const List<int> kFrequencyOptions = [5, 7, 10, 15, 20];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _sessionSvc = SessionService();
  final _socket = SocketService();
  final _locationSvc = LocationService();
  final _notifSvc = NotificationService.instance;

  AppLocation? _currentLocation;
  AppLocation? _homeLocation;
  TrafficCondition? _latestCondition;
  bool _monitoring = false;
  bool _connecting = false;
  int _frequencyMinutes = 10;

  final List<NotificationEntry> _notifications = [];
  StreamSubscription<TrafficUpdate>? _socketSub;

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  // ── Location ─────────────────────────────────────────────────────────────

  Future<void> _detectLocation() async {
    final loc = await _locationSvc.getCurrentLocation();
    if (mounted) setState(() => _currentLocation = loc);
  }

  // ── Session lifecycle ─────────────────────────────────────────────────────

  Future<void> _startMonitoring() async {
    if (_currentLocation == null) {
      _showError('Could not get your location. Enable GPS and try again.');
      return;
    }
    if (_homeLocation == null) {
      _showError('Please set your home location in Settings first.');
      return;
    }

    setState(() => _connecting = true);

    final (:session, :error) = await _sessionSvc.createSession(
      userId: kUserId,
      homeLocation: _homeLocation!,
      currentLocation: _currentLocation!,
      frequencyMinutes: _frequencyMinutes,
    );

    if (error != null || session == null) {
      setState(() => _connecting = false);
      _showError(_friendlyErrorMessage(error));
      return;
    }

    _socket.connect();
    _socketSub = _socket.updates.listen(_onTrafficUpdate);

    _locationSvc.startTracking((loc) {
      setState(() => _currentLocation = loc);
      _sessionSvc.updateLocation(kUserId, loc);
    });

    await _notifSvc.showMonitoringActive();
    setState(() {
      _monitoring = true;
      _connecting = false;
    });
  }

  Future<void> _stopMonitoring() async {
    await _sessionSvc.stopSession(kUserId);
    _socketSub?.cancel();
    _locationSvc.stopTracking();
    await _notifSvc.cancelMonitoringActive();
    setState(() => _monitoring = false);
  }

  // ── Real-time updates ─────────────────────────────────────────────────────

  void _onTrafficUpdate(TrafficUpdate update) {
    setState(() {
      _latestCondition = update.condition;
      if (update.notification != null) {
        _notifications.insert(
          0,
          NotificationEntry(
            time: DateTime.now(),
            notification: update.notification!,
          ),
        );
      }
    });

    if (update.notification != null) {
      final notif = update.notification!;
      _notifSvc.showTrafficAlert(
        notif.isWorsening ? 'Traffic Building' : 'Traffic Clearing',
        notif.message,
      );
    }
  }

  // ── Settings callbacks ────────────────────────────────────────────────────

  void _onFrequencyChanged(int value) {
    setState(() => _frequencyMinutes = value);
    if (_monitoring) {
      _sessionSvc.updateSettings(kUserId,
          notificationFrequencyMinutes: value);
    }
  }

  void _onHomeSelected(AppLocation loc) {
    setState(() => _homeLocation = loc);
    if (_monitoring) {
      _sessionSvc.updateSettings(kUserId, homeLocation: loc);
    }
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _friendlyErrorMessage(ApiError? error) {
    if (error == null) return 'Failed to start monitoring.';
    return switch (error) {
      MissingApiKeyError() => 'API key not configured.',
      AuthDeniedError()    => 'API key rejected. Check your key.',
      QuotaExceededError() => 'API quota exceeded. Try again later.',
      NetworkError()       => 'Cannot reach server. Is it running?',
      ParseError()         => 'Unexpected server response.',
      SessionNotFoundError() => 'Session not found.',
    };
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _socket.dispose();
    _locationSvc.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Traffic Builder'),
            const SizedBox(width: 8),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _monitoring
                    ? (_socket.isConnected ? Colors.green : Colors.orange)
                    : Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          if (_connecting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else if (_monitoring)
            TextButton(
              onPressed: _stopMonitoring,
              child:
                  const Text('Stop', style: TextStyle(color: Colors.white)),
            )
          else
            TextButton(
              onPressed: _startMonitoring,
              child:
                  const Text('Start', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrafficStatusCardWidget(
              condition: _latestCondition,
              frequencyMinutes: _frequencyMinutes,
              frequencyOptions: kFrequencyOptions,
              onFrequencyChanged: _onFrequencyChanged,
              onRefresh: () =>
                  _monitoring ? _socket.checkTraffic(kUserId) : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TrafficMap(
                currentLocation: _currentLocation,
                homeLocation: _homeLocation,
                trafficStatus: _latestCondition?.status,
                onCurrentLocationChanged: (loc) =>
                    setState(() => _currentLocation = loc),
                onHomeLocationChanged: _onHomeSelected,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: const Text(
                'Notifications',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            NotificationsList(entries: _notifications),
            const Divider(height: 32),
            SettingsPanel(
              homeLocation: _homeLocation,
              currentLocation: _currentLocation,
              onHomeSelected: _onHomeSelected,
              onRedetectGps: _detectLocation,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
