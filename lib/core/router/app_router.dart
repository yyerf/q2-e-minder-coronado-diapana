import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/monitoring/presentation/pages/monitoring_page.dart';
import '../../features/alerts/presentation/pages/alerts_page.dart';
import '../../features/maps/presentation/pages/maps_page.dart';
// import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/monitoring/presentation/pages/mqtt_test_page.dart';
import '../../shared/presentation/widgets/bottom_nav_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding', // Start at onboarding
    routes: [
      // Onboarding (entry) - outside shell
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      // Authentication routes (kept for potential future use, but not accessible)
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),

      // Main App with Bottom Navigation
      ShellRoute(
        builder: (context, state, child) => BottomNavScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) {
              return CustomTransitionPage(
                key: state.pageKey,
                transitionDuration: const Duration(milliseconds: 420),
                child: const DashboardPage(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  final curve = Curves.easeInOutCubic;
                  final fade = Tween(begin: 0.0, end: 1.0)
                      .chain(CurveTween(curve: curve))
                      .animate(animation);
                  final slide =
                      Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                          .chain(CurveTween(curve: curve))
                          .animate(animation);
                  final scale = Tween(begin: 0.98, end: 1.0)
                      .chain(CurveTween(curve: curve))
                      .animate(animation);

                  return FadeTransition(
                    opacity: fade,
                    child: SlideTransition(
                      position: slide,
                      child: ScaleTransition(
                        scale: scale,
                        child: child,
                      ),
                    ),
                  );
                },
              );
            },
          ),
          GoRoute(
            path: '/mqtt-test/:carId',
            builder: (context, state) => MqttTestPage(
                carId: state.pathParameters['carId'] ?? 'default-car'),
          ),
          GoRoute(
            path: '/monitoring',
            builder: (context, state) => const MonitoringPage(),
          ),
          GoRoute(
            path: '/alerts',
            builder: (context, state) => const AlertsPage(),
          ),
          GoRoute(
            path: '/maps',
            builder: (context, state) => const MapsPage(),
          ),
        ],
      ),
    ],
  );
});
