import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:mqtt_client/mqtt_client.dart';

import '../../../../core/models/battery_health.dart';
import '../../../../core/models/battery_alert.dart';
import '../../../../core/services/battery_monitor_service.dart';
import '../../../../core/services/mqtt_service.dart';

class MonitoringPage extends ConsumerStatefulWidget {
  const MonitoringPage({super.key});

  @override
  ConsumerState<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends ConsumerState<MonitoringPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String selectedCarId = 'car_1';
  Duration selectedPeriod = const Duration(hours: 24);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batteryHealth = ref.watch(batteryHealthStreamProvider(selectedCarId));
    final batteryHistory = ref.watch(batteryHistoryProvider(selectedCarId));
    final connectionState = ref.watch(mqttConnectionStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Battery Monitor'),
        elevation: 0,
        actions: [
          _buildConnectionIndicator(connectionState),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshData(),
          ),
          PopupMenuButton<Duration>(
            icon: const Icon(Icons.schedule),
            onSelected: (period) => setState(() => selectedPeriod = period),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: Duration(hours: 1),
                child: Text('Last Hour'),
              ),
              const PopupMenuItem(
                value: Duration(hours: 6),
                child: Text('Last 6 Hours'),
              ),
              const PopupMenuItem(
                value: Duration(hours: 24),
                child: Text('Last 24 Hours'),
              ),
              const PopupMenuItem(
                value: Duration(days: 7),
                child: Text('Last Week'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Live'),
            Tab(icon: Icon(Icons.show_chart), text: 'History'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLiveMonitoringTab(batteryHealth),
          _buildHistoryTab(batteryHistory),
          _buildAnalyticsTab(),
        ],
      ),
    );
  }

  Widget _buildConnectionIndicator(
      AsyncValue<MqttConnectionState> connectionState) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: connectionState.when(
        data: (state) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: state == MqttConnectionState.connected
                    ? Colors.green
                    : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              state == MqttConnectionState.connected ? 'Live' : 'Offline',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        loading: () => const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (_, __) => const Icon(Icons.error, color: Colors.red, size: 16),
      ),
    );
  }

  Widget _buildLiveMonitoringTab(
      AsyncValue<BatteryHealth?> batteryHealthAsync) {
    return batteryHealthAsync.when(
      data: (batteryHealth) {
        if (batteryHealth == null) {
          return _buildNoDataState();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRealTimeMonitoringSection(batteryHealth),
              const SizedBox(height: 16),
              _buildBatteryStatusCard(batteryHealth),
              const SizedBox(height: 16),
              _buildVitalStatsGrid(batteryHealth),
              const SizedBox(height: 16),
              _buildRecommendationCard(batteryHealth),
              const SizedBox(height: 16),
              _buildRecentAlertsSection(),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(error.toString()),
    );
  }

  Widget _buildBatteryStatusCard(BatteryHealth health) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: health.status.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    health.status.icon,
                    color: health.status.color,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${health.voltage.toStringAsFixed(2)}V',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: health.status.color,
                            ),
                      ),
                      Text(
                        health.status.displayName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: health.status.color,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      Text(
                        health.batteryType.toUpperCase(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildProgressIndicator(
                    'Charge',
                    health.soc,
                    '%',
                    health.status.color,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildProgressIndicator(
                    'Health',
                    health.soh,
                    '%',
                    _getHealthColor(health.soh),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(
      String label, double value, String unit, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)}$unit',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: value / 100,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ],
    );
  }

  Widget _buildVitalStatsGrid(BatteryHealth health) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vital Statistics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Voltage',
              '${health.voltage.toStringAsFixed(2)}V',
              Icons.flash_on,
              health.status.color,
            ),
            _buildStatCard(
              'State of Charge',
              '${health.soc.toStringAsFixed(1)}%',
              Icons.battery_charging_full,
              health.status.color,
            ),
            _buildStatCard(
              'State of Health',
              '${health.soh.toStringAsFixed(1)}%',
              Icons.favorite,
              _getHealthColor(health.soh),
            ),
            _buildStatCard(
              'Est. Runtime',
              health.estimatedHours != null
                  ? '${health.estimatedHours!.toStringAsFixed(1)}h'
                  : 'N/A',
              Icons.schedule,
              Colors.blue,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(BatteryHealth health) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: Colors.amber,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recommendation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              health.recommendation,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Last updated: ${_formatTimestamp(health.timestamp)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAlertsSection() {
    final alerts = ref
        .watch(activeAlertsProvider)
        .where((alert) => alert.carId == selectedCarId)
        .take(3)
        .toList();

    if (alerts.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'No active alerts',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Alerts',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ...alerts.map((alert) => _buildAlertCard(alert)),
      ],
    );
  }

  Widget _buildAlertCard(BatteryAlert alert) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: alert.severity.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            alert.type.icon,
            color: alert.severity.color,
          ),
        ),
        title: Text(
          alert.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(alert.message),
        trailing: !alert.isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () => _handleAlertTap(alert),
      ),
    );
  }

  Widget _buildHistoryTab(List<BatteryHealth> history) {
    if (history.isEmpty) {
      return _buildNoDataState();
    }

    final filteredHistory = history.where((h) {
      final cutoff = DateTime.now().subtract(selectedPeriod);
      return h.timestamp.isAfter(cutoff);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: 16),
          _buildVoltageChart(filteredHistory),
          const SizedBox(height: 16),
          _buildChargeHealthChart(filteredHistory),
          const SizedBox(height: 16),
          _buildHistoryList(filteredHistory),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final service = ref.read(batteryMonitorServiceProvider);
    final analytics =
        service.getBatteryAnalytics(selectedCarId, period: selectedPeriod);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analytics Overview',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildAnalyticsGrid(analytics),
          const SizedBox(height: 16),
          _buildTrendAnalysis(analytics),
          const SizedBox(height: 16),
          _buildPerformanceMetrics(analytics),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        Text(
          'Period: ${_formatPeriod(selectedPeriod)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => _showPeriodSelector(),
          icon: const Icon(Icons.tune),
          label: const Text('Change'),
        ),
      ],
    );
  }

  Widget _buildVoltageChart(List<BatteryHealth> history) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voltage History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < history.length) {
                            return Text(
                              DateFormat.Hm().format(history[index].timestamp),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(1)}V',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: history.asMap().entries.map((entry) {
                        return FlSpot(
                            entry.key.toDouble(), entry.value.voltage);
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChargeHealthChart(List<BatteryHealth> history) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Charge & Health Trends',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < history.length) {
                            return Text(
                              DateFormat.Hm().format(history[index].timestamp),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: history.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.soc);
                      }).toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: history.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.soh);
                      }).toList(),
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Charge (SOC)', Colors.green),
                const SizedBox(width: 16),
                _buildLegendItem('Health (SOH)', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 2,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildHistoryList(List<BatteryHealth> history) {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Detailed History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.take(10).length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final health = history.reversed.toList()[index];
              return ListTile(
                leading: Icon(
                  health.status.icon,
                  color: health.status.color,
                ),
                title: Text('${health.voltage.toStringAsFixed(2)}V'),
                subtitle: Text(
                  'SOC: ${health.soc.toStringAsFixed(1)}% | SOH: ${health.soh.toStringAsFixed(1)}%',
                ),
                trailing: Text(
                  _formatTimestamp(health.timestamp),
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsGrid(Map<String, dynamic> analytics) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildAnalyticsCard(
          'Avg Voltage',
          '${analytics['averageVoltage']?.toStringAsFixed(2) ?? '0.00'}V',
          Icons.flash_on,
          Colors.blue,
        ),
        _buildAnalyticsCard(
          'Avg Charge',
          '${analytics['averageSOC']?.toStringAsFixed(1) ?? '0.0'}%',
          Icons.battery_charging_full,
          Colors.green,
        ),
        _buildAnalyticsCard(
          'Avg Health',
          '${analytics['averageSOH']?.toStringAsFixed(1) ?? '0.0'}%',
          Icons.favorite,
          _getHealthColor(analytics['averageSOH'] as double? ?? 0.0),
        ),
        _buildAnalyticsCard(
          'Data Points',
          '${analytics['dataPoints'] ?? 0}',
          Icons.data_usage,
          Colors.grey,
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendAnalysis(Map<String, dynamic> analytics) {
    final trend = analytics['healthTrend'] as String? ?? 'stable';
    final trendColor = trend == 'improving'
        ? Colors.green
        : trend == 'declining'
            ? Colors.red
            : Colors.grey;
    final trendIcon = trend == 'improving'
        ? Icons.trending_up
        : trend == 'declining'
            ? Icons.trending_down
            : Icons.trending_flat;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trend Analysis',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(trendIcon, color: trendColor),
                const SizedBox(width: 8),
                Text(
                  'Battery health is ${trend}',
                  style: TextStyle(
                    color: trendColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Based on ${analytics['dataPoints'] ?? 0} data points over ${analytics['period']?.toString() ?? 'unknown period'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetrics(Map<String, dynamic> analytics) {
    final voltageRange = analytics['voltageRange'] as Map<String, dynamic>? ??
        {'min': 0.0, 'max': 0.0};

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Metrics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildMetricRow('Voltage Range',
                '${voltageRange['min']?.toStringAsFixed(2) ?? '0.00'} - ${voltageRange['max']?.toStringAsFixed(2) ?? '0.00'}V'),
            _buildMetricRow('Analysis Period',
                analytics['period']?.toString() ?? 'Unknown'),
            _buildMetricRow(
                'Data Quality',
                (analytics['dataPoints'] as int? ?? 0) > 10
                    ? 'Good'
                    : 'Limited'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.battery_unknown,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No battery data available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your battery monitor to start collecting data',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Connection'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading battery data',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.red[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // Helper methods
  void _refreshData() {
    // Trigger a manual update of the battery data
    final batteryMonitorService = ref.read(batteryMonitorServiceProvider);
    batteryMonitorService.updateBatteryHealth(selectedCarId, {
      'voltage': -0.00,
      'soc': 0.0,
      'soh': 30.0,
      'status': 'dead',
      'recommendation':
          'Battery is dead, replace immediately. Estimated time: 0.0h',
      'estimated_hours': 0.0,
      'battery_type': '9V',
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Trigger a refresh of the data providers
    ref.invalidate(batteryHealthStreamProvider(selectedCarId));
    ref.invalidate(batteryHistoryProvider(selectedCarId));
    ref.invalidate(mqttConnectionStateProvider);
  }

  Color _getHealthColor(double health) {
    if (health >= 80) return Colors.green;
    if (health >= 60) return Colors.orange;
    return Colors.red;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM dd, HH:mm').format(timestamp);
    }
  }

  String _formatPeriod(Duration period) {
    if (period.inDays >= 1) {
      return '${period.inDays} day${period.inDays > 1 ? 's' : ''}';
    } else {
      return '${period.inHours} hour${period.inHours > 1 ? 's' : ''}';
    }
  }

  void _handleAlertTap(BatteryAlert alert) {
    ref.read(batteryMonitorServiceProvider).markAlertAsRead(alert.id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(alert.type.icon, color: alert.severity.color),
            const SizedBox(width: 8),
            Expanded(child: Text(alert.title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.message),
            const SizedBox(height: 12),
            Text(
              'Time: ${_formatTimestamp(alert.timestamp)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (alert.data != null) ...[
              const SizedBox(height: 8),
              Text(
                'Data: ${alert.data.toString()}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPeriodSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Time Period',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...[
              const Duration(hours: 1),
              const Duration(hours: 6),
              const Duration(hours: 24),
              const Duration(days: 7),
            ].map((period) => ListTile(
                  title: Text(_formatPeriod(period)),
                  trailing: selectedPeriod == period
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() => selectedPeriod = period);
                    Navigator.of(context).pop();
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeMonitoringSection(BatteryHealth health) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Real-time Monitoring',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Connected',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: const Text(
                'Ping',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Real-time monitoring cards removed as requested
      ],
    );
  }
}
