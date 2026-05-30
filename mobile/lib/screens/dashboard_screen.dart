import 'dart:async';
import 'package:flutter/material.dart';
import '../models/location.dart';
import '../models/traffic_condition.dart';
import '../models/traffic_update.dart';
import '../services/api_service.dart';
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
  final _api = ApiService();
  final _socket = SocketService();
  final _locationSvc = LocationService();
  final _notifSvc = NotificationService();

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
    _notifSvc.init();
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    final loc = await _locationSvc.getCurrentLocation();
    if (mounted) setState(() => _currentLocation = loc);
  }

  Future<void> _startMonitoring() async {
    if (_currentLocation == null) {
      _showSnack('Could not get your location. Enable GPS and try again.');
      return;
    }
    if (_homeLocation == null) {
      _showSnack('Please set your home location first.');
      return;
    }

    setState(() => _connecting = true);
    try {
      await _api.createSession(
        userId: kUserId,
        homeLocation: _homeLocation!,
        currentLocation: _currentLocation!,
        frequency: _frequencyMinutes,
      );

      _socket.connect();
      _socketSub = _socket.updates.listen(_onTrafficUpdate);

      _locationSvc.startTracking((loc) {
        setState(() => _currentLocation = loc);
        _api.updateLocation(kUserId, loc);
      });

      await _notifSvc.showMonitoringNotification();

      setState(() { _monitoring = true; _connecting = false; });
    } catch (e) {
      setState(() => _connecting = false);
      _showSnack('Failed to start monitoring: $e');
    }
  }

  Future<void> _stopMonitoring() async {
    await _api.stopSession(kUserId);
    _socketSub?.cancel();
    _locationSvc.stopTracking();
    await _notifSvc.cancelMonitoringNotification();
    setState(() => _monitoring = false);
  }

  void _onTrafficUpdate(TrafficUpdate update) {
    setState(() {
      _latestCondition = update.condition;
      if (update.notification != null) {
        _notifications.insert(0, NotificationEntry(
          time: DateTime.now(),
          notification: update.notification!,
        ));
      }
    });

    if (update.notification != null) {
      final notif = update.notification!;
      final title = notif.isWorsening ? 'Traffic Building' : 'Traffic Clearing';
      _notifSvc.showTrafficNotification(title, notif.message);
    }
  }

  void _onFrequencyChanged(int value) {
    setState(() => _frequencyMinutes = value);
    if (_monitoring) {
      _api.updateSettings(kUserId, notificationFrequencyMinutes: value);
    }
  }

  void _onHomeSelected(AppLocation loc) {
    setState(() => _homeLocation = loc);
    if (_monitoring) {
      _api.updateSettings(kUserId, homeLocation: loc);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _socket.dispose();
    _locationSvc.dispose();
    super.dispose();
  }

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
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
            )
          else if (_monitoring)
            TextButton(
              onPressed: _stopMonitoring,
              child: const Text('Stop', style: TextStyle(color: Colors.white)),
            )
          else
            TextButton(
              onPressed: _startMonitoring,
              child: const Text('Start', style: TextStyle(color: Colors.white)),
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
              onRefresh: () => _monitoring ? _socket.checkTraffic(kUserId) : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TrafficMap(
                currentLocation: _currentLocation,
                homeLocation: _homeLocation,
                trafficStatus: _latestCondition?.status,
                onCurrentLocationChanged: (loc) => setState(() => _currentLocation = loc),
                onHomeLocationChanged: _onHomeSelected,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: const Text('Notifications',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
