import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/features/reports/cubit/reports_cubit.dart';
import 'package:flutter/material.dart';

import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import 'package:project_one/features/reports/widgets/category_spending_report_card.dart';
import 'package:project_one/shared/widgets/finance_data_view.dart';
import 'package:project_one/app/widgets/app_screen_header.dart';
import 'package:project_one/app/widgets/app_screen_navigation.dart';
import 'package:project_one/shared/widgets/kakeibo_card.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';
import 'package:project_one/shared/widgets/report_mode_bottom_toggle.dart';
import 'package:project_one/features/reports/widgets/spending_donut_chart_card.dart';
import 'package:project_one/features/reports/widgets/weekly_spending_trend_card.dart';
import 'package:project_one/features/forecast/screens/cashflow_forecast_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.insights});
  final FinanceInsights? insights;
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _dataController = FinanceDataController();
  final _cubit = ReportsCubit();
  String get _period => _cubit.state.period;
  String get _activeTab => _cubit.state.activeTab;
  DateTime get _anchor => _cubit.state.anchor;
  (DateTime, DateTime) get _range => _cubit.state.range;
  void _move(int step) => _cubit.move(step);

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ReportsCubit, ReportsState>(
    bloc: _cubit,
    builder: (context, state) => _buildContent(context),
  );

  Widget _buildContent(BuildContext context) => Scaffold(
    appBar: const AppScreenHeader(subtitle: 'Báo Cáo'),
    body: _activeTab == 'forecast'
        ? CashflowForecastScreen(
            insights: widget.insights,
            controller: _dataController,
            onSwitchToHistory: () => _cubit.selectTab('history'),
          )
        : FinanceDataView<SpendingData>(
            controller: _dataController,
            load: (widget.insights ?? AppDependencies.financeInsights).spending,
            builder: (context, data, refresh) => _history(data),
          ),
    bottomNavigationBar: AppScreenNavigation(
      selectedIndex: 1,
      onTransactionAdded: _dataController.refresh,
    ),
  );

  Widget _history(SpendingData data) {
    final (start, end) = _range;
    final items = data.between(start, end);
    final spent = data.total(items, 'expense');
    final income = data.total(items, 'income');
    final groups = data.distribution(items);
    final shares = groups
        .map((item) => spent == 0 ? 0.0 : item.amount / spent * 100)
        .toList();
    final colors = groups
        .map(
          (item) => Color(
            int.tryParse(item.color.replaceFirst('#', 'FF'), radix: 16) ??
                0xFF7B8782,
          ),
        )
        .toList();
    final names = groups.map((item) => item.name).toList();
    final lastDay = end.subtract(const Duration(days: 1));
    final title = _period == 'Tháng'
        ? 'Tháng ${_anchor.month}, ${_anchor.year}'
        : _period == 'Năm'
        ? 'Năm ${_anchor.year}'
        : '${start.day}/${start.month} – ${lastDay.day}/${lastDay.month}/${lastDay.year}';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE8EDE8),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              for (final period in ['Tuần', 'Tháng', 'Năm'])
                Expanded(
                  child: TextButton(
                    onPressed: () => _cubit.selectPeriod(period),
                    style: TextButton.styleFrom(
                      backgroundColor: _period == period
                          ? Colors.white
                          : Colors.transparent,
                    ),
                    child: Text(period),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              tooltip: 'Kỳ trước',
              onPressed: () => _move(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryForestGreen,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Kỳ sau',
              onPressed: () => _move(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 16),
        KakeiboCard(
          child: Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              _metric('Thu nhập', income, AppTheme.incomeEmerald),
              _metric('Chi tiêu', spent, AppTheme.expenseCoral),
              _metric('Thu − chi', income - spent, AppTheme.primaryForestGreen),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SpendingDonutChartCard(
          names: [
            for (var index = 0; index < names.length; index++)
              '${names[index]} (${shares[index].toStringAsFixed(1)}%)',
          ],
          shares: shares,
          colors: colors,
          totalExpense: spent,
          totalLabel: 'Tổng chi trong kỳ',
        ),
        const SizedBox(height: 16),
        WeeklySpendingTrendCard(amounts: data.week(_anchor)),
        const SizedBox(height: 16),
        CategorySpendingReportCard(
          names: names,
          shares: shares,
          amounts: groups.map((item) => item.amount).toList(),
          colors: colors,
        ),
        const SizedBox(height: 16),
        const KakeiboCard(
          child: Text(
            'Biết rõ dòng tiền là bước đầu tiên để làm chủ chi tiêu.',
          ),
        ),
        const SizedBox(height: 18),
        ReportModeBottomToggle(
          activeTab: _activeTab,
          onTabChanged: (tab) => _cubit.selectTab(tab),
        ),
      ],
    );
  }

  Widget _metric(String title, double amount, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
      ),
      Text(
        formatVnd(amount),
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
    ],
  );
}
