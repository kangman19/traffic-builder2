import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/location.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;

  /// Requests location permissions and returns the current position.
  /// Returns null if permission is denied.
  Future<AppLocation?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    // Request background permission for continuous monitoring.
    if (permission == LocationPermission.whileInUse) {
      await Geolocator.requestPermission();
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return AppLocation(lat: pos.latitude, long: pos.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Starts streaming position updates and calls [onUpdate] for each one.
  void startTracking(void Function(AppLocation) onUpdate) {
    _positionSubscription?.cancel();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50, // update every 50 metres
    );
    _positionSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) => onUpdate(AppLocation(lat: pos.latitude, long: pos.longitude)),
      onError: (_) {},
    );
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void dispose() => stopTracking();
}
