import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  GoogleMapController? _controller;

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final cur = widget.currentLocation;
    final home = widget.homeLocation;

    if (cur != null) {
      markers.add(Marker(
        markerId: const MarkerId('current'),
        position: LatLng(cur.lat, cur.long),
        infoWindow: const InfoWindow(title: 'Current Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        draggable: true,
        onDragEnd: (pos) =>
            widget.onCurrentLocationChanged(AppLocation(lat: pos.latitude, long: pos.longitude)),
      ));
    }

    if (home != null) {
      markers.add(Marker(
        markerId: const MarkerId('home'),
        position: LatLng(home.lat, home.long),
        infoWindow: const InfoWindow(title: 'Home'),
        draggable: true,
        onDragEnd: (pos) =>
            widget.onHomeLocationChanged(AppLocation(lat: pos.latitude, long: pos.longitude)),
      ));
    }

    return markers;
  }

  Set<Polyline> _buildPolyline() {
    final cur = widget.currentLocation;
    final home = widget.homeLocation;
    if (cur == null || home == null) return {};

    final color = (widget.trafficStatus ?? TrafficStatus.calm).color;
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [LatLng(cur.lat, cur.long), LatLng(home.lat, home.long)],
        color: color,
        width: 4,
      ),
    };
  }

  void _fitBounds() {
    final cur = widget.currentLocation;
    final home = widget.homeLocation;
    if (_controller == null || cur == null || home == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        cur.lat < home.lat ? cur.lat : home.lat,
        cur.long < home.long ? cur.long : home.long,
      ),
      northeast: LatLng(
        cur.lat > home.lat ? cur.lat : home.lat,
        cur.long > home.long ? cur.long : home.long,
      ),
    );
    _controller!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  @override
  void didUpdateWidget(TrafficMap old) {
    super.didUpdateWidget(old);
    if (old.currentLocation != widget.currentLocation ||
        old.homeLocation != widget.homeLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    }
  }

  void _onMapTap(LatLng pos) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location, color: Colors.blue),
              title: const Text('Set as Current Location'),
              onTap: () {
                Navigator.pop(context);
                widget.onCurrentLocationChanged(AppLocation(lat: pos.latitude, long: pos.longitude));
              },
            ),
            ListTile(
              leading: const Icon(Icons.home, color: Colors.red),
              title: const Text('Set as Home'),
              onTap: () {
                Navigator.pop(context);
                widget.onHomeLocationChanged(AppLocation(lat: pos.latitude, long: pos.longitude));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.currentLocation ?? widget.homeLocation;
    return SizedBox(
      height: 350,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: initial == null
            ? const Center(child: Text('Waiting for location…'))
            : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(initial.lat, initial.long),
                  zoom: 12,
                ),
                markers: _buildMarkers(),
                polylines: _buildPolyline(),
                onMapCreated: (c) {
                  _controller = c;
                  WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
                },
                onTap: _onMapTap,
                myLocationButtonEnabled: false,
              ),
      ),
    );
  }
}

