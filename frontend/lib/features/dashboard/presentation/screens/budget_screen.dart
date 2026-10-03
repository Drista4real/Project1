import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../finance/domain/usecases/finance_insights.dart';
import '../widgets/finance_data_view.dart';
import '../widgets/kakeibo_ui.dart';
import 'management_screen.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key, this.insights});
  final FinanceInsights? insights;
  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _dataController = FinanceDataController();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _manage(
    Future<void> Function() refresh, {
    FinanceRecord? record,
    bool create = false,
  }) async {
    await openFinanceModule(
      context,
      'budgets',
      record: record,
      create: create,
      defaults: {
        'month_year':
            '${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}-01',
      },
      repository: widget.insights?.repository,
    );
    if (mounted) await refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppScreenHeader(subtitle: 'Ngân Sách'),
    body: FinanceDataView<BudgetData>(
      controller: _dataController,
      load: (widget.insights ?? AppDependencies.financeInsights).budgets,
      builder: (context, data, refresh) {
        final records = data.month(_month);
        final budget = data.totalLimit(_month);
        final spent = data.spending.total(
          data.spending.month(_month),
          'expense',
        );
        final remaining = budget == null ? null : budget - spent;
        final progress = budget == null || budget <= 0 ? 0.0 : spent / budget;
        final now = DateTime.now();
        final currentMonth =
            _month.year == now.year && _month.month == now.month;
        final days =
            DateTime(_month.year, _month.month + 1, 0).day -
            (currentMonth ? now.day - 1 : 0);
        final daily = currentMonth && remaining != null
            ? (remaining / days).clamp(0, double.infinity)
            : null;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Tháng trước',
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Tháng ${_month.month}, ${_month.year}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryForestGreen,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tháng sau',
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month + 1),
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 16),
            KakeiboCard(
              child: Column(
                children: [
                  SizedBox(
                    height: 225,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 205,
                          height: 205,
                          child: CircularProgressIndicator(
                            value: progress.clamp(0, 1),
                            strokeWidth: 14,
                            strokeCap: StrokeCap.round,
                            backgroundColor: const Color(0xFFE8EDE8),
                            color: progress >= 1
                                ? AppTheme.expenseCoral
                                : AppTheme.primaryForestGreen,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'KHẢ DỤNG CÒN LẠI',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            Text(
                              remaining == null
                                  ? 'Chưa đặt tổng'
                                  : formatVnd(remaining),
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryForestGreen,
                              ),
                            ),
                            if (budget != null)
                              Text(
                                'Đã dùng ${(progress * 100).toStringAsFixed(1)}%',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _metric('Đã chi tiêu', formatVnd(spent)),
                      _metric(
                        'Ngân sách tổng',
                        budget == null ? 'Chưa thiết lập' : formatVnd(budget),
                      ),
                    ],
                  ),
                  if (budget == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Tạo ngân sách không chọn danh mục hoặc trụ cột để đặt hạn mức tổng.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (daily != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: KakeiboCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.savings_outlined),
                    title: const Text('Định mức còn lại mỗi ngày'),
                    subtitle: Text('$days ngày còn lại trong tháng'),
                    trailing: Text(
                      formatVnd(daily),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Phong Bao Kakeibo',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${records.length} hạn mức',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (records.isEmpty)
              const KakeiboCard(
                child: Text(
                  'Chưa có ngân sách cho tháng này. Tạo phong bao để bắt đầu.',
                ),
              ),
            for (final record in records)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EnvelopeCard(
                  title: data.title(record),
                  used: data.used(record, _month),
                  limit: financeAmount(record['limit_amount']),
                  threshold: financeAmount(record['alert_threshold_percent']),
                  onEdit: () => _manage(refresh, record: record),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _manage(refresh),
                  icon: const Icon(Icons.tune),
                  label: const Text('Quản lý ngân sách'),
                ),
                FilledButton.icon(
                  onPressed: () => _manage(refresh, create: true),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Tạo phong bao mới'),
                ),
              ],
            ),
          ],
        );
      },
    ),
    bottomNavigationBar: AppScreenNavigation(
      selectedIndex: 2,
      onTransactionAdded: _dataController.refresh,
    ),
  );

  Widget _metric(String label, String value) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _EnvelopeCard extends StatelessWidget {
  const _EnvelopeCard({
    required this.title,
    required this.used,
    required this.limit,
    required this.threshold,
    required this.onEdit,
  });
  final String title;
  final double used, limit, threshold;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final progress = limit > 0 ? used / limit : 0.0;
    final warning = progress * 100 >= threshold;
    final color = warning ? AppTheme.expenseCoral : AppTheme.primaryForestGreen;
    return KakeiboCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Chỉnh sửa',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          Text(
            '${formatVnd(used)} / ${formatVnd(limit)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          KakeiboProgress(value: progress, color: color),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(1)}% đã chi · Còn lại ${formatVnd(limit - used)}',
            style: const TextStyle(fontSize: 11),
          ),
          if (warning)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                progress >= 1
                    ? 'Đã vượt hoặc chạm hạn mức'
                    : 'Đã tới ngưỡng cảnh báo ${threshold.toStringAsFixed(0)}%',
                style: TextStyle(color: color, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
