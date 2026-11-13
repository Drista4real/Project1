import 'package:project_one/core/network/backend_client.dart';
import 'package:project_one/features/plan/data/budget_plan_repository.dart';
import 'package:project_one/features/plan/models/budget_plan_models.dart';

/// The engine's answer for 8.000.000 ₫ over 23 days with 3.100.000 ₫ fixed
/// and 10% saved: 4.100.000 ₫ spendable, 178.261 ₫ a day.
const setupPreview = PlanPreview(
  spendableBudget: 4100000,
  dailyAllowance: 178260.87,
  survivalFloor: 134782.61,
  groups: [
    PlanGroup(
      groupKey: 'food',
      pillar: 'needs',
      dailyAmount: 106956.52,
      totalAmount: 2460000,
    ),
    PlanGroup(
      groupKey: 'transport',
      pillar: 'needs',
      dailyAmount: 26739.13,
      totalAmount: 615000,
    ),
    PlanGroup(
      groupKey: 'lifestyle',
      pillar: 'wants',
      dailyAmount: 44565.22,
      totalAmount: 1025000,
    ),
  ],
);

class FakeSetupRepository implements BudgetPlanRepository {
  FakeSetupRepository({
    this.defaults,
    this.failDefaults = false,
    this.previewError,
    this.existingPlans = const [],
  });

  final SetupDefaults? defaults;
  final bool failDefaults;
  final String? previewError;
  final List<BudgetPlan> existingPlans;

  final List<PlanDraft> previews = [];
  final List<PlanDraft> created = [];

  @override
  Future<SetupDefaults> setupDefaults() async {
    if (failDefaults) throw const FinanceApiException('offline');
    return defaults ??
        SetupDefaults(
          availableBalance: 8000000,
          nextIncomeDate: DateTime(2026, 12, 5),
          nextIncomeSource: 'payroll_day',
          nextIncomeLabel: null,
          fixedExpenses: [
            SetupFixedExpense(
              description: 'Tiền nhà',
              amount: 2500000,
              nextDate: DateTime(2026, 12, 1),
            ),
            const SetupFixedExpense(description: 'Điện nước', amount: 600000),
          ],
          monthlySavingsTarget: 0,
          hasPlans: false,
        );
  }

  @override
  Future<PlanPreview> preview(PlanDraft draft) async {
    previews.add(draft);
    final error = previewError;
    if (error != null) throw FinanceApiException(error);
    return setupPreview;
  }

  @override
  Future<BudgetPlan> create(PlanDraft draft) async {
    created.add(draft);
    return BudgetPlan(
      id: 7,
      title: 'Kế hoạch tháng',
      status: 'ACTIVE',
      totalIncome: draft.totalIncome,
      durationDays: draft.durationDays,
      savingsTarget: draft.savingsTarget,
      fixedExpenses: draft.fixedExpenses,
      startDate: draft.startDate,
      spendableBudget: setupPreview.spendableBudget,
      dailyAllowance: setupPreview.dailyAllowance,
      survivalFloor: setupPreview.survivalFloor,
      planVersion: 1,
      configVersion: 'budget-engine-v1',
      groups: setupPreview.groups,
    );
  }

  @override
  Future<List<BudgetPlan>> plans({bool activeOnly = false}) async =>
      existingPlans;

  @override
  Future<BudgetPlan> plan(int planId) async => throw UnimplementedError();

  @override
  Future<List<DailyAllocation>> allocations(int planId) async => const [];

  @override
  Future<PurchaseImpact> purchaseImpact({
    required int planId,
    required int currentDay,
    required num amount,
    String groupKey = 'lifestyle',
    String? category,
  }) async => throw UnimplementedError();
}
