part of 'dashboard_screen.dart';

// These extensions split one State implementation without changing its private state.
// ignore_for_file: library_private_types_in_public_api

extension Reportstab on _DashboardScreenState {
  Widget _buildReportsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            children: [
              const Text(
                'Phân bổ chi tiêu Tháng 10',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              // Donut chart representation
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: 0.65,
                        strokeWidth: 16,
                        color: AppTheme.primaryForestGreen,
                        backgroundColor: AppTheme.secondaryMint,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Tổng chi',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          _formatVND(_overview.monthlyExpense),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildCategoryReportItem(
                'Nhà ở & Tiền điện nước',
                4500000,
                0.74,
                '#3B82F6',
              ),
              _buildCategoryReportItem(
                'Ăn uống & Cà phê',
                895000,
                0.15,
                '#F59E0B',
              ),
              _buildCategoryReportItem(
                'Mua sắm & Khác',
                655000,
                0.11,
                '#EC4899',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryReportItem(
    String name,
    double amount,
    double percentage,
    String colorHex,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${_formatVND(amount)} (${(percentage * 100).toInt()}%)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: AppTheme.bgCanvas,
            color: AppTheme.primaryForestGreen,
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }
}
