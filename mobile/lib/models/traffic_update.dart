import 'traffic_condition.dart';

class TrafficNotification {
  final String type;
  final String currentETA;
  final String delay;

  const TrafficNotification({
    required this.type,
    required this.currentETA,
    required this.delay,
  });

  factory TrafficNotification.fromJson(Map<String, dynamic> json) => TrafficNotification(
        type: json['type'] as String,
        currentETA: json['currentETA'] as String,
        delay: json['delay'] as String,
      );

  bool get isWorsening => type == 'start_getting_cozy';

  String get message => isWorsening
      ? 'Traffic building — ETA now $currentETA ($delay)'
      : 'Traffic clearing — ETA now $currentETA';
}

class TrafficUpdate {
  final String userId;
  final TrafficCondition condition;
  final TrafficNotification? notification;

  const TrafficUpdate({
    required this.userId,
    required this.condition,
    this.notification,
  });

  factory TrafficUpdate.fromJson(Map<String, dynamic> json) => TrafficUpdate(
        userId: json['userId'] as String,
        condition: TrafficCondition.fromJson(json['condition'] as Map<String, dynamic>),
        notification: json['notification'] != null
            ? TrafficNotification.fromJson(json['notification'] as Map<String, dynamic>)
            : null,
      );
}
