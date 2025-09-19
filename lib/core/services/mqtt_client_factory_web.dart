import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import '../config/app_config.dart';

MqttClient createMqttClient() {
  final url =
      'ws://${AppConfig.mqttBrokerUrl}:${AppConfig.mqttWebsocketPort}${AppConfig.mqttWebsocketPath}';
  return MqttBrowserClient(url, AppConfig.mqttClientId);
}
