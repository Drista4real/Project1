import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/cashflow_deficit_warning_card.dart';
import '../widgets/cashflow_forecast_chart_card.dart';
import '../widgets/gemini_advice_card.dart';
import '../widgets/report_mode_bottom_toggle.dart';

class CashflowForecastScreen extends StatefulWidget {
  final VoidCallback? onSwitchToHistory;

  const CashflowForecastScreen({this.onSwitchToHistory, super.key});

  @override
  State<CashflowForecastScreen> createState() => _CashflowForecastScreenState();
}

class _CashflowForecastScreenState extends State<CashflowForecastScreen> {
  int _selectedDays = 14;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Title & Accuracy Badge
        _buildForecastHeader(),

        const SizedBox(height: 14),

        // Period filter (7 ngày, 14 ngày, 30 ngày)
        _buildDaysFilter(),

        const SizedBox(height: 16),

        // CẢNH BÁO THÂM HỤT DÒNG TIỀN Card (Widget riêng)
        const CashflowDeficitWarningCard(),

        const SizedBox(height: 16),

        // Biến động số dư khả dụng (Interactive chart card - Widget riêng)
        const CashflowForecastChartCard(),

        const SizedBox(height: 16),

        // Lời khuyên Kakeibo từ Gemini (Zen AI Card - Widget riêng)
        const GeminiAdviceCard(),

        const SizedBox(height: 14),

        // Quote chánh niệm
        _buildMindfulnessQuote(),

        const SizedBox(height: 18),

        // Pill Switcher ở cuối: [Thống kê quá khứ] | [Dự báo AI Mới] (Widget riêng)
        ReportModeBottomToggle(
          activeTab: 'forecast',
          onTabChanged: (tab) {
            if (tab == 'history') {
              widget.onSwitchToHistory?.call();
            }
          },
        ),
      ],
    );
  }

  Widget _buildForecastHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dự báo dòng tiền AI',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryForestGreen,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Mô hình Darts / LightGBM • Gemini Pro',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted.withAlpha(220),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE5EDE7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF5E8B75),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Độ chính xác 94.8%',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF385746),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDaysFilter() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6EDE7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [7, 14, 30].map((days) {
          final isSelected = _selectedDays == days;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDays = days),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '$days ngày',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.primaryForestGreen
                        : AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMindfulnessQuote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1EB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.spa_outlined,
              size: 18,
              color: AppTheme.primaryForestGreen,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '“Tiền bạc là tấm gương phản chiếu tâm trí. Biết dừng lại trước một ham muốn nhỏ hôm nay là tự do tài chính cho ngày mai.”',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
                height: 1.45,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
