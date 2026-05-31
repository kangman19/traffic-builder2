import 'package:flutter/material.dart';
import '../models/traffic_condition.dart';
import '../theme/app_theme.dart';

class TrafficStatusCard extends StatelessWidget {
  final TrafficCondition? condition;

  const TrafficStatusCard({super.key, required this.condition});

  @override
  Widget build(BuildContext context) {
    final cond = condition;

    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: cond == null ? _buildWaiting() : _buildLoaded(cond),
    );
  }

  Widget _buildWaiting() => const SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'Start monitoring to see traffic',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ),
      );

  Widget _buildLoaded(TrafficCondition cond) {
    return Column(
      children: [
        // Large ETA
        Text(
          cond.etaMinutes,
          style: const TextStyle(
            color: AppTheme.accent,
            fontSize: 52,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          cond.status.statusLine,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        Container(height: 1, color: AppTheme.border),
        const SizedBox(height: 16),
        // Stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Stat(label: 'DISTANCE', value: cond.distanceMiles),
            _VertDivider(),
            _Stat(label: 'DELAY',    value: cond.delayShort),
            _VertDivider(),
            _Stat(label: 'ARRIVAL',  value: cond.arrivalTime),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label, style: AppTheme.statLabel),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.statValue),
        ],
      );
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1, height: 32, color: AppTheme.border,
      );
}
