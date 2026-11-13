import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/core/network/backend_client.dart';
import 'package:project_one/features/plan/data/budget_plan_repository.dart';
import 'package:project_one/features/plan/models/budget_plan_models.dart';
import 'package:project_one/features/plan/screens/plan_screen.dart';
import 'package:project_one/features/plan/widgets/plan_calendar.dart';

final _start = DateTime(2026, 11, 12);
final _today = DateTime(2026, 11, 14);

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

  /// 23 days of 178.261 ₫: 152k spent on day 1, 210k (over) on day 2 and 45k
  /// so far today, day 3.
  @override
  Future<List<DailyAllocation>> allocations(int planId) async => [
    for (var day = 1; day <= 23; day++) ...[
      DailyAllocation(
        dayIndex: day,
        allocDate: _start.add(Duration(days: day - 1)),
        groupKey: 'food',
        pillar: 'needs',
        amount: 106957,
        actualSpent: const {1: 100000, 2: 150000, 3: 45000, 4: 50000}[day] ?? 0,
      ),
      DailyAllocation(
        dayIndex: day,
        allocDate: _start.add(Duration(days: day - 1)),
        groupKey: 'lifestyle',
        pillar: 'wants',
        amount: 71304,
        actualSpent: const {1: 52000, 2: 60000}[day] ?? 0,
      ),
    ],
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

  @override
  Future<PlanPreview> preview(PlanDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<BudgetPlan> create(PlanDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<SetupDefaults> setupDefaults() async => throw UnimplementedError();
}

BudgetPlan _plan() => BudgetPlan(
  id: 42,
  title: 'Kế hoạch tháng',
  status: 'ACTIVE',
  totalIncome: 8000000,
  durationDays: 23,
  savingsTarget: 800000,
  fixedExpenses: 3100000,
  startDate: _start,
  spendableBudget: 4100000,
  dailyAllowance: 178261,
  survivalFloor: 134783,
  planVersion: 1,
  configVersion: 'budget-engine-v1',
  groups: const [
    PlanGroup(
      groupKey: 'food',
      pillar: 'needs',
      dailyAmount: 106957,
      totalAmount: 2460000,
    ),
    PlanGroup(
      groupKey: 'lifestyle',
      pillar: 'wants',
      dailyAmount: 71304,
      totalAmount: 1640000,
    ),
  ],
);

Future<void> _pumpPlan(
  WidgetTester tester,
  BudgetPlanRepository repository,
) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: PlanScreen(repository: repository, today: _today)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the calendar shows what was spent on every day', (tester) async {
    await _pumpPlan(tester, FakeBudgetPlanRepository(activePlan: _plan()));

    expect(find.text('Tháng 11, 2026'), findsOneWidget);
    expect(find.text('152k'), findsOneWidget);
    expect(find.text('210k'), findsOneWidget);
    expect(find.text('45k'), findsOneWidget);
    // A day still ahead shows the planned limit.
    expect(find.text('178k'), findsWidgets);
    expect(
      find.bySemanticsLabel(RegExp(r'Ngày 13/11, đã chi 210\.000 ₫')),
      findsOneWidget,
    );
  });

  testWidgets('a future day already spent shows the spending', (tester) async {
    await _pumpPlan(tester, FakeBudgetPlanRepository(activePlan: _plan()));

    expect(find.text('50k'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Ngày 15/11, đã chi 50\.000 ₫')),
      findsOneWidget,
    );
  });

  testWidgets('the summary shows what is left for today', (tester) async {
    await _pumpPlan(tester, FakeBudgetPlanRepository(activePlan: _plan()));

    expect(find.text('133.261 ₫'), findsOneWidget);
    expect(find.text('hôm nay còn được chi'), findsOneWidget);
    expect(find.textContaining('NGÀY 3/23'), findsOneWidget);
  });

  testWidgets('tapping a day shows its spending by group', (tester) async {
    await _pumpPlan(tester, FakeBudgetPlanRepository(activePlan: _plan()));

    expect(find.text('Thứ Bảy, 14/11 · Hôm nay'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-day-13/11')));
    await tester.pumpAndSettle();

    expect(find.text('Thứ Sáu, 13/11'), findsOneWidget);
    expect(find.text('210.000 ₫ / 178.261 ₫'), findsOneWidget);
    expect(find.text('150.000 ₫ / 106.957 ₫'), findsOneWidget);
  });

  testWidgets('the group limits stay below the calendar', (tester) async {
    await _pumpPlan(tester, FakeBudgetPlanRepository(activePlan: _plan()));

    await tester.scrollUntilVisible(find.text('Hạn mức theo nhóm chi'), 200);
    expect(find.text('Hạn mức theo nhóm chi'), findsOneWidget);
    expect(find.text('106.957 ₫/ngày'), findsOneWidget);
  });

  testWidgets('the plan screen only asks for active plans', (tester) async {
    final repository = FakeBudgetPlanRepository(activePlan: _plan());
    await _pumpPlan(tester, repository);

    expect(repository.loadedPlans, [1]);
  });

  testWidgets('without a plan the screen offers the monthly setup', (
    tester,
  ) async {
    await _pumpPlan(tester, FakeBudgetPlanRepository());

    expect(find.text('Chưa có kế hoạch chi tiêu'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Thiết lập kế hoạch tháng'),
      findsOneWidget,
    );
  });

  testWidgets('a failing load reports the error', (tester) async {
    await _pumpPlan(tester, _FailingRepository());

    expect(find.text('Không tải được kế hoạch'), findsOneWidget);
    expect(find.text('Máy chủ đang bận'), findsOneWidget);
  });

  group('planDays', () {
    test('sums the groups of a day into its limit and spending', () async {
      final allocations = await FakeBudgetPlanRepository().allocations(42);
      final days = planDays(_plan(), allocations);

      expect(days, hasLength(23));
      final second = days[DateTime(2026, 11, 13)]!;
      expect(second.dayIndex, 2);
      expect(second.limit, 178261);
      expect(second.spent, 210000);
      expect(second.overLimit, isTrue);
    });

    test('falls back to the start date when a row has no date', () {
      final days = planDays(_plan(), const [
        DailyAllocation(
          dayIndex: 3,
          allocDate: null,
          groupKey: 'food',
          pillar: 'needs',
          amount: 1000,
          actualSpent: 0,
        ),
      ]);

      expect(days.keys.single, DateTime(2026, 11, 14));
    });
  });

  test('formatCompactVnd keeps a cell short', () {
    expect(formatCompactVnd(0), '0đ');
    expect(formatCompactVnd(500), '500đ');
    expect(formatCompactVnd(152000), '152k');
    expect(formatCompactVnd(178261), '178k');
    expect(formatCompactVnd(1000000), '1tr');
    expect(formatCompactVnd(1200000), '1,2tr');
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

  @override
  Future<PlanPreview> preview(PlanDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<BudgetPlan> create(PlanDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<SetupDefaults> setupDefaults() async => throw UnimplementedError();
}
