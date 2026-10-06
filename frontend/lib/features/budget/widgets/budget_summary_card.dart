import 'package:flutter/material.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';
import '../models/budget_month_overview.dart';
import '../models/envelope_pillar.dart';

class BudgetSummaryCard extends StatelessWidget {
  const BudgetSummaryCard({super.key, required this.overview});
  final BudgetMonthOverview overview;
  @override
  Widget build(BuildContext context) {
    final remaining = overview.remaining;
    final over = remaining != null && remaining < 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [EnvelopeStyle.primary, Color(0xFF2D5A43)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Color(0xFFBCEECF),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  remaining == null
                      ? 'NGÂN SÁCH THÁNG'
                      : over
                      ? 'VƯỢT NGÂN SÁCH'
                      : 'NGÂN SÁCH CÒN LẠI',
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: .6,
                    color: Color(0xFFBCEECF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                remaining == null
                    ? 'Chưa thiết lập'
                    : '${over ? '−' : ''}${formatVnd(remaining.abs())}',
                key: const ValueKey('budget-remaining'),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: over ? const Color(0xFFFFC3A9) : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            remaining == null
                ? 'Lưu phân bổ để bắt đầu quản lý ngân sách tháng này.'
                : '${(overview.progress * 100).toStringAsFixed(1)}% ngân sách đã dùng',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFD7EADC),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: overview.progress.clamp(0, 1),
              minHeight: 8,
              semanticsLabel: 'Mức sử dụng ngân sách tháng',
              color: over ? const Color(0xFFFE875D) : const Color(0xFF85D6BB),
              backgroundColor: const Color(0xFF547B63),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _metric('Đã chi tiêu', formatVnd(overview.spent)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _metric(
                  'Ngân sách tháng',
                  overview.limit == null
                      ? 'Chưa đặt'
                      : formatVnd(overview.limit!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFFD7EADC)),
      ),
      const SizedBox(height: 6),
      SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ],
  );
}

class BudgetDailyAllowance extends StatelessWidget {
  const BudgetDailyAllowance({super.key, required this.overview});
  final BudgetMonthOverview overview;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFE2FAF2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.spa_outlined, color: Color(0xFF005D49), size: 23),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Định mức mỗi ngày',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF005D49),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${overview.daysLeft} ngày còn lại trong tháng',
                style: const TextStyle(
                  fontSize: 11,
                  color: EnvelopeStyle.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${formatVnd(overview.daily!)} / ngày',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF005D49),
                ),
              ),
              if (overview.remaining! <= 0)
                const Text(
                  'Ngân sách tháng đã dùng hết.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFA0401C)),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
