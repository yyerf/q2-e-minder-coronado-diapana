import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mqtt_client/mqtt_client.dart';

import '../../../../core/services/firebase_service.dart';
import '../../../../core/services/mqtt_service.dart';
import '../../../../core/services/battery_monitor_service.dart';
import '../../../../core/models/sensor_data.dart';
import '../../../../core/models/battery_health.dart';
import '../../../../core/models/battery_alert.dart';
import '../../../../shared/presentation/widgets/sensor_card.dart';
import '../../../../shared/widgets/notification_bell.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  String? selectedCarId;
  String? _lastAlertIdShown;

  void _maybeShowNewAlertPopup(List<BatteryAlert> alerts) {
    if (alerts.isEmpty) return;
    final newest = alerts.first; // alerts stored newest first
    if (_lastAlertIdShown == newest.id) return; // already shown

    _lastAlertIdShown = newest.id;

    final isCritical = newest.severity == AlertSeverity.critical;
    final bg = isCritical
        ? Colors.red.shade700
        : (newest.severity == AlertSeverity.warning
            ? Colors.orange.shade700
            : Theme.of(context).colorScheme.inverseSurface);

    final snackBar = SnackBar(
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(newest.title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            newest.message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      action: SnackBarAction(
        label: 'VIEW',
        textColor: Colors.white,
        onPressed: () {
          // TODO: navigate to alerts page when implemented
        },
      ),
    );

    // Ensure only one snackbar at a time
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(snackBar);
  }

  @override
  void initState() {
    super.initState();
    // Set up battery health data callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mqttService = ref.read(mqttServiceProvider);
      final batteryService = ref.read(batteryMonitorServiceProvider);

      mqttService.onBatteryHealthReceived = (carId, healthData) {
        batteryService.updateBatteryHealth(carId, healthData);
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final userCars = ref.watch(userCarsProvider);
    // Listen for alert list changes; schedule check after build to avoid setState in build
    ref.listen(alertsStreamProvider, (previous, next) {
      final value = next.valueOrNull;
      if (mounted && value != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _maybeShowNewAlertPopup(value));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          const AnimatedNotificationBell(),
          IconButton(
            tooltip: 'MQTT Test',
            icon: const Icon(Icons.wifi_tethering),
            onPressed: () {
              final id = selectedCarId ?? 'default-car';
              context.push('/mqtt-test/$id');
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              final service = ref.read(batteryMonitorServiceProvider);
              final id = selectedCarId ?? 'car_1';
              switch (value) {
                case 'clear_history_car':
                  service.clearHistory(id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cleared history for car')),
                  );
                  break;
                case 'clear_history_all':
                  service.clearAllHistory();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cleared all history')),
                  );
                  break;
                case 'reset_analytics_24h':
                  service.resetAnalyticsWindow(keep: const Duration(hours: 24));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kept last 24h of data')),
                  );
                  break;
                case 'reset_analytics_all':
                  service.resetAnalyticsWindow(keep: const Duration());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Analytics reset')),
                  );
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'clear_history_car',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_sweep),
                  title: Text('Clear History (this car)'),
                ),
              ),
              PopupMenuItem(
                value: 'clear_history_all',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_forever),
                  title: Text('Clear History (all)'),
                ),
              ),
              PopupMenuItem(
                value: 'reset_analytics_24h',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.refresh),
                  title: Text('Keep last 24h only'),
                ),
              ),
              PopupMenuItem(
                value: 'reset_analytics_all',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.restore_from_trash),
                  title: Text('Reset analytics'),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(userCarsProvider);
            },
          ),
        ],
      ),
      body: userCars.when(
        data: (cars) {
          if (cars.isEmpty) {
            return const _EmptyDashboard();
          }

          // Select first car if none selected
          selectedCarId ??= cars.first.id;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CarSelector(
                  cars: cars,
                  selectedCarId: selectedCarId!,
                  onCarSelected: (carId) {
                    setState(() {
                      selectedCarId = carId;
                    });
                  },
                ),
                // Space for real-time alert snackbars is handled by ScaffoldMessenger; this comment left intentionally.
                const SizedBox(height: 20),
                _RealTimeMonitoring(carId: selectedCarId!),
                const SizedBox(height: 20),
                _RecentAlerts(carId: selectedCarId!),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(userCarsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            'No Cars Registered',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          const Text(
            'Add your first car to start monitoring',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to add car page
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Car'),
          ),
        ],
      ),
    );
  }
}

class _CarSelector extends StatelessWidget {
  final List cars;
  final String selectedCarId;
  final Function(String) onCarSelected;

  const _CarSelector({
    required this.cars,
    required this.selectedCarId,
    required this.onCarSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Vehicle',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedCarId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: cars.map((car) {
                return DropdownMenuItem<String>(
                  value: car.id,
                  child: Text(car.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  onCarSelected(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RealTimeMonitoring extends ConsumerWidget {
  final String carId;

  const _RealTimeMonitoring({required this.carId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensorDataStream = ref.watch(sensorDataStreamProvider(carId));
    final conn = ref.watch(mqttConnectionStateProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sensors, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Real-time Monitoring',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                conn.when(
                  data: (state) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: state == MqttConnectionState.connected
                              ? Colors.green
                              : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        state == MqttConnectionState.connected
                            ? 'Connected'
                            : 'Disconnected',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  loading: () => const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) =>
                      const Text('Conn?', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(mqttServiceProvider).sendPing(carId);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(60, 32),
                    ),
                    child: const Text('Ping', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            sensorDataStream.when(
              data: (sensorData) => _buildSensorGrid(context, sensorData),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text('Error: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorGrid(BuildContext context, SensorData latestData) {
    return Consumer(
      builder: (context, ref, child) {
        final batteryService = ref.watch(batteryMonitorServiceProvider);
        final batteryHealth = batteryService.getCurrentBatteryHealth(carId);

        // Use fallback values if no battery health data available
        final voltage = batteryHealth?.voltage ?? -0.00;
        final soc = batteryHealth?.soc ?? 0.0;
        final soh = batteryHealth?.soh ?? 30.0;
        final status = batteryHealth?.status ?? BatteryStatus.dead;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            SensorCard(
              title: 'Voltage',
              value: '${voltage.toStringAsFixed(2)}',
              unit: 'V',
              icon: Icons.flash_on,
              color: _getVoltageColor(voltage),
            ),
            SensorCard(
              title: 'Battery SOC',
              value: '${soc.toStringAsFixed(1)}',
              unit: '%',
              icon: Icons.battery_std,
              color: _getBatteryColor(soc),
            ),
            SensorCard(
              title: 'Battery Health',
              value: '${soh.toStringAsFixed(1)}',
              unit: '%',
              icon: Icons.health_and_safety,
              color: _getBatteryHealthColor(soh),
            ),
            SensorCard(
              title: 'Status',
              value: status.displayName,
              unit: '',
              icon: status.icon,
              color: status.color,
            ),
          ],
        );
      },
    );
  }

  Color _getVoltageColor(double voltage) {
    if (voltage < 11.5) return Colors.red;
    if (voltage < 12.0) return Colors.orange;
    return Colors.green;
  }

  Color _getBatteryColor(double battery) {
    if (battery < 20) return Colors.red;
    if (battery < 50) return Colors.orange;
    return Colors.green;
  }

  Color _getBatteryHealthColor(double health) {
    if (health < 40) return Colors.red;
    if (health < 70) return Colors.orange;
    return Colors.green;
  }
}

class _RecentAlerts extends ConsumerWidget {
  final String carId;

  const _RecentAlerts({required this.carId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsStreamProvider);
    final activeAlerts = alertsAsync.valueOrNull ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Recent Alerts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    // Navigate to alerts page
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (alertsAsync.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (activeAlerts.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'No recent alerts',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...activeAlerts
                  .take(3)
                  .map((alert) => _buildAlertItem(
                        alert.title,
                        alert.message,
                        _formatAlertTime(alert.timestamp),
                        _getAlertColor(alert.severity.value),
                      ))
                  .toList(),
          ],
        ),
      ),
    );
  }

  String _formatAlertTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Color _getAlertColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildAlertItem(
      String title, String description, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
