import 'package:flutter/material.dart';

import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import 'package:project_one/features/forecast/widgets/cashflow_deficit_warning_card.dart';
import 'package:project_one/features/forecast/widgets/cashflow_forecast_chart_card.dart';
import 'package:project_one/shared/widgets/finance_data_view.dart';
import 'package:project_one/features/ai/widgets/gemini_advice_card.dart';
import 'package:project_one/app/widgets/app_screen_header.dart';
import 'package:project_one/app/widgets/app_screen_navigation.dart';
import 'package:project_one/shared/widgets/kakeibo_card.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';
import 'package:project_one/shared/widgets/report_mode_bottom_toggle.dart';
import 'package:project_one/features/management/open_finance_module.dart';

class CashflowForecastScreen extends StatefulWidget {
  const CashflowForecastScreen({
    super.key,
    this.onSwitchToHistory,
    this.insights,
    this.controller,
  });
  final VoidCallback? onSwitchToHistory;
  final FinanceInsights? insights;
  final FinanceDataController? controller;
  @override
  State<CashflowForecastScreen> createState() => _CashflowForecastScreenState();
}

class ForecastPage extends StatefulWidget {
  const ForecastPage({super.key});
  @override
  State<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends State<ForecastPage> {
  final _controller = FinanceDataController();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppScreenHeader(subtitle: 'Dự Báo'),
    body: CashflowForecastScreen(controller: _controller),
    bottomNavigationBar: AppScreenNavigation(
      selectedIndex: 1,
      onTransactionAdded: _controller.refresh,
    ),
  );
}

class _CashflowForecastScreenState extends State<CashflowForecastScreen> {
  int _selectedDays = 14;
  final _saving = <int>{};
  FinanceInsights get _insights =>
      widget.insights ?? AppDependencies.financeInsights;

  Future<void> _updateAlert(
    FinanceRecord alert,
    String field,
    Future<void> Function() refresh,
  ) async {
    final id = alert['id'] as int;
    if (_saving.contains(id)) return;
    setState(() => _saving.add(id));
    try {
      await _insights.repository.save('cashflow_alerts', {
        field: true,
      }, key: '$id');
      if (mounted) await refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(id));
    }
  }

  Future<void> _manage(String resource, Future<void> Function() refresh) async {
    await openFinanceModule(
      context,
      resource,
      repository: _insights.repository,
    );
    if (mounted) await refresh();
  }

  @override
  Widget build(BuildContext context) => FinanceDataView<ForecastData>(
    controller: widget.controller,
    load: _insights.forecasts,
    builder: (context, data, refresh) {
      final records = data.upcoming(DateTime.now(), _selectedDays);
      final alerts = data.alerts
          .where((item) => item['is_resolved'] != true)
          .toList();
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text(
            'Dự báo dòng tiền',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryForestGreen,
            ),
          ),
          const Text(
            'Dự báo và tư vấn đã lưu của bạn',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final days in [7, 14, 30])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text('$days ngày'),
                      selected: _selectedDays == days,
                      onSelected: (_) => setState(() => _selectedDays = days),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (alerts.isEmpty)
            const KakeiboCard(child: Text('Không có cảnh báo chưa xử lý.')),
          for (final alert in alerts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CashflowDeficitWarningCard(
                alert: alert,
                busy: _saving.contains(alert['id']),
                onRead: () => _updateAlert(alert, 'is_read', refresh),
                onResolve: () => _updateAlert(alert, 'is_resolved', refresh),
              ),
            ),
          const SizedBox(height: 16),
          CashflowForecastChartCard(
            records: records,
            currentBalance: financeAmount(data.profile['current_balance']),
            days: _selectedDays,
          ),
          const SizedBox(height: 12),
          if (records.isNotEmpty)
            KakeiboCard(
              child: Column(
                children: [
                  for (final record in records)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${record['forecast_date']}'),
                      subtitle: Text(
                        'Thu ${formatVnd(financeAmount(record['predicted_income']))} · Chi ${formatVnd(financeAmount(record['predicted_expense']))}',
                      ),
                      trailing: Text(
                        formatVnd(financeAmount(record['predicted_balance'])),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          GeminiAdviceCard(
            consultation: data.consultations.isEmpty
                ? null
                : data.consultations.first,
            onOpen: () => _manage('ai_consultations', refresh),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _manage('cashflow_forecasts', refresh),
                child: const Text('Quản lý dự báo'),
              ),
              OutlinedButton(
                onPressed: () => _manage('cashflow_alerts', refresh),
                child: const Text('Quản lý cảnh báo'),
              ),
              OutlinedButton(
                onPressed: () => _manage('ai_chat_sessions', refresh),
                child: const Text('Cuộc trò chuyện'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (widget.onSwitchToHistory != null)
            ReportModeBottomToggle(
              activeTab: 'forecast',
              onTabChanged: (tab) {
                if (tab == 'history') widget.onSwitchToHistory!();
              },
            ),
        ],
      );
    },
  );
}
