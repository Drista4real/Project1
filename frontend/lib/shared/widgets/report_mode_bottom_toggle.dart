import 'package:flutter/material.dart';

import 'package:project_one/core/theme/app_theme.dart';

class ReportModeBottomToggle extends StatelessWidget {
  final String activeTab;
  final ValueChanged<String> onTabChanged;

  const ReportModeBottomToggle({
    required this.activeTab,
    required this.onTabChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isHistory = activeTab == 'history';
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => onTabChanged('history'),
              borderRadius: BorderRadius.circular(26),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isHistory
                      ? AppTheme.primaryForestGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.show_chart,
                      size: 16,
                      color: isHistory ? Colors.white : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Thống kê quá khứ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isHistory
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isHistory ? Colors.white : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => onTabChanged('forecast'),
              borderRadius: BorderRadius.circular(26),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !isHistory
                      ? AppTheme.primaryForestGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: !isHistory ? Colors.white : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Dự báo AI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: !isHistory
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: !isHistory ? Colors.white : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const _BadgeMoi(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeMoi extends StatelessWidget {
  const _BadgeMoi();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFC5EBDD),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Mới',
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF134E35),
        ),
      ),
    );
  }
}
