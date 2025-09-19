import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BottomNavScaffold extends StatelessWidget {
  final Widget child;

  const BottomNavScaffold({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getSelectedIndex(currentPath),
        onTap: (index) => _onItemTapped(context, index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.speed),
            label: 'Monitor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'E-Waste',
          ),
        ],
      ),
    );
  }

  int _getSelectedIndex(String path) {
    switch (path) {
      case '/dashboard':
        return 0;
      case '/monitoring':
        return 1;
      case '/alerts':
        return 2;
      case '/maps':
        return 3;
      default:
        return 0;
    }
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/monitoring');
        break;
      case 2:
        context.go('/alerts');
        break;
      case 3:
        context.go('/maps');
        break;
    }
  }
}
