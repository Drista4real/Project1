import 'package:project_one/core/config/supabase_config.dart';
import 'package:project_one/features/plan/data/budget_plan_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Decides whether the monthly setup opens by itself after sign-in.
abstract interface class MonthlySetupGate {
  /// True for a signed-in user with no plan who was never prompted here.
  Future<bool> shouldAutoOpen();

  /// Remember that the setup opened, so skipping it is not asked again.
  Future<void> markPrompted();
}

/// The gate backed by the user's plans and a flag on this device.
///
/// The flag lives on the device (ADR 0001 keeps device settings local), so a
/// reinstall may prompt a user without a plan one more time.
class LocalMonthlySetupGate implements MonthlySetupGate {
  LocalMonthlySetupGate({
    BudgetPlanRepository? repository,
    String? Function()? userId,
  }) : repository = repository ?? BackendBudgetPlanRepository(),
       userId = userId ?? _currentUserId;

  final BudgetPlanRepository repository;
  final String? Function() userId;

  static String? _currentUserId() {
    try {
      return SupabaseConfig.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  String _key(String id) => 'monthly_setup_prompted_$id';

  @override
  Future<bool> shouldAutoOpen() async {
    final id = userId();
    if (id == null) return false;
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_key(id)) ?? false) return false;
    final plans = await repository.plans(activeOnly: false);
    return plans.isEmpty;
  }

  @override
  Future<void> markPrompted() async {
    final id = userId();
    if (id == null) return;
    await (await SharedPreferences.getInstance()).setBool(_key(id), true);
  }
}
