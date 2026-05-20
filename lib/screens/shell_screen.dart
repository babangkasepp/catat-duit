import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellScreen extends StatelessWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  static const _tabs = [
    (route: '/', icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
    (route: '/transactions', icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Transaksi'),
    (route: '/reports', icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, label: 'Laporan'),
    (route: '/budget', icon: Icons.savings_outlined, selectedIcon: Icons.savings, label: 'Budget'),
    (route: '/settings', icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Setelan'),
  ];

  int _currentIndex(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].route == location) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final idx = _currentIndex(location);

    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add'),
        icon: const Icon(Icons.add),
        label: const Text('Catat'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(_tabs[i].route),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
