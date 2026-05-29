import 'package:flutter/material.dart';
import '../models/traffic_condition.dart';

class TrafficStatusCardWidget extends StatelessWidget {
  final TrafficCondition? condition;
  final int frequencyMinutes;
  final List<int> frequencyOptions;
  final ValueChanged<int> onFrequencyChanged;
  final VoidCallback onRefresh;

  const TrafficStatusCardWidget({
    super.key,
    required this.condition,
    required this.frequencyMinutes,
    required this.frequencyOptions,
    required this.onFrequencyChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cond = condition;
    final status = cond?.status ?? TrafficStatus.calm;
    final color = status.color;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    cond != null ? status.label : '---',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                if (cond != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow('ETA', cond.etaFormatted),
                        _InfoRow('Normal', cond.normalFormatted),
                        _InfoRow('Delay', cond.delayFormatted),
                        _InfoRow('Distance', cond.distanceFormatted),
                      ],
                    ),
                  )
                else
                  const Expanded(child: Text('Waiting for first check…')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Notify every: '),
                DropdownButton<int>(
                  value: frequencyMinutes,
                  items: frequencyOptions
                      .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                      .toList(),
                  onChanged: (v) => v != null ? onFrequencyChanged(v) : null,
                ),
                const Spacer(),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Force check',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      );
}
