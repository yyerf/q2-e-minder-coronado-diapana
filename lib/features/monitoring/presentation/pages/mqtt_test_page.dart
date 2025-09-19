import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/mqtt_service.dart';
import '../../../../core/config/app_config.dart';

class MqttTestPage extends ConsumerWidget {
  final String carId;
  const MqttTestPage({super.key, required this.carId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(mqttConnectionStateProvider);
    final stream = ref.watch(sensorDataStreamProvider(carId));

    return Scaffold(
      appBar: AppBar(title: const Text('MQTT Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Broker: ${AppConfig.mqttBrokerUrl}:${AppConfig.mqttPort}'),
            const SizedBox(height: 8),
            conn.when(
              data: (s) => Row(
                children: [
                  const Text('Status: '),
                  Text(s.toString().split('.').last, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              loading: () => const Text('Status: connecting...'),
              error: (e, _) => Text('Status: error $e'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await ref.read(mqttServiceProvider).connect();
                    await ref.read(mqttServiceProvider).subscribeToCarSensors(carId);
                  },
                  child: const Text('Connect + Subscribe'),
                ),
                OutlinedButton(
                  onPressed: () => ref.read(mqttServiceProvider).sendPing(carId),
                  child: const Text('Send Ping'),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text('Last message as sensor data:'),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: stream.when(
                  data: (d) => Text('${d.sensorType}: ${d.value} ${d.unit}\n@ ${d.timestamp}'),
                  loading: () => const Text('Waiting for data...'),
                  error: (e, _) => Text('Error: $e'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
