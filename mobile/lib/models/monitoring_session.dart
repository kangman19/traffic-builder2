import 'location.dart';
import 'traffic_condition.dart';

class MonitoringSession {
  final String userId;
  final AppLocation homeLocation;
  final AppLocation currentLocation;
  final bool isActive;
  final TrafficCondition? lastCheck;
  final int notificationThreshold;
  final int notificationFrequencyMinutes;

  const MonitoringSession({
    required this.userId,
    required this.homeLocation,
    required this.currentLocation,
    required this.isActive,
    this.lastCheck,
    required this.notificationThreshold,
    required this.notificationFrequencyMinutes,
  });

  factory MonitoringSession.fromJson(Map<String, dynamic> json) => MonitoringSession(
        userId: json['userId'] as String,
        homeLocation: AppLocation.fromJson(json['homeLocation'] as Map<String, dynamic>),
        currentLocation: AppLocation.fromJson(json['currentLocation'] as Map<String, dynamic>),
        isActive: json['isActive'] as bool,
        lastCheck: json['lastCheck'] != null
            ? TrafficCondition.fromJson(json['lastCheck'] as Map<String, dynamic>)
            : null,
        notificationThreshold: (json['notificationThreshold'] as num).toInt(),
        notificationFrequencyMinutes: (json['notificationFrequencyMinutes'] as num).toInt(),
      );
}
