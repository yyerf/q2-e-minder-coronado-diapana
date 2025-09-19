class SensorData {
  final String id;
  final String carId;
  final String sensorType;
  final double value;
  final String unit;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const SensorData({
    required this.id,
    required this.carId,
    required this.sensorType,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.metadata,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      id: json['id'] as String,
      carId: json['carId'] as String,
      sensorType: json['sensorType'] as String,
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'carId': carId,
      'sensorType': sensorType,
      'value': value,
      'unit': unit,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  SensorData copyWith({
    String? id,
    String? carId,
    String? sensorType,
    double? value,
    String? unit,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return SensorData(
      id: id ?? this.id,
      carId: carId ?? this.carId,
      sensorType: sensorType ?? this.sensorType,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
}

enum ComponentType {
  battery,
  alternator,
  starter,
  sensor,
  ecu,
  lighting,
  ignition,
  other
}

enum ComponentStatus {
  healthy,
  warning,
  critical,
  failed,
  maintenance
}

class MaintenanceHistory {
  final DateTime lastMaintenance;
  final String description;
  final double cost;
  final String? mechanicId;

  const MaintenanceHistory({
    required this.lastMaintenance,
    required this.description,
    required this.cost,
    this.mechanicId,
  });

  factory MaintenanceHistory.fromJson(Map<String, dynamic> json) {
    return MaintenanceHistory(
      lastMaintenance: DateTime.parse(json['lastMaintenance'] as String),
      description: json['description'] as String,
      cost: (json['cost'] as num).toDouble(),
      mechanicId: json['mechanicId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lastMaintenance': lastMaintenance.toIso8601String(),
      'description': description,
      'cost': cost,
      'mechanicId': mechanicId,
    };
  }
}

class CarElectronics {
  final String id;
  final String carId;
  final String componentName;
  final ComponentType type;
  final ComponentStatus status;
  final double healthScore; // 0-100
  final DateTime lastChecked;
  final DateTime? predictedFailureDate;
  final List<String> issues;
  final MaintenanceHistory? maintenanceHistory;

  const CarElectronics({
    required this.id,
    required this.carId,
    required this.componentName,
    required this.type,
    required this.status,
    required this.healthScore,
    required this.lastChecked,
    this.predictedFailureDate,
    required this.issues,
    this.maintenanceHistory,
  });

  factory CarElectronics.fromJson(Map<String, dynamic> json) {
    return CarElectronics(
      id: json['id'] as String,
      carId: json['carId'] as String,
      componentName: json['componentName'] as String,
      type: ComponentType.values.firstWhere(
        (e) => e.toString() == 'ComponentType.${json['type']}',
      ),
      status: ComponentStatus.values.firstWhere(
        (e) => e.toString() == 'ComponentStatus.${json['status']}',
      ),
      healthScore: (json['healthScore'] as num).toDouble(),
      lastChecked: DateTime.parse(json['lastChecked'] as String),
      predictedFailureDate: json['predictedFailureDate'] != null
          ? DateTime.parse(json['predictedFailureDate'] as String)
          : null,
      issues: List<String>.from(json['issues'] as List),
      maintenanceHistory: json['maintenanceHistory'] != null
          ? MaintenanceHistory.fromJson(json['maintenanceHistory'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'carId': carId,
      'componentName': componentName,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'healthScore': healthScore,
      'lastChecked': lastChecked.toIso8601String(),
      'predictedFailureDate': predictedFailureDate?.toIso8601String(),
      'issues': issues,
      'maintenanceHistory': maintenanceHistory?.toJson(),
    };
  }
}
