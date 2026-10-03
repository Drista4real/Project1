import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../finance/domain/usecases/finance_insights.dart';
import 'kakeibo_ui.dart';

class GeminiAdviceCard extends StatelessWidget {
  const GeminiAdviceCard({super.key, this.consultation, this.onOpen});
  final FinanceRecord? consultation;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final item = consultation;
    if (item == null) {
      return const KakeiboCard(
        child: Text('Chưa có nội dung tư vấn được lưu.'),
      );
    }
    return KakeiboCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.primaryForestGreen),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tư vấn tài chính đã lưu',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${item['user_query']}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '${item['ai_recommendation']}',
            style: const TextStyle(height: 1.5),
          ),
          if (onOpen != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.history),
                label: const Text('Xem lịch sử tư vấn'),
              ),
            ),
        ],
      ),
    );
  }
}
