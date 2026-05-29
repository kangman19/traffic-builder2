import 'package:flutter/material.dart';
import '../models/traffic_update.dart';

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
        child: Text('No notifications yet.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        final isWorsening = e.notification.isWorsening;
        final timeStr =
            '${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')}';
        return ListTile(
          leading: Icon(
            isWorsening ? Icons.warning_rounded : Icons.check_circle_rounded,
            color: isWorsening ? Colors.orange : Colors.green,
          ),
          title: Text(e.notification.message, style: const TextStyle(fontSize: 13)),
          trailing: Text(timeStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          dense: true,
        );
      },
    );
  }
}
