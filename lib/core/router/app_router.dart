import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/screens/app_screens.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';

abstract final class AppRoutes {
  static const ledger = '/';
  static const reports = '/reports';
  static const budget = '/budget';
  static const settings = '/settings';
  static const addTransaction = '/add-transaction';
  static const aiQuickInput = '/ai-quick-input';
  static const forecast = '/forecast';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.ledger,
  routes: [
    GoRoute(
      path: AppRoutes.ledger,
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.reports,
      builder: (context, state) => const ReportsScreen(),
    ),
    GoRoute(
      path: AppRoutes.budget,
      builder: (context, state) => const BudgetScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.addTransaction,
      builder: (context, state) => const AiQuickInputScreen(),
    ),
    GoRoute(
      path: AppRoutes.aiQuickInput,
      builder: (context, state) => const AiQuickInputScreen(),
    ),
    GoRoute(
      path: AppRoutes.forecast,
      builder: (context, state) => const Scaffold(
        appBar: AppScreenHeader(subtitle: 'Dự Báo'),
        body: CashflowForecastScreen(),
        bottomNavigationBar: AppScreenNavigation(selectedIndex: 1),
      ),
    ),
  ],
);
