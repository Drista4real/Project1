import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/core/network/backend_client.dart';
import 'package:project_one/features/plan/data/budget_plan_repository.dart';
import 'package:project_one/features/plan/models/budget_plan_models.dart';
import 'package:project_one/features/plan/screens/plan_screen.dart';

class FakeBudgetPlanRepository implements BudgetPlanRepository {
  FakeBudgetPlanRepository({this.activePlan});

  BudgetPlan? activePlan;
  final List<int> loadedPlans = [];

  @override
  Future<List<BudgetPlan>> plans({bool activeOnly = false}) async {
    loadedPlans.add(activeOnly ? 1 : 0);
    final value = activePlan;
    return value == null ? const [] : [value];
  }

  @override
  Future<BudgetPlan> plan(int planId) async => activePlan!;

  @override
  Future<List<DailyAllocation>> allocations(int planId) async => const [
    DailyAllocation(
      dayIndex: 1,
      allocDate: null,
      groupKey: 'food',
      pillar: 'needs',
      amount: 60000,
      actualSpent: 20000,
    ),
    DailyAllocation(
      dayIndex: 1,
      allocDate: null,
      groupKey: 'lifestyle',
      pillar: 'wants',
      amount: 25000,
      actualSpent: 0,
    ),
  ];

  @override
  Future<PurchaseImpact> purchaseImpact({
    required int planId,
    required int currentDay,
    required num amount,
    String groupKey = 'lifestyle',
    String? category,
  }) async => PurchaseImpact(
    level: 'SAFE',
    planId: planId,
    dailyAllowanceNow: 100000,
    dailyAllowanceAfter: 95000,
    survivalFloor: 50000,
    remainingDays: 28,
    reason: 'Vẫn trong hạn mức.',
  );
}

BudgetPlan _plan() => BudgetPlan(
  id: 42,
  title: 'Kế hoạch chi tiêu',
  status: 'ACTIVE',
  totalIncome: 8000000,
  durationDays: 30,
  savingsTarget: 2000000,
  fixedExpenses: 3000000,
  startDate: DateTime.now(),
  spendableBudget: 3000000,
  dailyAllowance: 100000,
  survivalFloor: 50000,
  planVersion: 1,
  configVersion: 'budget-engine-v1',
  groups: const [
    PlanGroup(
      groupKey: 'food',
      pillar: 'needs',
      dailyAmount: 60000,
      totalAmount: 1800000,
    ),
    PlanGroup(
      groupKey: 'transport',
      pillar: 'needs',
      dailyAmount: 15000,
      totalAmount: 450000,
    ),
    PlanGroup(
      groupKey: 'lifestyle',
      pillar: 'wants',
      dailyAmount: 25000,
      totalAmount: 750000,
    ),
  ],
);

void main() {
  testWidgets('the plan screen shows the daily allowance and the groups', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlanScreen(
          repository: FakeBudgetPlanRepository(activePlan: _plan()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('100.000 ₫'), findsWidgets);
    expect(find.text('Phân bổ theo trụ cột'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Ăn uống'), 200);
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.text('Chi tiêu linh hoạt'), findsOneWidget);
  });

  testWidgets('the plan screen only asks for active plans', (tester) async {
    final repository = FakeBudgetPlanRepository(activePlan: _plan());
    await tester.pumpWidget(
      MaterialApp(home: PlanScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(repository.loadedPlans, [1]);
  });

  testWidgets('without a plan the screen points to the assistant', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PlanScreen(repository: FakeBudgetPlanRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có kế hoạch chi tiêu'), findsOneWidget);
    expect(find.text('Mở trợ lý'), findsOneWidget);
  });

  testWidgets('a failing load reports the error', (tester) async {
    final repository = _FailingRepository();
    await tester.pumpWidget(
      MaterialApp(home: PlanScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không tải được kế hoạch'), findsOneWidget);
    expect(find.text('Máy chủ đang bận'), findsOneWidget);
  });
}

class _FailingRepository implements BudgetPlanRepository {
  @override
  Future<List<BudgetPlan>> plans({bool activeOnly = false}) async {
    throw const FinanceApiException('Máy chủ đang bận');
  }

  @override
  Future<BudgetPlan> plan(int planId) async => throw UnimplementedError();

  @override
  Future<List<DailyAllocation>> allocations(int planId) async =>
      throw UnimplementedError();

  @override
  Future<PurchaseImpact> purchaseImpact({
    required int planId,
    required int currentDay,
    required num amount,
    String groupKey = 'lifestyle',
    String? category,
  }) async => throw UnimplementedError();
}
