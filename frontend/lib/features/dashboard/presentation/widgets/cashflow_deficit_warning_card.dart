import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../finance/domain/usecases/finance_insights.dart';
import 'kakeibo_ui.dart';

class CashflowDeficitWarningCard extends StatelessWidget {
  const CashflowDeficitWarningCard({
    super.key,
    this.alert,
    this.onRead,
    this.onResolve,
    this.busy = false,
  });
  final FinanceRecord? alert;
  final VoidCallback? onRead, onResolve;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final item = alert;
    if (item == null) return const SizedBox.shrink();
    final date = financeDate(item['predicted_deficit_date']);
    return KakeiboCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.expenseCoral,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${item['title']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('${item['message']}'),
          if (date != null)
            Text(
              'Ngày dự kiến: ${date.day}/${date.month}/${date.year}',
              style: const TextStyle(fontSize: 12),
            ),
          if (item['predicted_deficit_amount'] != null)
            Text(
              'Thiếu hụt: ${formatVnd(financeAmount(item['predicted_deficit_amount']))}',
            ),
          if (item['suggested_action'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${item['suggested_action']}'),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              if (item['is_read'] != true)
                TextButton(
                  onPressed: busy ? null : onRead,
                  child: const Text('Đánh dấu đã đọc'),
                )
              else
                const Chip(label: Text('Đã đọc')),
              if (item['is_resolved'] != true)
                FilledButton(
                  onPressed: busy ? null : onResolve,
                  child: const Text('Đã xử lý'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
