import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:project_one/app/app_routes.dart';
import 'package:project_one/app/widgets/app_screen_navigation.dart';
import 'package:project_one/features/plan/cubit/plan_cubit.dart';
import 'package:project_one/features/plan/data/budget_plan_repository.dart';
import 'package:project_one/features/plan/models/budget_plan_models.dart';
import 'package:project_one/features/plan/widgets/plan_calendar.dart';
import 'package:project_one/features/plan/widgets/plan_widgets.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';

/// The plan screen: the active budget plan laid out as a month calendar.
///
/// Every day shows what was spent against the engine's limit. The screen
/// never computes a plan figure (ADR 0009).
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, this.repository, this.today});

  final BudgetPlanRepository? repository;

  /// The current day; tests pin it, the app uses the clock.
  final DateTime? today;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late final PlanCubit _cubit = PlanCubit(
    widget.repository ?? BackendBudgetPlanRepository(),
  )..load();

  DateTime? _month;
  DateTime? _selected;
  int? _planId;

  DateTime get _today {
    final now = widget.today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

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
            tooltip: 'Thiết lập kế hoạch tháng',
            onPressed: () => context.push(AppRoutes.monthlySetup),
            icon: const Icon(Icons.tune),
          ),
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
        actionIcon: Icons.refresh_rounded,
        onAction: _cubit.load,
      );
    }
    if (state.plans.isEmpty) {
      return _buildMessage(
        context,
        title: 'Chưa có kế hoạch chi tiêu',
        message:
            'Trả lời 6 câu ngắn để biết mỗi ngày được chi bao nhiêu, hoặc hỏi '
            'trợ lý ở trang chủ.',
        actionLabel: 'Thiết lập kế hoạch tháng',
        actionIcon: Icons.event_note,
        onAction: () => context.push(AppRoutes.monthlySetup),
      );
    }
    final plan = state.selected!;
    final days = planDays(plan, state.allocations);
    _syncCalendar(plan);
    final selectedDay = _selected == null ? null : days[_selected!];
    final theme = Theme.of(context);
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
          PlanTodayCard(plan: plan, today: _today, days: days),
          const SizedBox(height: 12),
          PlanCalendar(
            month: _month!,
            days: days,
            today: _today,
            selected: _selected,
            onSelect: (date) => setState(() => _selected = date),
            onMoveMonth: (delta) => setState(
              () => _month = DateTime(_month!.year, _month!.month + delta),
            ),
            canGoBack: _month!.isAfter(_firstMonth(plan)),
            canGoForward: _month!.isBefore(_lastMonth(plan)),
          ),
          if (selectedDay != null) ...[
            const SizedBox(height: 12),
            PlanDayDetail(day: selectedDay, today: _today),
          ],
          const SizedBox(height: 18),
          Text(
            'Hạn mức theo nhóm chi',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          PlanGroupList(plan: plan),
          const SizedBox(height: 8),
          Text(
            'Kế hoạch là bản chiếu của phong bao. Hạn mức danh mục vẫn nằm ở '
            'phần Ngân sách.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Open the calendar on today, or on the plan's first day when today is
  /// outside it, whenever another plan is shown.
  void _syncCalendar(BudgetPlan plan) {
    if (_planId == plan.id && _month != null) return;
    _planId = plan.id;
    final first = plan.startDate;
    final start = first == null
        ? _today
        : DateTime(first.year, first.month, first.day);
    final end = start.add(Duration(days: plan.durationDays - 1));
    final focus = _today.isBefore(start) || _today.isAfter(end)
        ? start
        : _today;
    _selected = focus;
    _month = DateTime(focus.year, focus.month);
  }

  DateTime _firstMonth(BudgetPlan plan) {
    final start = plan.startDate ?? _today;
    return DateTime(start.year, start.month);
  }

  DateTime _lastMonth(BudgetPlan plan) {
    final end = (plan.startDate ?? _today).add(
      Duration(days: plan.durationDays - 1),
    );
    return DateTime(end.year, end.month);
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
    required IconData actionIcon,
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
                icon: Icon(actionIcon, size: 18),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
