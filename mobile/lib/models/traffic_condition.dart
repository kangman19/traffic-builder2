import 'package:flutter/material.dart';

enum TrafficStatus { calm, bookey, ggs }

extension TrafficStatusX on TrafficStatus {
  String get label {
    switch (this) {
      case TrafficStatus.calm:
        return 'CALM';
      case TrafficStatus.bookey:
        return 'BOOKEY';
      case TrafficStatus.ggs:
        return "GG's";
    }
  }

  Color get color {
    switch (this) {
      case TrafficStatus.calm:
        return const Color(0xFF22C55E);
      case TrafficStatus.bookey:
        return const Color(0xFFF59E0B);
      case TrafficStatus.ggs:
        return const Color(0xFFEF4444);
    }
  }

  static TrafficStatus fromString(String s) {
    switch (s) {
      case 'bookey':
        return TrafficStatus.bookey;
      case "GG's":
        return TrafficStatus.ggs;
      default:
        return TrafficStatus.calm;
    }
  }
}

class TrafficCondition {
  final int duration;
  final int durationInTraffic;
  final int distance;
  final TrafficStatus status;
  final DateTime timestamp;
  final DateTime eta;

  const TrafficCondition({
    required this.duration,
    required this.durationInTraffic,
    required this.distance,
    required this.status,
    required this.timestamp,
    required this.eta,
  });

  factory TrafficCondition.fromJson(Map<String, dynamic> json) => TrafficCondition(
        duration: (json['duration'] as num).toInt(),
        durationInTraffic: (json['durationInTraffic'] as num).toInt(),
        distance: (json['distance'] as num).toInt(),
        status: TrafficStatusX.fromString(json['status'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
        eta: DateTime.parse(json['eta'] as String),
      );

  String get etaFormatted {
    final mins = (durationInTraffic / 60).round();
    return '$mins mins';
  }

  String get normalFormatted {
    final mins = (duration / 60).round();
    return '$mins mins';
  }

  String get delayFormatted {
    final delay = durationInTraffic - duration;
    if (delay <= 0) return 'On time';
    final mins = (delay / 60).round();
    return '+$mins mins';
  }

  String get distanceFormatted {
    final km = distance / 1000;
    return '${km.toStringAsFixed(1)} km';
  }
}
