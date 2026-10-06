import 'package:go_router/go_router.dart';
import 'package:project_one/app/app_routes.dart';
import 'package:project_one/features/ledger/screens/ledger_screen.dart';
import 'package:project_one/features/reports/screens/reports_screen.dart';
import 'package:project_one/features/budget/screens/budget_screen.dart';
import 'package:project_one/features/settings/screens/settings_screen.dart';
import 'package:project_one/features/transactions/screens/quick_add_transaction_screen.dart';
import 'package:project_one/features/ai/screens/ai_quick_input_screen.dart';
import 'package:project_one/features/forecast/screens/cashflow_forecast_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.ledger,
  routes: [
    GoRoute(
      path: AppRoutes.ledger,
      builder: (context, state) => const LedgerScreen(),
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
      builder: (context, state) => const QuickAddTransactionScreen(),
    ),
    GoRoute(
      path: AppRoutes.aiQuickInput,
      builder: (context, state) => const AiQuickInputScreen(),
    ),
    GoRoute(
      path: AppRoutes.forecast,
      builder: (context, state) => const ForecastPage(),
    ),
  ],
);
