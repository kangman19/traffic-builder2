import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/config/app_config.dart';
import '../models/location.dart';
import '../models/traffic_condition.dart';
import '../theme/app_theme.dart';

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
    final cur  = widget.currentLocation;
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
    final cur  = widget.currentLocation;
    final home = widget.homeLocation;

    if (cur != null) {
      markers.add(Marker(
        point: LatLng(cur.lat, cur.long),
        width: 36, height: 36,
        child: const _Pin(icon: Icons.my_location_rounded, color: Color(0xFF00C2FF)),
      ));
    }
    if (home != null) {
      markers.add(Marker(
        point: LatLng(home.lat, home.long),
        width: 36, height: 36,
        child: const _Pin(icon: Icons.home_rounded, color: AppTheme.accent),
      ));
    }
    return markers;
  }

  List<Polyline> _buildPolylines() {
    final cur  = widget.currentLocation;
    final home = widget.homeLocation;
    if (cur == null || home == null) return [];

    final color = (widget.trafficStatus ?? TrafficStatus.calm).color;
    return [
      Polyline(
        points: [LatLng(cur.lat, cur.long), LatLng(home.lat, home.long)],
        color: color.withValues(alpha: 0.85),
        strokeWidth: 4,
      ),
    ];
  }

  void _onTap(TapPosition _, LatLng pos) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: AppTheme.border),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.my_location_rounded, color: Color(0xFF00C2FF), size: 20),
              title: const Text('Set as Current Location',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                widget.onCurrentLocationChanged(
                    AppLocation(lat: pos.latitude, long: pos.longitude));
              },
            ),
            ListTile(
              leading: const Icon(Icons.home_rounded, color: AppTheme.accent, size: 20),
              title: const Text('Set as Home',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                widget.onHomeLocationChanged(
                    AppLocation(lat: pos.latitude, long: pos.longitude));
              },
            ),
            const SizedBox(height: 8),
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
    final center  = initial != null
        ? LatLng(initial.lat, initial.long)
        : const LatLng(34.0522, -118.2437); // Default: Los Angeles

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          SizedBox(
            height: 260,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: initial != null ? 13.0 : 10.0,
                onMapReady: () {
                  _mapReady = true;
                  _fitBounds();
                },
                onTap: _onTap,
                backgroundColor: AppTheme.background,
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
          // "Optimal Path" overlay label
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha:0.92),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alt_route_rounded, size: 13, color: AppTheme.accent),
                  SizedBox(width: 5),
                  Text('Optimal Path',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
          ),
        ],
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
          color: color.withValues(alpha:0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        padding: const EdgeInsets.all(5),
        child: Icon(icon, color: color, size: 16),
      );
}
