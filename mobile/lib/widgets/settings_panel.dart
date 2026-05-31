import 'package:flutter/material.dart';
import '../models/location.dart';
import 'address_search.dart';

class SettingsPanel extends StatelessWidget {
  final AppLocation? homeLocation;
  final AppLocation? currentLocation;
  final ValueChanged<AppLocation> onHomeSelected;
  final VoidCallback onRedetectGps;

  const SettingsPanel({
    super.key,
    required this.homeLocation,
    required this.currentLocation,
    required this.onHomeSelected,
    required this.onRedetectGps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          AddressSearch(
            current: homeLocation,
            onSelected: onHomeSelected,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Location', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      currentLocation?.toString() ?? 'Not detected',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: onRedetectGps,
                icon: const Icon(Icons.gps_fixed, size: 16),
                label: const Text('Re-detect'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
