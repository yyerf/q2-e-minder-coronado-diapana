import 'package:flutter/material.dart';

class BatteryHealth {
  final String carId;
  final double voltage;
  final double soc; // State of Charge (%)
  final double soh; // State of Health (%)
  final BatteryStatus status;
  final String recommendation;
  final double? estimatedHours;
  final String batteryType;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const BatteryHealth({
    required this.carId,
    required this.voltage,
    required this.soc,
    required this.soh,
    required this.status,
    required this.recommendation,
    this.estimatedHours,
    required this.batteryType,
    required this.timestamp,
    this.metadata,
  });

  factory BatteryHealth.fromJson(Map<String, dynamic> json) {
    return BatteryHealth(
      carId: json['carId'] as String? ?? '',
      voltage: (json['voltage'] as num?)?.toDouble() ?? 0.0,
      soc: (json['soc'] as num?)?.toDouble() ?? 0.0,
      soh: (json['soh'] as num?)?.toDouble() ?? 0.0,
      status: BatteryStatus.fromString(json['status'] as String? ?? 'unknown'),
      recommendation:
          json['recommendation'] as String? ?? 'No recommendation available',
      estimatedHours: json['estimated_hours'] != null
          ? (json['estimated_hours'] as num).toDouble()
          : null,
      batteryType: json['battery_type'] as String? ?? 'unknown',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'carId': carId,
      'voltage': voltage,
      'soc': soc,
      'soh': soh,
      'status': status.value,
      'recommendation': recommendation,
      'estimated_hours': estimatedHours,
      'battery_type': batteryType,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  BatteryHealth copyWith({
    String? carId,
    double? voltage,
    double? soc,
    double? soh,
    BatteryStatus? status,
    String? recommendation,
    double? estimatedHours,
    String? batteryType,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return BatteryHealth(
      carId: carId ?? this.carId,
      voltage: voltage ?? this.voltage,
      soc: soc ?? this.soc,
      soh: soh ?? this.soh,
      status: status ?? this.status,
      recommendation: recommendation ?? this.recommendation,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      batteryType: batteryType ?? this.batteryType,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isCritical =>
      status == BatteryStatus.dead || status == BatteryStatus.low;
  bool get needsAttention => status == BatteryStatus.weak || isCritical;
}

enum BatteryStatus {
  fresh('fresh'),
  good('good'),
  weak('weak'),
  low('low'),
  dead('dead'),
  unknown('unknown');

  const BatteryStatus(this.value);
  final String value;

  static BatteryStatus fromString(String value) {
    return BatteryStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => BatteryStatus.unknown,
    );
  }

  String get displayName {
    switch (this) {
      case BatteryStatus.fresh:
        return 'Fresh';
      case BatteryStatus.good:
        return 'Good';
      case BatteryStatus.weak:
        return 'Weak';
      case BatteryStatus.low:
        return 'Low';
      case BatteryStatus.dead:
        return 'Dead';
      case BatteryStatus.unknown:
        return 'Unknown';
    }
  }

  Color get color {
    switch (this) {
      case BatteryStatus.fresh:
        return const Color(0xFF4CAF50); // Green
      case BatteryStatus.good:
        return const Color(0xFF8BC34A); // Light Green
      case BatteryStatus.weak:
        return const Color(0xFFFF9800); // Orange
      case BatteryStatus.low:
        return const Color(0xFFFF5722); // Deep Orange
      case BatteryStatus.dead:
        return const Color(0xFFF44336); // Red
      case BatteryStatus.unknown:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  IconData get icon {
    switch (this) {
      case BatteryStatus.fresh:
        return Icons.battery_full;
      case BatteryStatus.good:
        return Icons.battery_5_bar;
      case BatteryStatus.weak:
        return Icons.battery_3_bar;
      case BatteryStatus.low:
        return Icons.battery_1_bar;
      case BatteryStatus.dead:
        return Icons.battery_0_bar;
      case BatteryStatus.unknown:
        return Icons.battery_unknown;
    }
  }
}
