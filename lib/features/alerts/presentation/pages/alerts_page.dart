import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/battery_alert.dart';
import '../../../../core/services/battery_monitor_service.dart';

class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});

  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(alertsStreamProvider);
    final alerts = alertsAsync.valueOrNull ?? const <BatteryAlert>[];
    final unreadCount = alerts.where((a) => !a.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.notifications),
            const SizedBox(width: 8),
            const Text('Alerts'),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
                _showUnreadOnly ? Icons.mark_email_read : Icons.filter_list),
            onPressed: () => setState(() => _showUnreadOnly = !_showUnreadOnly),
            tooltip: _showUnreadOnly ? 'Show All' : 'Show Unread Only',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read),
                    SizedBox(width: 8),
                    Text('Mark All as Read'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear All Alerts'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.priority_high),
                  const SizedBox(width: 4),
                  const Text('Critical'),
                  if (alertsAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (_getCriticalAlertsCount(alerts) > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_getCriticalAlertsCount(alerts)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.list),
                  const SizedBox(width: 4),
                  const Text('All'),
                  if (alertsAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (alerts.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${alerts.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          if (alertsAsync.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildCriticalAlertsTab(alerts),
          if (alertsAsync.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildAllAlertsTab(alerts),
        ],
      ),
    );
  }

  Widget _buildCriticalAlertsTab(List<BatteryAlert> allAlerts) {
    final criticalAlerts = allAlerts
        .where((alert) => alert.severity == AlertSeverity.critical)
        .toList();

    if (criticalAlerts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: 'No Critical Alerts',
        subtitle: 'Your battery systems are operating normally',
        color: Colors.green,
      );
    }

    return _buildAlertsList(criticalAlerts);
  }

  Widget _buildAllAlertsTab(List<BatteryAlert> alerts) {
    List<BatteryAlert> filteredAlerts = alerts;

    if (_showUnreadOnly) {
      filteredAlerts = alerts.where((alert) => !alert.isRead).toList();
    }

    if (filteredAlerts.isEmpty) {
      if (_showUnreadOnly) {
        return _buildEmptyState(
          icon: Icons.mark_email_read,
          title: 'No Unread Alerts',
          subtitle: 'All alerts have been read',
          color: Colors.blue,
        );
      } else {
        return _buildEmptyState(
          icon: Icons.notifications_none,
          title: 'No Alerts',
          subtitle: 'No alerts to display at this time',
          color: Colors.grey,
        );
      }
    }

    return _buildAlertsList(filteredAlerts);
  }

  Widget _buildAlertsList(List<BatteryAlert> alerts) {
    // Group alerts by date
    final groupedAlerts = <String, List<BatteryAlert>>{};
    for (final alert in alerts) {
      final dateKey = DateFormat('yyyy-MM-dd').format(alert.timestamp);
      groupedAlerts.putIfAbsent(dateKey, () => []).add(alert);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedAlerts.length,
      itemBuilder: (context, index) {
        final dateKey = groupedAlerts.keys.elementAt(index);
        final dateAlerts = groupedAlerts[dateKey]!;
        final date = DateTime.parse(dateKey);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateHeader(date),
            const SizedBox(height: 8),
            ...dateAlerts.map((alert) => _buildAlertCard(alert)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1;

    String dateText;
    if (isToday) {
      dateText = 'Today';
    } else if (isYesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('MMMM dd, yyyy').format(date);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        dateText,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildAlertCard(BatteryAlert alert) {
    return Card(
      elevation: alert.isRead ? 1 : 3,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _handleAlertTap(alert),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: !alert.isRead
                ? Border.all(color: alert.severity.color, width: 2)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: alert.severity.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    alert.type.icon,
                    color: alert.severity.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              alert.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: alert.isRead
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildSeverityBadge(alert.severity),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimestamp(alert.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          const Spacer(),
                          if (!alert.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: alert.severity.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityBadge(AlertSeverity severity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: severity.color.withOpacity(0.1),
        border: Border.all(color: severity.color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        severity.displayName.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: severity.color,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: color.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  int _getCriticalAlertsCount(List<BatteryAlert> alerts) {
    return alerts
        .where((alert) => alert.severity == AlertSeverity.critical)
        .length;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(timestamp);
    }
  }

  void _handleAlertTap(BatteryAlert alert) {
    // Mark alert as read
    ref.read(batteryMonitorServiceProvider).markAlertAsRead(alert.id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(alert.type.icon, color: alert.severity.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                alert.title,
                style: TextStyle(color: alert.severity.color),
              ),
            ),
            _buildSeverityBadge(alert.severity),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.message,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Occurred: ${DateFormat('MMM dd, yyyy \'at\' HH:mm').format(alert.timestamp)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              if (alert.data != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Technical Details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                ...alert.data!.entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              '${entry.key}:',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value.toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (!alert.isRead)
            ElevatedButton(
              onPressed: () {
                ref
                    .read(batteryMonitorServiceProvider)
                    .markAlertAsRead(alert.id);
                Navigator.of(context).pop();
              },
              child: const Text('Mark as Read'),
            ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    final service = ref.read(batteryMonitorServiceProvider);

    switch (action) {
      case 'mark_all_read':
        service.markAllAlertsAsRead();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All alerts marked as read')),
        );
        break;
      case 'clear_all':
        _showClearAllConfirmation();
        break;
    }
  }

  void _showClearAllConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Alerts'),
        content: const Text(
          'Are you sure you want to clear all alerts? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(batteryMonitorServiceProvider).clearAllAlerts();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All alerts cleared')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
