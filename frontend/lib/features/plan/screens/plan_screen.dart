import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:project_one/app/app_routes.dart';
import 'package:project_one/app/widgets/app_screen_navigation.dart';
import 'package:project_one/features/budget/models/envelope_pillar.dart';
import 'package:project_one/features/plan/cubit/plan_cubit.dart';
import 'package:project_one/features/plan/data/budget_plan_repository.dart';
import 'package:project_one/features/plan/models/budget_plan_models.dart';
import 'package:project_one/features/plan/widgets/plan_widgets.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';

/// The plan screen: the projection of the active budget plan.
///
/// Every figure on this screen comes from the deterministic engine. The
/// screen never computes money (ADR 0009).
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, this.repository});

  final BudgetPlanRepository? repository;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late final PlanCubit _cubit = PlanCubit(
    widget.repository ?? BackendBudgetPlanRepository(),
  )..load();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<PlanCubit, PlanState>(
        builder: (context, state) => _buildContent(context, state),
      ),
    );
  }

  Widget _buildContent(BuildContext context, PlanState state) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kế hoạch chi tiêu',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: state.loading ? null : _cubit.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.loading && state.plans.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, state),
      bottomNavigationBar: const AppScreenNavigation(selectedIndex: 3),
    );
  }

  Widget _buildBody(BuildContext context, PlanState state) {
    if (state.error != null && state.plans.isEmpty) {
      return _buildMessage(
        context,
        title: 'Không tải được kế hoạch',
        message: state.error!,
        actionLabel: 'Thử lại',
        onAction: _cubit.load,
      );
    }
    if (state.plans.isEmpty) {
      return _buildMessage(
        context,
        title: 'Chưa có kế hoạch chi tiêu',
        message:
            'Hỏi trợ lý ở trang chủ để lập kế hoạch, hoặc mở phần ngân sách để '
            'phân bổ theo tháng.',
        actionLabel: 'Mở trợ lý',
        onAction: () => context.go(AppRoutes.home),
      );
    }
    final plan = state.selected!;
    return RefreshIndicator(
      onRefresh: _cubit.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (state.plans.length > 1) ...[
            _buildPlanPicker(context, state),
            const SizedBox(height: 12),
          ],
          PlanHeaderCard(plan: plan),
          const SizedBox(height: 18),
          Text(
            'Phân bổ theo trụ cột',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Hạn mức mỗi ngày và chi tiêu đã ghi nhận.',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          for (final entry in _pillarTotals(plan, state.allocations).entries)
            PlanPillarRow(
              pillar: entry.key,
              limit: entry.value.$1,
              spent: entry.value.$2,
            ),
          const SizedBox(height: 10),
          Text(
            'Hạn mức theo nhóm chi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          PlanGroupList(plan: plan),
          const SizedBox(height: 10),
          Text(
            'Dự báo từng ngày',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          PlanDayStrip(allocations: state.allocations),
          const SizedBox(height: 8),
          Text(
            'Kế hoạch là bản chiếu của phong bao. Hạn mức danh mục vẫn nằm ở '
            'phần Ngân sách.',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanPicker(BuildContext context, PlanState state) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.plans.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final plan = state.plans[index];
          final selected = plan.id == state.selected?.id;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => _cubit.select(plan),
            label: Text(
              '${plan.durationDays} ngày · ${formatVnd(plan.dailyAllowance)}',
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessage(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The daily limit and the recorded spending of every pillar.
  ///
  /// The limit comes from the plan's groups; the spending comes from the
  /// allocation rows of the current day, so both numbers are the engine's.
  Map<EnvelopePillar, (num, num)> _pillarTotals(
    BudgetPlan plan,
    List<DailyAllocation> allocations,
  ) {
    final limits = <EnvelopePillar, num>{};
    final spent = <EnvelopePillar, num>{};
    for (final group in plan.groups) {
      final pillar = planPillarOf(group.groupKey);
      limits[pillar] = (limits[pillar] ?? 0) + group.dailyAmount;
    }
    final today = _currentDay(plan);
    for (final item in allocations) {
      if (item.dayIndex != today) continue;
      final pillar = planPillarOf(item.groupKey);
      spent[pillar] = (spent[pillar] ?? 0) + item.actualSpent;
    }
    return {
      for (final pillar in limits.keys)
        pillar: (limits[pillar] ?? 0, spent[pillar] ?? 0),
    };
  }

  /// The day of the plan that is running now.
  int _currentDay(BudgetPlan plan) {
    final start = plan.startDate;
    if (start == null) return 1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = DateTime(start.year, start.month, start.day);
    final index = today.difference(first).inDays + 1;
    if (index < 1 || index > plan.durationDays) return 1;
    return index;
  }
}
