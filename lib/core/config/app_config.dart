import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static late SharedPreferences _prefs;

  // MQTT Configuration
  // Set to your Raspberry Pi broker host/IP (e.g., 'raspberrypi.local' or '192.168.1.50')
  static String mqttBrokerUrl = '192.168.88.252';
  static int mqttPort = 1883;
  // Toggle to generate mock MQTT data instead of connecting to broker
  static bool useMockMqtt = false;
  // Each device needs a unique MQTT client ID. We'll generate one on first run and persist it.
  static late String mqttClientId;
  static const String mqttClientIdPrefix = 'flutter_iot_ewaste';
  static String? mqttUsername;
  static String? mqttPassword;
  // WebSocket settings for web (Chrome) builds
  static int mqttWebsocketPort = 9001; // typical Mosquitto WS port
  static String mqttWebsocketPath = '/';

  // Topic patterns for different sensors
  static const String voltageTopicPattern = 'car/{carId}/voltage';
  static const String temperatureTopicPattern = 'car/{carId}/temperature';
  static const String batteryTopicPattern = 'car/{carId}/battery';
  // Raspberry Pi publisher often uses a nested battery/health topic
  static const String batteryHealthTopicPattern = 'car/{carId}/battery/health';
  static const String alternatorTopicPattern = 'car/{carId}/alternator';

  // Firebase Configuration
  static const String firestoreUsersCollection = 'users';
  static const String firestoreCarsCollection = 'cars';
  static const String firestoreSensorDataCollection = 'sensor_data';
  static const String firestoreEWasteLocationsCollection = 'ewaste_locations';

  // Google Maps API
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // Prediction Thresholds
  static const double lowVoltageThreshold = 11.5; // Volts
  static const double highTemperatureThreshold = 80.0; // Celsius
  static const double criticalBatteryLevel = 20.0; // Percentage

  // Cache durations
  static const Duration cacheRefreshInterval = Duration(minutes: 5);
  static const Duration dataRetentionPeriod = Duration(days: 30);

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    // Allow overriding MQTT settings via SharedPreferences (optional)
    mqttBrokerUrl = _prefs.getString('mqtt_broker_url') ?? mqttBrokerUrl;
    mqttPort = _prefs.getInt('mqtt_port') ?? mqttPort;
    useMockMqtt = _prefs.getBool('mqtt_use_mock') ?? useMockMqtt;
    mqttWebsocketPort = _prefs.getInt('mqtt_ws_port') ?? mqttWebsocketPort;
    mqttWebsocketPath = _prefs.getString('mqtt_ws_path') ?? mqttWebsocketPath;
    mqttUsername = _prefs.getString('mqtt_username');
    mqttPassword = _prefs.getString('mqtt_password');

    // Ensure a unique, stable client ID per installation
    mqttClientId = _prefs.getString('mqtt_client_id') ?? _generateClientId();
    // Persist if newly generated
    await _prefs.setString('mqtt_client_id', mqttClientId);
  }

  static SharedPreferences get prefs => _prefs;

  // Helper methods for storing user preferences
  static Future<void> setThemeMode(String mode) async {
    await _prefs.setString('theme_mode', mode);
  }

  static String getThemeMode() {
    return _prefs.getString('theme_mode') ?? 'system';
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool('notifications_enabled', enabled);
  }

  static bool getNotificationsEnabled() {
    return _prefs.getBool('notifications_enabled') ?? true;
  }

  // Optional setters so you can change at runtime and persist
  static Future<void> setMqttSettings(
      {String? brokerUrl, int? port, bool? useMock}) async {
    if (brokerUrl != null) {
      mqttBrokerUrl = brokerUrl;
      await _prefs.setString('mqtt_broker_url', brokerUrl);
    }
    if (port != null) {
      mqttPort = port;
      await _prefs.setInt('mqtt_port', port);
    }
    if (useMock != null) {
      useMockMqtt = useMock;
      await _prefs.setBool('mqtt_use_mock', useMock);
    }
  }

  static Future<void> setMqttWebsocketSettings(
      {int? port, String? path}) async {
    if (port != null) {
      mqttWebsocketPort = port;
      await _prefs.setInt('mqtt_ws_port', port);
    }
    if (path != null) {
      mqttWebsocketPath = path;
      await _prefs.setString('mqtt_ws_path', path);
    }
  }

  static Future<void> setMqttCredentials(
      {String? username, String? password}) async {
    if (username != null) {
      mqttUsername = username;
      await _prefs.setString('mqtt_username', username);
    }
    if (password != null) {
      mqttPassword = password;
      await _prefs.setString('mqtt_password', password);
    }
  }

  // Generates a unique client ID with a short random suffix, e.g., flutter_iot_ewaste_ab12cd34
  static String _generateClientId() {
    const chars = 'abcdef0123456789';
    final rand = Random.secure();
    String randomHex(int length) =>
        List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
    return '${mqttClientIdPrefix}_${randomHex(8)}';
  }
}
