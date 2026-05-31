import 'package:flutter/material.dart';
import '../models/traffic_update.dart';
import '../theme/app_theme.dart';

class NotificationEntry {
  final DateTime time;
  final TrafficNotification notification;
  const NotificationEntry({required this.time, required this.notification});
}

class NotificationsList extends StatelessWidget {
  final List<NotificationEntry> entries;
  const NotificationsList({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No alerts yet.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: AppTheme.border),
      itemBuilder: (_, i) {
        final e = entries[i];
        final worsening = e.notification.isWorsening;
        final timeStr =
            '${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')}';
        return ListTile(
          dense: true,
          leading: Icon(
            worsening ? Icons.warning_rounded : Icons.check_circle_rounded,
            size: 18,
            color: worsening ? Colors.orange : const Color(0xFF22C55E),
          ),
          title: Text(
            e.notification.message,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          ),
          trailing: Text(
            timeStr,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        );
      },
    );
  }
}
