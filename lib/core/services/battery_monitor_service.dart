import 'dart:async';
import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../models/battery_health.dart';
import '../models/battery_alert.dart';

final batteryMonitorServiceProvider = Provider<BatteryMonitorService>((ref) {
  final service = BatteryMonitorService();
  ref.onDispose(service.dispose);
  return service;
});

final batteryHealthStreamProvider =
    StreamProvider.family<BatteryHealth?, String>((ref, carId) {
  final service = ref.watch(batteryMonitorServiceProvider);
  return service.getBatteryHealthStream(carId);
});

final batteryHistoryProvider =
    Provider.family<List<BatteryHealth>, String>((ref, carId) {
  final service = ref.watch(batteryMonitorServiceProvider);
  return service.getBatteryHistory(carId);
});

final activeAlertsProvider = Provider<List<BatteryAlert>>((ref) {
  final service = ref.watch(batteryMonitorServiceProvider);
  return service.getActiveAlerts();
});

final unreadAlertsCountProvider = Provider<int>((ref) {
  final service = ref.watch(batteryMonitorServiceProvider);
  return service.getUnreadAlertsCount();
});

final alertsStreamProvider = StreamProvider<List<BatteryAlert>>((ref) {
  final service = ref.watch(batteryMonitorServiceProvider);
  return service.alertsStream;
});

class BatteryMonitorService {
  final Map<String, StreamController<BatteryHealth?>> _healthControllers = {};
  final Map<String, Queue<BatteryHealth>> _batteryHistory = {};
  final List<BatteryAlert> _alerts = [];
  final Map<String, BatteryHealth?> _currentHealth = {};
  final StreamController<List<BatteryAlert>> _alertsController =
      StreamController<List<BatteryAlert>>.broadcast();
  void _emitAlerts() {
    if (!_alertsController.isClosed) {
      _alertsController.add(List<BatteryAlert>.unmodifiable(_alerts));
    }
  }

  static const int maxHistoryEntries = 1000; // Keep last 1000 readings
  static const int maxAlerts = 100; // Keep last 100 alerts

  // Alert thresholds
  static const double criticalVoltageThreshold9V = 6.5;
  static const double lowVoltageThreshold9V = 7.5;
  static const double criticalVoltageThreshold12V = 11.5;
  static const double lowVoltageThreshold12V = 12.0;
  static const double healthDegradationThreshold = 70.0;
  // Ultra-low disposable threshold (regardless of battery type)
  static const double disposableVoltageThreshold =
      4.5; // <=4.5V -> disposable alert
  static const double disposableRecoveryMargin =
      0.2; // Must rise above (threshold + margin) to allow a new disposable alert
  // Sudden drop detection
  static const Duration suddenDropWindow = Duration(seconds: 30);
  static const double suddenDropDelta = 1.0; // V
  // Swap detection (good battery suddenly replaced with bad/very low one)
  static const double swapDropVoltageThreshold = 5.0; // If new reading <= 5.0V
  static const double goodVoltageMargin =
      0.5; // Previous must be at least (lowThreshold + margin)
  static const Duration swapDetectionMaxGap =
      Duration(minutes: 2); // Allow longer gap for physical swap

  BatteryMonitorService() {
    _startPeriodicCleanup();
    _initializeSampleHistoryData(); // Add sample data for testing
    // Emit initial empty alerts list
    _alertsController.add(const []);
    // _initializeDemoData(); // Disabled - use real MQTT data only
    // _startRealTimeUpdates(); // Disabled - use real MQTT data only
  }

  void _initializeSampleHistoryData() {
    // Create some sample historical data for testing the graphs
    final now = DateTime.now();
    const carId = 'car_1';

    final List<BatteryHealth> sampleHistory = [];

    // Generate 24 hours of sample data (1 reading per hour)
    for (int i = 24; i >= 0; i--) {
      final timestamp = now.subtract(Duration(hours: i));
      final voltage =
          7.5 + (i / 24) * 2.0; // Voltage increases from 7.5V to 9.5V
      final soc = (i / 24) * 80; // SOC from 0% to 80%
      final soh = 25 + (i / 24) * 10; // SOH from 25% to 35%

      final health = BatteryHealth(
        carId: carId,
        voltage: voltage,
        soc: soc,
        soh: soh,
        status: soc < 20
            ? BatteryStatus.dead
            : soc < 40
                ? BatteryStatus.low
                : soc < 60
                    ? BatteryStatus.weak
                    : BatteryStatus.good,
        recommendation: 'Sample historical data',
        estimatedHours: soc / 10,
        batteryType: '9V',
        timestamp: timestamp,
      );

      sampleHistory.add(health);
    }

    // Store the sample history
    if (!_batteryHistory.containsKey(carId)) {
      _batteryHistory[carId] = Queue<BatteryHealth>();
    }

    for (final health in sampleHistory) {
      _batteryHistory[carId]!.addLast(health);
    }

    // Set the latest as current health
    if (sampleHistory.isNotEmpty) {
      _currentHealth[carId] = sampleHistory.last;

      // Initialize stream controller and emit current data
      if (!_healthControllers.containsKey(carId)) {
        _healthControllers[carId] =
            StreamController<BatteryHealth?>.broadcast();
      }
      _healthControllers[carId]!.add(sampleHistory.last);
    }
  }

  Stream<BatteryHealth?> getBatteryHealthStream(String carId) {
    if (!_healthControllers.containsKey(carId)) {
      _healthControllers[carId] = StreamController<BatteryHealth?>.broadcast();
      _batteryHistory[carId] = Queue<BatteryHealth>();
    }
    return _healthControllers[carId]!.stream;
  }

  void updateBatteryHealth(String carId, Map<String, dynamic> healthData) {
    try {
      final health = BatteryHealth.fromJson({
        'carId': carId,
        ...healthData,
      });

      _currentHealth[carId] = health;

      // Add to history
      if (!_batteryHistory.containsKey(carId)) {
        _batteryHistory[carId] = Queue<BatteryHealth>();
      }

      final history = _batteryHistory[carId]!;
      history.addLast(health);

      // Limit history size
      while (history.length > maxHistoryEntries) {
        history.removeFirst();
      }

      // Check for alerts
      _checkAndCreateAlerts(health);

      // Notify listeners
      if (_healthControllers.containsKey(carId)) {
        _healthControllers[carId]!.add(health);
      }
    } catch (e) {
      print('Error updating battery health: $e');
    }
  }

  List<BatteryHealth> getBatteryHistory(String carId, {int? limit}) {
    final history = _batteryHistory[carId]?.toList() ?? [];
    if (limit != null && history.length > limit) {
      return history.reversed.take(limit).toList().reversed.toList();
    }
    return history;
  }

  List<BatteryHealth> getBatteryHistoryForTimeRange(
    String carId, {
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final history = _batteryHistory[carId]?.toList() ?? [];
    return history.where((health) {
      return health.timestamp.isAfter(startTime) &&
          health.timestamp.isBefore(endTime);
    }).toList();
  }

  BatteryHealth? getCurrentBatteryHealth(String carId) {
    return _currentHealth[carId];
  }

  void _checkAndCreateAlerts(BatteryHealth health) {
    final String batteryType = health.batteryType.toLowerCase();
    final bool is9V =
        batteryType.contains('9v') || batteryType.contains('alkaline');

    // Check for critical battery level
    final double criticalThreshold =
        is9V ? criticalVoltageThreshold9V : criticalVoltageThreshold12V;
    final double lowThreshold =
        is9V ? lowVoltageThreshold9V : lowVoltageThreshold12V;

    // Disposable (ultra-low) detection with debounce/hysteresis
    if (health.voltage <= disposableVoltageThreshold) {
      final existingDisposable = _alerts.firstWhereOrNull((a) =>
          a.carId == health.carId &&
          a.type == AlertType.batteryLow &&
          a.data?['reason'] == 'absolute_dispose_<=4_5V');
      bool recoveredSince = false;
      if (existingDisposable != null) {
        final historyList = _batteryHistory[health.carId]?.toList() ?? [];
        // Any reading AFTER the existing alert that went above threshold + margin?
        recoveredSince = historyList.any((h) =>
            h.timestamp.isAfter(existingDisposable.timestamp) &&
            h.voltage >
                (disposableVoltageThreshold + disposableRecoveryMargin));
      }
      if (existingDisposable == null || recoveredSince) {
        _addAlert(BatteryAlert.createDisposableBatteryAlert(
          carId: health.carId,
          voltage: health.voltage,
          soc: health.soc,
          batteryType: health.batteryType,
        ));
      }
    } else if (health.voltage <= criticalThreshold || health.soc <= 10) {
      _addAlert(BatteryAlert.createCriticalBatteryAlert(
        carId: health.carId,
        voltage: health.voltage,
        soc: health.soc,
        batteryType: health.batteryType,
      ));
    } else if (health.voltage <= lowThreshold || health.soc <= 25) {
      // Check if we haven't already alerted recently for low battery
      final recentLowBatteryAlert = _alerts
          .where((alert) =>
              alert.carId == health.carId &&
              alert.type == AlertType.batteryLow &&
              DateTime.now().difference(alert.timestamp).inMinutes < 30)
          .firstOrNull;

      if (recentLowBatteryAlert == null) {
        _addAlert(BatteryAlert.createLowBatteryAlert(
          carId: health.carId,
          voltage: health.voltage,
          soc: health.soc,
          batteryType: health.batteryType,
        ));
      }
    }

    // Check for health degradation
    if (health.soh <= healthDegradationThreshold) {
      final recentHealthAlert = _alerts
          .where((alert) =>
              alert.carId == health.carId &&
              alert.type == AlertType.healthDegradation &&
              DateTime.now().difference(alert.timestamp).inHours < 24)
          .firstOrNull;

      if (recentHealthAlert == null) {
        _addAlert(BatteryAlert.createHealthDegradationAlert(
          carId: health.carId,
          soh: health.soh,
          batteryType: health.batteryType,
        ));
      }
    }

    // Sudden drop detection: compare current voltage with the most recent within window
    final history = _batteryHistory[health.carId];
    if (history != null && history.length >= 2) {
      final now = health.timestamp;
      final list = history.toList();
      // Search backward for a sample within the window (exclude the last which is current)
      BatteryHealth previous = list[list.length - 2];
      for (int i = list.length - 2; i >= 0; i--) {
        if (now.difference(list[i].timestamp) <= suddenDropWindow) {
          previous = list[i];
          break;
        }
      }
      final drop = previous.voltage - health.voltage;
      // First: explicit physical swap detection (good -> very low) even if delta logic would miss
      final bool previousWasGood =
          previous.voltage >= (lowThreshold + goodVoltageMargin);
      final bool currentIsVeryLow = health.voltage <= swapDropVoltageThreshold;
      final bool withinSwapGap =
          now.difference(previous.timestamp) <= swapDetectionMaxGap;
      if (previousWasGood && currentIsVeryLow && withinSwapGap) {
        final recentSwap = _alerts.firstWhereOrNull(
          (a) =>
              a.carId == health.carId &&
              a.type == AlertType.suddenDrop &&
              a.data != null &&
              a.data!['reason'] == 'swap_detected' &&
              now.difference(a.timestamp) <= const Duration(seconds: 15),
        );
        if (recentSwap == null) {
          final swapAlert = BatteryAlert.createSuddenDropAlert(
            carId: health.carId,
            fromVoltage: previous.voltage,
            toVoltage: health.voltage,
            within: now.difference(previous.timestamp),
            batteryType: health.batteryType,
          );
          final newData = {
            ...?swapAlert.data,
            'reason': 'swap_detected',
            'detected': 'good_to_very_low',
            'previousWasGood': previous.voltage,
            'lowThreshold': lowThreshold,
            'margin': goodVoltageMargin,
          };
          _addAlert(swapAlert.copyWith(data: newData));
        }
      }
      if (drop >= suddenDropDelta) {
        // Debounce: avoid duplicate sudden-drop alerts within window
        final recentDrop = _alerts.firstWhereOrNull(
          (a) =>
              a.carId == health.carId &&
              a.type == AlertType.suddenDrop &&
              now.difference(a.timestamp) <= suddenDropWindow,
        );
        if (recentDrop == null) {
          _addAlert(BatteryAlert.createSuddenDropAlert(
            carId: health.carId,
            fromVoltage: previous.voltage,
            toVoltage: health.voltage,
            within: now.difference(previous.timestamp),
            batteryType: health.batteryType,
          ));
        }
      }
    }
  }

  // Helper for demo: simulate a swap from good battery to bad battery quickly.
  // This injects two readings: a good voltage then (after short delay) a bad one.
  Future<void> simulateBatterySwap({
    required String carId,
    double fromVoltage = 8.8,
    double toVoltage = 4.8,
    String batteryType = '9V',
  }) async {
    // Initial good reading
    updateBatteryHealth(carId, {
      'voltage': fromVoltage,
      'soc': 70.0,
      'soh': 90.0,
      'status': 'good',
      'recommendation': 'All good',
      'estimatedHours': 12.0,
      'batteryType': batteryType,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await Future.delayed(const Duration(seconds: 2));
    // Simulated swap -> very low reading
    updateBatteryHealth(carId, {
      'voltage': toVoltage,
      'soc': 10.0,
      'soh': 85.0,
      'status': 'low',
      'recommendation': 'Investigate sudden drop',
      'estimatedHours': 1.0,
      'batteryType': batteryType,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void _addAlert(BatteryAlert alert) {
    _alerts.insert(0, alert); // Add to beginning (newest first)

    // Print critical alerts to console for monitoring
    if (alert.severity == AlertSeverity.critical) {
      print('🚨 CRITICAL ALERT: ${alert.title} - ${alert.message}');
    } else if (alert.severity == AlertSeverity.warning) {
      print('⚠️ WARNING: ${alert.title} - ${alert.message}');
    } else {
      print('ℹ️ INFO: ${alert.title} - ${alert.message}');
    }

    // Limit alerts
    while (_alerts.length > maxAlerts) {
      _alerts.removeLast();
    }

    print('🚨 New Alert: ${alert.title} - ${alert.message}');

    // Broadcast updated list (send a copy to avoid external mutation)
    _emitAlerts();
  }

  List<BatteryAlert> getActiveAlerts({String? carId}) {
    if (carId != null) {
      return _alerts.where((alert) => alert.carId == carId).toList();
    }
    return List.from(_alerts);
  }

  List<BatteryAlert> getUnreadAlerts({String? carId}) {
    final alerts = getActiveAlerts(carId: carId);
    return alerts.where((alert) => !alert.isRead).toList();
  }

  int getUnreadAlertsCount({String? carId}) {
    return getUnreadAlerts(carId: carId).length;
  }

  void markAlertAsRead(String alertId) {
    final alertIndex = _alerts.indexWhere((alert) => alert.id == alertId);
    if (alertIndex != -1) {
      _alerts[alertIndex] = _alerts[alertIndex].copyWith(isRead: true);
      _emitAlerts();
    }
  }

  void markAllAlertsAsRead({String? carId}) {
    for (int i = 0; i < _alerts.length; i++) {
      if (carId == null || _alerts[i].carId == carId) {
        _alerts[i] = _alerts[i].copyWith(isRead: true);
      }
    }
    _emitAlerts();
  }

  void clearAlert(String alertId) {
    _alerts.removeWhere((alert) => alert.id == alertId);
    _emitAlerts();
  }

  void clearAllAlerts({String? carId}) {
    if (carId != null) {
      _alerts.removeWhere((alert) => alert.carId == carId);
    } else {
      _alerts.clear();
    }
    _emitAlerts();
  }

  // Analytics methods
  Map<String, dynamic> getBatteryAnalytics(String carId, {Duration? period}) {
    final DateTime endTime = DateTime.now();
    final DateTime startTime = period != null
        ? endTime.subtract(period)
        : endTime.subtract(const Duration(hours: 24));

    final historyData = getBatteryHistoryForTimeRange(
      carId,
      startTime: startTime,
      endTime: endTime,
    );

    if (historyData.isEmpty) {
      return {
        'averageVoltage': 0.0,
        'averageSOC': 0.0,
        'averageSOH': 0.0,
        'voltageRange': {'min': 0.0, 'max': 0.0},
        'healthTrend': 'stable',
        'dataPoints': 0,
        'period': '${period?.inHours ?? 24} hours',
      };
    }

    final voltages = historyData.map((h) => h.voltage).toList();
    final socs = historyData.map((h) => h.soc).toList();
    final sohs = historyData.map((h) => h.soh).toList();

    final avgVoltage = voltages.reduce((a, b) => a + b) / voltages.length;
    final avgSOC = socs.reduce((a, b) => a + b) / socs.length;
    final avgSOH = sohs.reduce((a, b) => a + b) / sohs.length;

    // Calculate trend
    String healthTrend = 'stable';
    if (historyData.length >= 10) {
      final firstHalf = sohs.take(sohs.length ~/ 2).toList();
      final secondHalf = sohs.skip(sohs.length ~/ 2).toList();
      final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
      final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

      if (secondAvg > firstAvg + 2) {
        healthTrend = 'improving';
      } else if (secondAvg < firstAvg - 2) {
        healthTrend = 'declining';
      }
    }

    return {
      'averageVoltage': double.parse(avgVoltage.toStringAsFixed(2)),
      'averageSOC': double.parse(avgSOC.toStringAsFixed(1)),
      'averageSOH': double.parse(avgSOH.toStringAsFixed(1)),
      'voltageRange': {
        'min': voltages.reduce((a, b) => a < b ? a : b),
        'max': voltages.reduce((a, b) => a > b ? a : b),
      },
      'healthTrend': healthTrend,
      'dataPoints': historyData.length,
      'period': '${period?.inHours ?? 24} hours',
    };
  }

  // Reset/Wipe methods for presentation/demo
  void clearHistory(String carId) {
    _batteryHistory[carId]?.clear();
    _healthControllers[carId]?.add(null);
    _currentHealth.remove(carId);
  }

  void clearAllHistory() {
    for (final q in _batteryHistory.values) {
      q.clear();
    }
    for (final controller in _healthControllers.values) {
      controller.add(null);
    }
    _currentHealth.clear();
  }

  void resetAnalyticsWindow({Duration keep = const Duration(hours: 0)}) {
    // Optionally keep only recent history within 'keep'
    if (keep.inSeconds <= 0) {
      clearAllHistory();
      return;
    }
    final cutoff = DateTime.now().subtract(keep);
    for (final entry in _batteryHistory.entries) {
      final q = entry.value;
      while (q.isNotEmpty && q.first.timestamp.isBefore(cutoff)) {
        q.removeFirst();
      }
      // Push latest to stream
      _healthControllers[entry.key]?.add(q.isNotEmpty ? q.last : null);
      if (q.isEmpty) _currentHealth.remove(entry.key);
    }
  }

  void _startPeriodicCleanup() {
    Timer.periodic(const Duration(hours: 1), (timer) {
      _cleanupOldData();
    });
  }

  void _cleanupOldData() {
    final cutoffTime = DateTime.now().subtract(const Duration(days: 7));

    // Clean up old history
    for (final history in _batteryHistory.values) {
      while (
          history.isNotEmpty && history.first.timestamp.isBefore(cutoffTime)) {
        history.removeFirst();
      }
    }

    // Clean up old alerts
    _alerts.removeWhere((alert) => alert.timestamp.isBefore(cutoffTime));
  }

  void dispose() {
    for (final controller in _healthControllers.values) {
      controller.close();
    }
    _healthControllers.clear();
    _batteryHistory.clear();
    _alerts.clear();
    _currentHealth.clear();
    _alertsController.close();
  }

  // Expose alerts as a reactive stream
  Stream<List<BatteryAlert>> get alertsStream => _alertsController.stream;
}
