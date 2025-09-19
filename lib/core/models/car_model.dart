// import 'package:json_annotation/json_annotation.dart';

// part 'car_model.g.dart';

// @JsonSerializable()
class Car {
  final String id;
  final String userId;
  final String make;
  final String model;
  final int year;
  final String? vin;
  final String? licensePlate;
  final DateTime registeredAt;
  final bool isActive;
  final String? deviceId; // IoT device identifier
  final CarConfiguration? configuration;

  const Car({
    required this.id,
    required this.userId,
    required this.make,
    required this.model,
    required this.year,
    this.vin,
    this.licensePlate,
    required this.registeredAt,
    this.isActive = true,
    this.deviceId,
    this.configuration,
  });

  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      id: json['id'] as String,
      userId: json['userId'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      vin: json['vin'] as String?,
      licensePlate: json['licensePlate'] as String?,
      registeredAt: DateTime.parse(json['registeredAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
      deviceId: json['deviceId'] as String?,
      configuration: json['configuration'] != null
          ? CarConfiguration.fromJson(json['configuration'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'make': make,
      'model': model,
      'year': year,
      'vin': vin,
      'licensePlate': licensePlate,
      'registeredAt': registeredAt.toIso8601String(),
      'isActive': isActive,
      'deviceId': deviceId,
      'configuration': configuration?.toJson(),
    };
  }

  String get displayName => '$year $make $model';
}

// @JsonSerializable()
class CarConfiguration {
  final Map<String, SensorConfig> sensors;
  final int dataCollectionInterval; // seconds
  final bool alertsEnabled;
  final Map<String, double> thresholds;

  const CarConfiguration({
    required this.sensors,
    this.dataCollectionInterval = 30,
    this.alertsEnabled = true,
    required this.thresholds,
  });

  factory CarConfiguration.fromJson(Map<String, dynamic> json) {
    return CarConfiguration(
      sensors: (json['sensors'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, SensorConfig.fromJson(value as Map<String, dynamic>)),
      ),
      dataCollectionInterval: json['dataCollectionInterval'] as int? ?? 30,
      alertsEnabled: json['alertsEnabled'] as bool? ?? true,
      thresholds: Map<String, double>.from(json['thresholds'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sensors': sensors.map((key, value) => MapEntry(key, value.toJson())),
      'dataCollectionInterval': dataCollectionInterval,
      'alertsEnabled': alertsEnabled,
      'thresholds': thresholds,
    };
  }
}

// @JsonSerializable()
class SensorConfig {
  final String type;
  final String mqttTopic;
  final bool enabled;
  final double minValue;
  final double maxValue;
  final String unit;

  const SensorConfig({
    required this.type,
    required this.mqttTopic,
    this.enabled = true,
    required this.minValue,
    required this.maxValue,
    required this.unit,
  });

  factory SensorConfig.fromJson(Map<String, dynamic> json) {
    return SensorConfig(
      type: json['type'] as String,
      mqttTopic: json['mqttTopic'] as String,
      enabled: json['enabled'] as bool? ?? true,
      minValue: (json['minValue'] as num).toDouble(),
      maxValue: (json['maxValue'] as num).toDouble(),
      unit: json['unit'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'mqttTopic': mqttTopic,
      'enabled': enabled,
      'minValue': minValue,
      'maxValue': maxValue,
      'unit': unit,
    };
  }
}
