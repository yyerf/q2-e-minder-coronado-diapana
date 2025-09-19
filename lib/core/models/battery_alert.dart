import 'package:flutter/material.dart';

class BatteryAlert {
  final String id;
  final String carId;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? data;

  const BatteryAlert({
    required this.id,
    required this.carId,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.data,
  });

  factory BatteryAlert.fromJson(Map<String, dynamic> json) {
    return BatteryAlert(
      id: json['id'] as String,
      carId: json['carId'] as String,
      type: AlertType.fromString(json['type'] as String),
      severity: AlertSeverity.fromString(json['severity'] as String),
      title: json['title'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'carId': carId,
      'type': type.value,
      'severity': severity.value,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'data': data,
    };
  }

  BatteryAlert copyWith({
    String? id,
    String? carId,
    AlertType? type,
    AlertSeverity? severity,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return BatteryAlert(
      id: id ?? this.id,
      carId: carId ?? this.carId,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }

  static BatteryAlert createCriticalBatteryAlert({
    required String carId,
    required double voltage,
    required double soc,
    required String batteryType,
  }) {
    return BatteryAlert(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      carId: carId,
      type: AlertType.batteryLow,
      severity: AlertSeverity.critical,
      title: 'Critical Battery Level',
      message:
          'Battery voltage is critically low at ${voltage.toStringAsFixed(2)}V (${soc.toStringAsFixed(1)}%). Immediate replacement required.',
      timestamp: DateTime.now(),
      data: {
        'voltage': voltage,
        'soc': soc,
        'batteryType': batteryType,
      },
    );
  }

  static BatteryAlert createLowBatteryAlert({
    required String carId,
    required double voltage,
    required double soc,
    required String batteryType,
  }) {
    return BatteryAlert(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      carId: carId,
      type: AlertType.batteryLow,
      severity: AlertSeverity.warning,
      title: 'Low Battery Level',
      message:
          'Battery voltage is low at ${voltage.toStringAsFixed(2)}V (${soc.toStringAsFixed(1)}%). Consider replacement soon.',
      timestamp: DateTime.now(),
      data: {
        'voltage': voltage,
        'soc': soc,
        'batteryType': batteryType,
      },
    );
  }

  static BatteryAlert createHealthDegradationAlert({
    required String carId,
    required double soh,
    required String batteryType,
  }) {
    return BatteryAlert(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      carId: carId,
      type: AlertType.healthDegradation,
      severity: soh < 60 ? AlertSeverity.warning : AlertSeverity.info,
      title: 'Battery Health Degradation',
      message:
          'Battery health has degraded to ${soh.toStringAsFixed(1)}%. Monitor performance closely.',
      timestamp: DateTime.now(),
      data: {
        'soh': soh,
        'batteryType': batteryType,
      },
    );
  }

  static BatteryAlert createSuddenDropAlert({
    required String carId,
    required double fromVoltage,
    required double toVoltage,
    required Duration within,
    required String batteryType,
  }) {
    final drop = fromVoltage - toVoltage;
    return BatteryAlert(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      carId: carId,
      type: AlertType.suddenDrop,
      severity: AlertSeverity.critical,
      title: 'Sudden Voltage Drop',
      message:
          'Voltage dropped by ${drop.toStringAsFixed(2)}V in ${within.inSeconds}s (from ${fromVoltage.toStringAsFixed(2)}V to ${toVoltage.toStringAsFixed(2)}V). Investigate possible failure or disconnection.',
      timestamp: DateTime.now(),
      data: {
        'fromVoltage': fromVoltage,
        'toVoltage': toVoltage,
        'drop': drop,
        'windowSeconds': within.inSeconds,
        'batteryType': batteryType,
      },
    );
  }

  static BatteryAlert createDisposableBatteryAlert({
    required String carId,
    required double voltage,
    required double soc,
    required String batteryType,
  }) {
    return BatteryAlert(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      carId: carId,
      type: AlertType.batteryLow,
      severity: AlertSeverity.critical,
      title: 'Battery Disposed/Dead',
      message:
          'Voltage is at ${voltage.toStringAsFixed(2)}V (${soc.toStringAsFixed(1)}%). This is <= 4.5V and indicates the battery should be disposed/replaced.',
      timestamp: DateTime.now(),
      data: {
        'voltage': voltage,
        'soc': soc,
        'batteryType': batteryType,
        'reason': 'absolute_dispose_<=4_5V',
      },
    );
  }
}

enum AlertType {
  batteryLow('battery_low'),
  healthDegradation('health_degradation'),
  suddenDrop('sudden_drop'),
  connectionLost('connection_lost'),
  sensorError('sensor_error'),
  systemError('system_error');

  const AlertType(this.value);
  final String value;

  static AlertType fromString(String value) {
    return AlertType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => AlertType.systemError,
    );
  }

  String get displayName {
    switch (this) {
      case AlertType.batteryLow:
        return 'Battery Low';
      case AlertType.healthDegradation:
        return 'Health Degradation';
      case AlertType.suddenDrop:
        return 'Sudden Drop';
      case AlertType.connectionLost:
        return 'Connection Lost';
      case AlertType.sensorError:
        return 'Sensor Error';
      case AlertType.systemError:
        return 'System Error';
    }
  }

  IconData get icon {
    switch (this) {
      case AlertType.batteryLow:
        return Icons.battery_alert;
      case AlertType.healthDegradation:
        return Icons.trending_down;
      case AlertType.suddenDrop:
        return Icons.bolt;
      case AlertType.connectionLost:
        return Icons.wifi_off;
      case AlertType.sensorError:
        return Icons.sensors_off;
      case AlertType.systemError:
        return Icons.error;
    }
  }
}

enum AlertSeverity {
  info('info'),
  warning('warning'),
  critical('critical');

  const AlertSeverity(this.value);
  final String value;

  static AlertSeverity fromString(String value) {
    return AlertSeverity.values.firstWhere(
      (severity) => severity.value == value,
      orElse: () => AlertSeverity.info,
    );
  }

  String get displayName {
    switch (this) {
      case AlertSeverity.info:
        return 'Info';
      case AlertSeverity.warning:
        return 'Warning';
      case AlertSeverity.critical:
        return 'Critical';
    }
  }

  Color get color {
    switch (this) {
      case AlertSeverity.info:
        return Colors.blue;
      case AlertSeverity.warning:
        return Colors.orange;
      case AlertSeverity.critical:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case AlertSeverity.info:
        return Icons.info;
      case AlertSeverity.warning:
        return Icons.warning;
      case AlertSeverity.critical:
        return Icons.error;
    }
  }
}
