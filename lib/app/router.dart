import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/shell_screen.dart';
import '../screens/home_screen.dart';
import '../screens/add_transaction_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/budget_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/onboarding_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/transactions', builder: (_, __) => const TransactionsScreen()),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
          GoRoute(path: '/budget', builder: (_, __) => const BudgetScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: '/add',
        builder: (_, __) => const AddTransactionScreen(),
      ),
    ],
  );
});
