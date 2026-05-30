import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/config/app_config.dart';
import '../models/location.dart';
import '../models/traffic_condition.dart';

class TrafficMap extends StatefulWidget {
  final AppLocation? currentLocation;
  final AppLocation? homeLocation;
  final TrafficStatus? trafficStatus;
  final ValueChanged<AppLocation> onCurrentLocationChanged;
  final ValueChanged<AppLocation> onHomeLocationChanged;

  const TrafficMap({
    super.key,
    required this.currentLocation,
    required this.homeLocation,
    required this.trafficStatus,
    required this.onCurrentLocationChanged,
    required this.onHomeLocationChanged,
  });

  @override
  State<TrafficMap> createState() => _TrafficMapState();
}

class _TrafficMapState extends State<TrafficMap> {
  final _mapController = MapController();
  bool _mapReady = false;

  @override
  void didUpdateWidget(TrafficMap old) {
    super.didUpdateWidget(old);
    if (old.currentLocation != widget.currentLocation ||
        old.homeLocation != widget.homeLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    }
  }

  void _fitBounds() {
    if (!_mapReady) return;
    final cur = widget.currentLocation;
    final home = widget.homeLocation;

    if (cur != null && home != null) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([
            LatLng(cur.lat, cur.long),
            LatLng(home.lat, home.long),
          ]),
          padding: const EdgeInsets.all(60),
        ),
      );
    } else {
      final single = cur ?? home;
      if (single != null) {
        _mapController.move(LatLng(single.lat, single.long), 13);
      }
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    final cur = widget.currentLocation;
    final home = widget.homeLocation;

    if (cur != null) {
      markers.add(Marker(
        point: LatLng(cur.lat, cur.long),
        width: 44,
        height: 44,
        child: const _Pin(icon: Icons.my_location, color: Colors.blue),
      ));
    }
    if (home != null) {
      markers.add(Marker(
        point: LatLng(home.lat, home.long),
        width: 44,
        height: 44,
        child: const _Pin(icon: Icons.home, color: Colors.red),
      ));
    }
    return markers;
  }

  List<Polyline> _buildPolylines() {
    final cur = widget.currentLocation;
    final home = widget.homeLocation;
    if (cur == null || home == null) return [];

    final color = (widget.trafficStatus ?? TrafficStatus.calm).color;
    return [
      Polyline(
        points: [LatLng(cur.lat, cur.long), LatLng(home.lat, home.long)],
        color: color,
        strokeWidth: 5,
      ),
    ];
  }

  void _onTap(TapPosition _, LatLng pos) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location, color: Colors.blue),
              title: const Text('Set as Current Location'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onCurrentLocationChanged(
                    AppLocation(lat: pos.latitude, long: pos.longitude));
              },
            ),
            ListTile(
              leading: const Icon(Icons.home, color: Colors.red),
              title: const Text('Set as Home'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onHomeLocationChanged(
                    AppLocation(lat: pos.latitude, long: pos.longitude));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.currentLocation ?? widget.homeLocation;
    final center = initial != null ? LatLng(initial.lat, initial.long) : const LatLng(51.5, -0.1);

    return SizedBox(
      height: 350,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: initial != null ? 13.0 : 4.0,
            onMapReady: () {
              _mapReady = true;
              _fitBounds();
            },
            onTap: _onTap,
          ),
          children: [
            TileLayer(
              urlTemplate: AppConfig.openStreetMapTileEndpoint,
              userAgentPackageName: 'com.trafficbuilder.mobile',
              maxZoom: 19,
            ),
            PolylineLayer(polylines: _buildPolylines()),
            MarkerLayer(markers: _buildMarkers()),
          ],
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _Pin({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: Colors.white, size: 20),
      );
}
