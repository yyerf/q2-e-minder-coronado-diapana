import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/battery_monitor_service.dart';
import '../../../features/alerts/presentation/pages/alerts_page.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadAlertsCountProvider);
    final activeAlerts = ref.watch(activeAlertsProvider);

    // Determine notification color based on alert severity
    Color iconColor = Colors.grey[600]!;
    if (activeAlerts.any((alert) => alert.severity.value == 'critical')) {
      iconColor = Colors.red;
    } else if (activeAlerts.any((alert) => alert.severity.value == 'warning')) {
      iconColor = Colors.orange;
    } else if (unreadCount > 0) {
      iconColor = Colors.blue;
    }

    return Stack(
      children: [
        IconButton(
          icon: Icon(
            unreadCount > 0 || activeAlerts.isNotEmpty
                ? Icons.notifications_active
                : Icons.notifications_none,
            color: iconColor,
          ),
          onPressed: () => _navigateToAlerts(context),
          tooltip: unreadCount > 0
              ? '$unreadCount unread alert${unreadCount > 1 ? 's' : ''}'
              : 'Notifications',
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _navigateToAlerts(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AlertsPage(),
      ),
    );
  }
}

class AnimatedNotificationBell extends ConsumerStatefulWidget {
  const AnimatedNotificationBell({super.key});

  @override
  ConsumerState<AnimatedNotificationBell> createState() =>
      _AnimatedNotificationBellState();
}

class _AnimatedNotificationBellState
    extends ConsumerState<AnimatedNotificationBell>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late AnimationController _pulseController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _pulseAnimation;

  int _previousUnreadCount = 0;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadAlertsCountProvider);
    final activeAlerts = ref.watch(activeAlertsProvider);

    // Trigger animations when new alerts arrive
    if (unreadCount > _previousUnreadCount) {
      _triggerNewAlertAnimation();
    }
    _previousUnreadCount = unreadCount;

    // Check for critical alerts to start pulsing
    final hasCriticalAlerts = activeAlerts
        .any((alert) => alert.severity.value == 'critical' && !alert.isRead);

    if (hasCriticalAlerts && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!hasCriticalAlerts && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    // Determine notification color based on alert severity
    Color iconColor = Colors.grey[600]!;
    if (activeAlerts.any((alert) => alert.severity.value == 'critical')) {
      iconColor = Colors.red;
    } else if (activeAlerts.any((alert) => alert.severity.value == 'warning')) {
      iconColor = Colors.orange;
    } else if (unreadCount > 0) {
      iconColor = Colors.blue;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_shakeAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Transform.rotate(
            angle: _shakeAnimation.value * 0.3,
            child: Stack(
              children: [
                IconButton(
                  icon: Icon(
                    unreadCount > 0 || activeAlerts.isNotEmpty
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                    color: iconColor,
                  ),
                  onPressed: () => _navigateToAlerts(context),
                  tooltip: unreadCount > 0
                      ? '$unreadCount unread alert${unreadCount > 1 ? 's' : ''}'
                      : 'Notifications',
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: iconColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _triggerNewAlertAnimation() {
    _shakeController.forward().then((_) {
      _shakeController.reset();
    });
  }

  void _navigateToAlerts(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AlertsPage(),
      ),
    );
  }
}
