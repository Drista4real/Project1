import 'package:flutter/material.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';
import '../models/category_envelope_data.dart';

class EnvelopeFundingCard extends StatelessWidget {
  const EnvelopeFundingCard({super.key, required this.data});
  final CategoryEnvelopeData data;
  @override
  Widget build(BuildContext context) {
    if (data.availableBalance == null && data.monthlyIncome == 0) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nguồn tiền cho phong bao tháng ${data.month.month}/${data.month.year}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _amount(
                  'Thu nhập trong tháng',
                  data.monthlyIncome,
                  'envelope-monthly-income',
                ),
                if (data.availableBalance != null)
                  _amount(
                    'Số dư ví hiện tại',
                    data.availableBalance!,
                    'envelope-available-balance',
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Thu nhập mới cập nhật nguồn tiền. Hạn mức phong bao chỉ đổi khi bạn lưu phân bổ.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amount(String label, double amount, String key) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12)),
      Text(
        '${amount < 0 ? '−' : ''}${formatVnd(amount)}',
        key: ValueKey(key),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ],
  );
}
