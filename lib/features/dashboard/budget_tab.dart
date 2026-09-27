part of 'dashboard_screen.dart';

// These extensions split one State implementation without changing its private state.
// ignore_for_file: library_private_types_in_public_api

extension Budgettab on _DashboardScreenState {
  Widget _buildBudgetTab() {
    const budgetTotal = 12000000.0;
    const budgetUsed = 5550000.0;
    final progress = budgetUsed / budgetTotal;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ngân sách tháng này',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Tháng 10, 2024',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.secondaryMint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Còn 7 ngày',
                style: TextStyle(
                  color: AppTheme.primaryForestGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            children: [
              SizedBox(
                width: 190,
                height: 190,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 172,
                      height: 172,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 14,
                        color: AppTheme.primaryForestGreen,
                        backgroundColor: AppTheme.secondaryMint,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Đã sử dụng',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatVND(budgetUsed),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryForestGreen,
                          ),
                        ),
                        Text(
                          'trên ${_formatVND(budgetTotal)}',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bạn đang chi tiêu trong giới hạn an toàn.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Phong bao chi tiêu',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            TextButton.icon(
              onPressed: () => _showBudgetMessage(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tạo mới'),
            ),
          ],
        ),
        _buildBudgetEnvelope(
          'Ăn uống & Cà phê',
          1800000,
          2500000,
          Icons.restaurant_outlined,
          const Color(0xFFF59E0B),
        ),
        _buildBudgetEnvelope(
          'Nhà ở & Điện nước',
          3200000,
          4500000,
          Icons.home_outlined,
          const Color(0xFF3B82F6),
        ),
        _buildBudgetEnvelope(
          'Mua sắm & Gia dụng',
          550000,
          1500000,
          Icons.shopping_bag_outlined,
          const Color(0xFFEC4899),
        ),
        const SizedBox(height: 70),
      ],
    );
  }

  Widget _buildBudgetEnvelope(
    String name,
    double used,
    double limit,
    IconData icon,
    Color color,
  ) {
    final progress = (used / limit).clamp(0.0, 1.0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${_formatVND(used)} / ${_formatVND(limit)}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: color,
              backgroundColor: color.withAlpha(35),
            ),
          ),
        ],
      ),
    );
  }

  void _showBudgetMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tạo phong bao mới sẽ được kết nối với danh mục Supabase trong phiên tiếp theo.',
        ),
      ),
    );
  }
}
