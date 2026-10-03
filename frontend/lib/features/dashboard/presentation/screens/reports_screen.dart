import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../finance/domain/entities/financial_overview.dart';
import '../widgets/category_spending_report_card.dart';
import '../widgets/kakeibo_ui.dart';
import '../widgets/report_mode_bottom_toggle.dart';
import '../widgets/spending_donut_chart_card.dart';
import '../widgets/weekly_spending_trend_card.dart';
import 'cashflow_forecast_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _getOverview = AppDependencies.getOverview;
  FinancialOverview _overview = FinancialOverview(
    currentBalance: 18450000,
    monthlyIncome: 24500000,
    monthlyExpense: 13550000,
  );
  String _period = 'Tháng';
  // Mode: 'history' (Thống kê quá khứ) or 'forecast' (Dự báo AI)
  String _activeTab = 'history';

  @override
  void initState() {
    super.initState();
    _getOverview()
        .then((value) {
          if (mounted) setState(() => _overview = value);
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppScreenHeader(subtitle: 'Báo Cáo'),
      body: _activeTab == 'forecast'
          ? CashflowForecastScreen(
              onSwitchToHistory: () => setState(() => _activeTab = 'history'),
            )
          : _buildHistoryReportBody(),
      bottomNavigationBar: const AppScreenNavigation(selectedIndex: 1),
    );
  }

  Widget _buildHistoryReportBody() {
    const colors = [
      Color(0xFFA64220),
      Color(0xFF285B45),
      Color(0xFFF17A59),
      Color(0xFF76CBB2),
      Color(0xFFC4CDC7),
    ];
    const names = [
      'Ăn uống (42%)',
      'Nhà ở (28%)',
      'Mua sắm (15%)',
      'Di chuyển (10%)',
      'Khác (5%)',
    ];
    const shares = [42, 28, 15, 10, 5];
    const amounts = [5690000, 3790000, 2030000, 1355000, 685000];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Tab Tuần / Tháng / Năm
        _buildPeriodToggle(),

        const SizedBox(height: 18),

        // Subtitle & An yên badge
        _buildReportTitleHeader(),

        const SizedBox(height: 16),

        // Phân bổ chi tiêu Donut Chart Card (Widget riêng)
        SpendingDonutChartCard(
          names: names,
          shares: shares,
          colors: colors,
          totalExpense: _overview.monthlyExpense,
        ),

        const SizedBox(height: 16),

        // Xu hướng trong tuần Card (Widget riêng)
        const WeeklySpendingTrendCard(),

        const SizedBox(height: 16),

        // Hạng mục chi nhiều nhất Card (Widget riêng)
        const CategorySpendingReportCard(
          names: names,
          shares: shares,
          amounts: amounts,
          colors: colors,
        ),

        const SizedBox(height: 14),

        // Tâm niệm Kakeibo Banner
        _buildMindfulnessBanner(),

        const SizedBox(height: 18),

        // Pill Switcher ở cuối: [Thống kê quá khứ] | [Dự báo AI Mới] (Widget riêng)
        ReportModeBottomToggle(
          activeTab: _activeTab,
          onTabChanged: (tab) => setState(() => _activeTab = tab),
        ),
      ],
    );
  }

  Widget _buildPeriodToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDE8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          for (final label in ['Tuần', 'Tháng', 'Năm'])
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _period = label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _period == label ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _period == label
                          ? AppTheme.primaryForestGreen
                          : AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportTitleHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BÁO CÁO TÀI CHÍNH',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textMuted,
                letterSpacing: .6,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  _period == 'Tháng' ? 'Tháng 10, 2024' : '$_period 2024',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryForestGreen,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: AppTheme.primaryForestGreen,
                ),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1EB),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.spa_outlined,
                size: 14,
                color: AppTheme.primaryForestGreen,
              ),
              SizedBox(width: 5),
              Text(
                'An yên',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryForestGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMindfulnessBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1EB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          _MindfulnessIconTile(),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tâm niệm Kakeibo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textCharcoal,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Biết rõ dòng tiền là bước đầu tiên để tâm trí luôn an định giữa nhịp sống bận rộn.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MindfulnessIconTile extends StatelessWidget {
  const _MindfulnessIconTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.menu_book,
        color: AppTheme.primaryForestGreen,
        size: 22,
      ),
    );
  }
}
