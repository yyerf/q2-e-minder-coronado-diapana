import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config/app_config.dart';

MqttClient createMqttClient() {
  return MqttServerClient.withPort(
    AppConfig.mqttBrokerUrl,
    AppConfig.mqttClientId,
    AppConfig.mqttPort,
  );
}
