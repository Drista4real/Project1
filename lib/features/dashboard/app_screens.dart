import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/di/injection.dart';
import '../../features/finance/domain/entities/category.dart';
import '../../features/finance/domain/entities/financial_overview.dart';

class AppScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  final String subtitle;

  const AppScreenHeader({required this.subtitle, super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.secondaryMint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.spa,
              color: AppTheme.primaryForestGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kakeibo Zen',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryForestGreen,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none),
        ),
        const Padding(
          padding: EdgeInsets.only(right: 16, left: 4),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.secondaryMint,
            child: Icon(
              Icons.person,
              color: AppTheme.primaryForestGreen,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}

class AppScreenNavigation extends StatelessWidget {
  final int selectedIndex;

  const AppScreenNavigation({required this.selectedIndex, super.key});

  void _navigate(BuildContext context, int index) {
    final routes = [
      AppRoutes.ledger,
      AppRoutes.reports,
      AppRoutes.budget,
      AppRoutes.settings,
    ];
    if (index != selectedIndex) {
      context.go(routes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.menu_book_outlined, Icons.menu_book, 'Sổ thu chi'),
      (Icons.pie_chart_outline, Icons.pie_chart, 'Báo cáo'),
      (
        Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet,
        'Ngân sách',
      ),
      (Icons.tune_outlined, Icons.tune, 'Cài đặt'),
    ];
    return BottomAppBar(
      color: Colors.white,
      elevation: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => _navigate(context, i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selectedIndex == i ? items[i].$2 : items[i].$1,
                        color: selectedIndex == i
                            ? AppTheme.primaryForestGreen
                            : AppTheme.textMuted,
                        size: 22,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[i].$3,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selectedIndex == i
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: selectedIndex == i
                              ? AppTheme.primaryForestGreen
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
    monthlyExpense: 6050000,
  );
  String _period = 'Tháng';

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    final overview = await _getOverview();
    if (mounted) setState(() => _overview = overview);
  }

  String _money(double amount) =>
      '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}₫';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppScreenHeader(subtitle: 'Báo cáo'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Tuần', label: Text('Tuần')),
              ButtonSegment(value: 'Tháng', label: Text('Tháng')),
              ButtonSegment(value: 'Năm', label: Text('Năm')),
            ],
            selected: {_period},
            onSelectionChanged: (value) =>
                setState(() => _period = value.first),
          ),
          const SizedBox(height: 18),
          _ReportCard(
            title: 'Phân bổ chi tiêu',
            child: Column(
              children: [
                SizedBox(
                  width: 190,
                  height: 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const SizedBox(
                        width: 170,
                        height: 170,
                        child: CircularProgressIndicator(
                          value: .65,
                          strokeWidth: 18,
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
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _money(_overview.monthlyExpense),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _reportLine(
                  'Nhà ở & Điện nước',
                  4500000,
                  .74,
                  const Color(0xFF3B82F6),
                ),
                _reportLine(
                  'Ăn uống & Cà phê',
                  895000,
                  .15,
                  const Color(0xFFF59E0B),
                ),
                _reportLine(
                  'Mua sắm & Khác',
                  655000,
                  .11,
                  const Color(0xFFEC4899),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _ZenMessage(
            text:
                'Biết rõ dòng tiền là bước đầu tiên để tâm trí luôn an định giữa nhịp sống bận rộn.',
          ),
        ],
      ),
      bottomNavigationBar: const AppScreenNavigation(selectedIndex: 1),
    );
  }

  Widget _reportLine(String name, double amount, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontSize: 13)),
              Text(
                '${_money(amount)} (${(value * 100).round()}%)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: value,
            color: color,
            backgroundColor: color.withAlpha(30),
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }
}

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  String _money(double amount) =>
      '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}₫';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppScreenHeader(subtitle: 'Ngân sách'),
      body: ListView(
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tháng 10, 2024',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
              Chip(
                avatar: const Icon(Icons.timelapse, size: 16),
                label: const Text('Còn 7 ngày'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ReportCard(
            title: 'Khả dụng còn lại',
            child: Column(
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  width: 210,
                  height: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const SizedBox(
                        width: 188,
                        height: 188,
                        child: CircularProgressIndicator(
                          value: .46,
                          strokeWidth: 14,
                          color: AppTheme.primaryForestGreen,
                          backgroundColor: AppTheme.secondaryMint,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _money(6450000),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryForestGreen,
                            ),
                          ),
                          const Text(
                            'trên 12.000.000₫',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Bạn đang chi tiêu trong giới hạn an toàn.',
                  style: TextStyle(color: AppTheme.textMuted),
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
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Tạo mới'),
              ),
            ],
          ),
          _Envelope(
            name: 'Ăn uống & Cà phê',
            used: '1.800.000₫',
            limit: '2.500.000₫',
            value: .72,
            color: const Color(0xFFF59E0B),
            icon: Icons.restaurant_outlined,
          ),
          _Envelope(
            name: 'Nhà ở & Điện nước',
            used: '3.200.000₫',
            limit: '4.500.000₫',
            value: .71,
            color: const Color(0xFF3B82F6),
            icon: Icons.home_outlined,
          ),
          _Envelope(
            name: 'Mua sắm & Gia dụng',
            used: '550.000₫',
            limit: '1.500.000₫',
            value: .36,
            color: const Color(0xFFEC4899),
            icon: Icons.shopping_bag_outlined,
          ),
        ],
      ),
      bottomNavigationBar: const AppScreenNavigation(selectedIndex: 2),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppTheme.primaryForestGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppScreenHeader(subtitle: 'Tiện ích & Cài đặt'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Tiện ích & Thiết lập',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.cloud_done,
                title: 'Đồng bộ Supabase Cloud',
                subtitle: 'Đã kết nối an toàn',
                trailing: const Icon(
                  Icons.check_circle,
                  color: AppTheme.incomeEmerald,
                ),
              ),
              _SettingsTile(
                icon: Icons.currency_exchange,
                title: 'Đơn vị tiền tệ',
                subtitle: 'VND (₫)',
                trailing: const Icon(Icons.chevron_right),
              ),
              _SettingsTile(
                icon: Icons.notifications_none,
                title: 'Nhắc nhở ghi chép',
                subtitle: 'Mỗi ngày lúc 20:00',
                trailing: Switch(value: true, onChanged: (_) {}),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.backup_outlined,
                title: 'Sao lưu dữ liệu',
                subtitle: 'Lần cuối: Hôm nay, 08:30',
                trailing: const Icon(Icons.chevron_right),
              ),
              _SettingsTile(
                icon: Icons.security,
                title: 'Bảo mật dữ liệu',
                subtitle: 'PostgreSQL RLS đang bật',
                trailing: const Icon(
                  Icons.check_circle,
                  color: AppTheme.incomeEmerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _ZenMessage(
            text:
                'Mỗi ngày ghi chép là một bước hướng tới tự do và an tâm tài chính.',
          ),
        ],
      ),
      bottomNavigationBar: const AppScreenNavigation(selectedIndex: 3),
    );
  }
}

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _getCategories = AppDependencies.getCategories;
  final _addTransaction = AppDependencies.addTransaction;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  List<Category> _categories = [];
  Category? _selectedCategory;
  String _type = 'expense';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await _getCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
        _selectedCategory = categories.isNotEmpty ? categories.first : null;
      });
    }
  }

  Future<void> _save() async {
    final amount =
        double.tryParse(_amountController.text.replaceAll('.', '').trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _addTransaction(
        amount: amount,
        transactionType: _type,
        description: _noteController.text.trim().isEmpty
            ? 'Giao dịch'
            : _noteController.text.trim(),
        categoryId: _selectedCategory?.id,
        categoryName: _selectedCategory?.name,
      );
      if (mounted) context.pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lưu giao dịch: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm thu chi'),
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.close),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.lightMintBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    label: 'Chi tiêu',
                    icon: Icons.arrow_upward,
                    selected: _type == 'expense',
                    onTap: () => setState(() => _type = 'expense'),
                  ),
                ),
                Expanded(
                  child: _TypeButton(
                    label: 'Thu nhập',
                    icon: Icons.arrow_downward,
                    selected: _type == 'income',
                    onTap: () => setState(() => _type = 'income'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Số tiền',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryForestGreen,
            ),
            decoration: InputDecoration(
              hintText: '0',
              suffixText: '₫',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'Ghi chú nhanh',
              hintText: 'Ví dụ: Bánh mì, Grab...',
              prefixIcon: const Icon(Icons.edit_note),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Danh mục',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((category) {
              final selected = category.id == _selectedCategory?.id;
              return ChoiceChip(
                label: Text(category.name),
                selected: selected,
                selectedColor: AppTheme.secondaryMint,
                onSelected: (_) => setState(() => _selectedCategory = category),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Đang lưu...' : 'Lưu vào sổ thu chi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryForestGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : AppTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ReportCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Envelope extends StatelessWidget {
  final String name;
  final String used;
  final String limit;
  final double value;
  final Color color;
  final IconData icon;

  const _Envelope({
    required this.name,
    required this.used,
    required this.limit,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
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
                '$used / $limit',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: value,
            minHeight: 8,
            color: color,
            backgroundColor: color.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.secondaryMint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primaryForestGreen),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: trailing,
    );
  }
}

class _ZenMessage extends StatelessWidget {
  final String text;

  const _ZenMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightMintBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.spa, color: AppTheme.primaryForestGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '“$text”',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
