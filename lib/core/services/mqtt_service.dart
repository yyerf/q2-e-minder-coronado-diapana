import 'dart:async';
import 'dart:convert';
// no dart:io here to stay web-safe
import 'package:mqtt_client/mqtt_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'mqtt_client_factory.dart';
import '../models/sensor_data.dart';

final mqttServiceProvider = Provider<MqttService>((ref) {
  final service = MqttService();
  ref.onDispose(service.dispose);
  return service;
});

final sensorDataStreamProvider =
    StreamProvider.family<SensorData, String>((ref, carId) {
  final mqttService = ref.watch(mqttServiceProvider);
  return mqttService.getSensorDataStream(carId);
});

final mqttConnectionStateProvider = StreamProvider<MqttConnectionState>((ref) {
  final mqttService = ref.watch(mqttServiceProvider);
  return mqttService.connectionStateStream;
});

class MqttService {
  late MqttClient
      _client; // Use platform-specific factory instead of direct imports
  final Map<String, StreamController<SensorData>> _dataControllers = {};
  bool _isConnected = false;
  final _connectionController =
      StreamController<MqttConnectionState>.broadcast();

  // Callback for battery health data processing
  void Function(String carId, Map<String, dynamic> healthData)?
      onBatteryHealthReceived;

  MqttService() {
    _initializeClient();
  }

  void _initializeClient() {
    _client = createMqttClient();

    _client.logging(on: false);
    _client.keepAlivePeriod = 20;
    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;
    _client.onSubscribed = _onSubscribed;
  }

  Future<bool> connect() async {
    try {
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(AppConfig.mqttClientId)
          .withWillTopic('willtopic')
          .withWillMessage('Client disconnected unexpectedly')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      _client.connectionMessage = connMessage;

      if (AppConfig.mqttUsername != null && AppConfig.mqttPassword != null) {
        await _client.connect(AppConfig.mqttUsername, AppConfig.mqttPassword);
      } else {
        await _client.connect();
      }
      return _isConnected;
    } catch (e) {
      print('MQTT Connection failed: $e');
      _client.disconnect();
      return false;
    }
  }

  void disconnect() {
    _client.disconnect();
    _closeAllStreams();
  }

  void _onConnected() {
    print('MQTT Connected');
    _isConnected = true;
    _connectionController.add(MqttConnectionState.connected);
  }

  void _onDisconnected() {
    print('MQTT Disconnected');
    _isConnected = false;
    _connectionController.add(MqttConnectionState.disconnected);
  }

  void _onSubscribed(String topic) {
    print('Subscribed to topic: $topic');
  }

  Future<void> subscribeToCarSensors(String carId) async {
    if (!_isConnected) {
      final connected = await connect();
      if (!connected) return;
    }

    final topics = [
      AppConfig.voltageTopicPattern.replaceAll('{carId}', carId),
      AppConfig.temperatureTopicPattern.replaceAll('{carId}', carId),
      AppConfig.batteryTopicPattern.replaceAll('{carId}', carId),
      AppConfig.batteryHealthTopicPattern.replaceAll('{carId}', carId),
      AppConfig.alternatorTopicPattern.replaceAll('{carId}', carId),
    ];

    for (final topic in topics) {
      _client.subscribe(topic, MqttQos.atMostOnce);
    }

    // Set up message listener
    _client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final message in messages) {
        final payload = MqttPublishPayload.bytesToStringAsString(
          (message.payload as MqttPublishMessage).payload.message,
        );
        _handleIncomingMessage(message.topic, payload, carId);
      }
    });
  }

  void _handleIncomingMessage(String topic, String payload, String carId) {
    try {
      final data = json.decode(payload) as Map<String, dynamic>;

      // Determine sensor type based on topic
      String sensorType = 'unknown';
      if (topic.contains('voltage')) {
        sensorType = 'voltage';
      } else if (topic.contains('temperature')) {
        sensorType = 'temperature';
      } else if (topic.contains('battery/health')) {
        // Battery health data from Raspberry Pi monitoring script
        // Process comprehensive health data and emit individual sensor updates
        final now = DateTime.now();

        // Emit individual sensor data for dashboard compatibility
        if (data['voltage'] != null) {
          _emitSensor(
            carId: carId,
            type: 'voltage',
            value: (data['voltage'] as num).toDouble(),
            unit: 'V',
            ts: now,
            metadata: data,
          );
        }
        if (data['soc'] != null) {
          _emitSensor(
            carId: carId,
            type: 'battery',
            value: (data['soc'] as num).toDouble(),
            unit: '%',
            ts: now,
            metadata: data,
          );
        }

        // Process battery health data through battery monitor service
        if (onBatteryHealthReceived != null) {
          onBatteryHealthReceived!(carId, data);
        }

        return;
      } else if (topic.contains('battery')) {
        sensorType = 'battery';
      } else if (topic.contains('alternator')) {
        sensorType = 'alternator';
      }

      final sensorData = SensorData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        carId: carId,
        sensorType: sensorType,
        value: (data['value'] as num).toDouble(),
        unit: data['unit'] as String? ?? '',
        timestamp: DateTime.now(),
        metadata: data['metadata'] as Map<String, dynamic>?,
      );

      // Send to appropriate stream
      if (_dataControllers.containsKey(carId)) {
        _dataControllers[carId]!.add(sensorData);
      }
    } catch (e) {
      print('Error parsing MQTT message: $e');
    }
  }

  void _emitSensor({
    required String carId,
    required String type,
    required double value,
    required String unit,
    required DateTime ts,
    Map<String, dynamic>? metadata,
  }) {
    if (_dataControllers.containsKey(carId)) {
      _dataControllers[carId]!.add(
        SensorData(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          carId: carId,
          sensorType: type,
          value: value,
          unit: unit,
          timestamp: ts,
          metadata: metadata,
        ),
      );
    }
  }

  Stream<SensorData> getSensorDataStream(String carId) {
    if (!_dataControllers.containsKey(carId)) {
      _dataControllers[carId] = StreamController<SensorData>.broadcast();

      if (AppConfig.useMockMqtt) {
        // For demo purposes, generate mock sensor data every 5 seconds
        _startMockDataGeneration(carId);
      } else {
        // Subscribe to real topics
        // fire and forget
        subscribeToCarSensors(carId);
      }
    }
    return _dataControllers[carId]!.stream;
  }

  void _startMockDataGeneration(String carId) {
    // Generate mock sensor data for demo
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_dataControllers.containsKey(carId)) {
        timer.cancel();
        return;
      }

      final sensorTypes = ['voltage', 'temperature', 'battery', 'alternator'];
      final units = ['V', '°C', '%', 'A'];
      final baseValues = [12.0, 65.0, 85.0, 14.0];

      for (int i = 0; i < sensorTypes.length; i++) {
        final variation = (DateTime.now().millisecond % 100 - 50) / 50.0;
        final value = baseValues[i] + variation * 2;

        final sensorData = SensorData(
          id: DateTime.now().millisecondsSinceEpoch.toString() + '_$i',
          carId: carId,
          sensorType: sensorTypes[i],
          value: value,
          unit: units[i],
          timestamp: DateTime.now(),
        );

        _dataControllers[carId]!.add(sensorData);
      }
    });
  }

  Future<void> sendCommand(
      String carId, String command, Map<String, dynamic> params) async {
    if (!_isConnected) return;

    final topic = 'car/$carId/commands';
    final payload = json.encode({
      'command': command,
      'params': params,
      'timestamp': DateTime.now().toIso8601String(),
    });

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  Future<void> sendPing(String carId) async {
    if (!_isConnected) {
      final connected = await connect();
      if (!connected) return;
    }
    final topic = 'car/$carId/app/ping';
    final payload = json.encode({
      'msg': 'hello-from-app',
      'ts': DateTime.now().toIso8601String(),
    });
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void _closeAllStreams() {
    for (final controller in _dataControllers.values) {
      controller.close();
    }
    _dataControllers.clear();
  }

  bool get isConnected => _isConnected;

  Stream<MqttConnectionState> get connectionStateStream =>
      _connectionController.stream;

  void dispose() {
    _closeAllStreams();
    _connectionController.close();
    if (_isConnected) {
      _client.disconnect();
    }
  }
}
