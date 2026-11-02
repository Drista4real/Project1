import 'package:project_one/core/network/backend_client.dart';
import 'package:project_one/features/plan/models/budget_plan_models.dart';

/// The budget engine's server contract.
///
/// The client never computes a plan figure. It renders what the deterministic
/// engine returned, exactly as ADR 0009 requires.
abstract interface class BudgetPlanRepository {
  Future<List<BudgetPlan>> plans({bool activeOnly});

  Future<BudgetPlan> plan(int planId);

  Future<List<DailyAllocation>> allocations(int planId);

  Future<PurchaseImpact> purchaseImpact({
    required int planId,
    required int currentDay,
    required num amount,
    String groupKey,
    String? category,
  });
}

class BackendBudgetPlanRepository implements BudgetPlanRepository {
  BackendBudgetPlanRepository({BackendClient? client})
    : client = client ?? BackendClient();

  final BackendClient client;

  @override
  Future<List<BudgetPlan>> plans({bool activeOnly = false}) async {
    final response =
        await client.request(
              'GET',
              '/budget-plans?active=$activeOnly&limit=50',
            )
            as Map<String, dynamic>;
    final items = (response['items'] as List?) ?? const [];
    return items
        .map((item) => BudgetPlan.fromJson((item as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<BudgetPlan> plan(int planId) async {
    final response =
        await client.request('GET', '/budget-plans/$planId')
            as Map<String, dynamic>;
    final plan = (response['plan'] as Map?)?.cast<String, dynamic>() ?? const {};
    return BudgetPlan.fromJson(plan);
  }

  @override
  Future<List<DailyAllocation>> allocations(int planId) async {
    final response =
        await client.request('GET', '/budget-plans/$planId/allocations')
            as Map<String, dynamic>;
    final items = (response['items'] as List?) ?? const [];
    return items
        .map(
          (item) =>
              DailyAllocation.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  @override
  Future<PurchaseImpact> purchaseImpact({
    required int planId,
    required int currentDay,
    required num amount,
    String groupKey = 'lifestyle',
    String? category,
  }) async {
    final body = <String, dynamic>{
      'plan_id': planId,
      'current_day': currentDay,
      'amount': amount.toStringAsFixed(2),
      'group_key': groupKey,
    };
    if (category != null) body['category'] = category;
    final response =
        await client.request(
              'POST',
              '/budget-plans/$planId/purchase-impact',
              body: body,
            )
            as Map<String, dynamic>;
    return PurchaseImpact.fromJson(response);
  }
}
