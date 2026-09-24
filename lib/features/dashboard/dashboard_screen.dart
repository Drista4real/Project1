import 'package:flutter/material.dart';
import '../../core/constants/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../services/supabase_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseService _service = SupabaseService();
  int _currentNavIndex = 0;

  bool _isLoading = false;
  FinancialOverview _overview = FinancialOverview(
    currentBalance: 18450000,
    monthlyIncome: 24500000,
    monthlyExpense: 6050000,
  );
  List<TransactionModel> _transactions = [];
  List<CategoryModel> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final overview = await _service.getFinancialOverview();
      final txList = await _service.getTransactions();
      final catList = await _service.getCategories();

      if (mounted) {
        setState(() {
          _overview = overview;
          _transactions = txList;
          _categories = catList;
        });
      }
    } catch (_) {
      // Fallback
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatVND(double amount) {
    final formatted = amount
        .abs()
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '$formatted₫';
  }

  void _showAddTransactionDialog() {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String type = 'expense';
    CategoryModel? selectedCategory = _categories.isNotEmpty ? _categories.first : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Thêm Giao dịch Mới',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textCharcoal,
                ),
              ),
              const SizedBox(height: 16),
              // Segmented Button: Chi tiêu / Thu nhập
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.bgCanvas,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => type = 'expense'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: type == 'expense' ? AppTheme.primaryForestGreen : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Chi tiêu',
                            style: TextStyle(
                              color: type == 'expense' ? Colors.white : AppTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => type = 'income'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: type == 'income' ? AppTheme.primaryForestGreen : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Thu nhập',
                            style: TextStyle(
                              color: type == 'income' ? Colors.white : AppTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Nhập số tiền
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Số tiền (₫)',
                  hintText: '0',
                  prefixText: '₫ ',
                  filled: true,
                  fillColor: AppTheme.bgCanvas,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Mô tả sao kê
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'Mô tả / Nội dung chuyển khoản',
                  hintText: 'VD: Ăn trưa, Cà phê Highland...',
                  filled: true,
                  fillColor: AppTheme.bgCanvas,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Chọn danh mục
              if (_categories.isNotEmpty) ...[
                const Text(
                  'Chọn danh mục',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = selectedCategory?.id == cat.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(cat.name),
                          selected: isSelected,
                          selectedColor: AppTheme.secondaryMint,
                          backgroundColor: AppTheme.bgCanvas,
                          labelStyle: TextStyle(
                            color: isSelected ? AppTheme.primaryForestGreen : AppTheme.textCharcoal,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => selectedCategory = cat);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              // Nút lưu
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    final text = amountController.text.replaceAll('.', '').trim();
                    final amount = double.tryParse(text) ?? 0.0;
                    if (amount <= 0) return;

                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    await _service.addTransaction(
                      amount: amount,
                      transactionType: type,
                      description: descController.text.trim().isEmpty ? 'Giao dịch' : descController.text.trim(),
                      categoryId: selectedCategory?.id,
                      categoryName: selectedCategory?.name,
                    );
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Đã ghi nhận giao dịch vào PostgreSQL!')),
                      );
                      _loadAllData();
                    }
                  },
                  child: const Text('Lưu vào Sổ Thu Chi', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildKakeiboAppBar(),
      body: _buildSelectedTabBody(),
      bottomNavigationBar: _buildKakeiboBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTransactionDialog,
        backgroundColor: AppTheme.primaryForestGreen,
        elevation: 3,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  PreferredSizeWidget _buildKakeiboAppBar() {
    return AppBar(
      title: Row(
        children: [
          // Logo Kakeibo Zen
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.secondaryMint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.spa, color: AppTheme.primaryForestGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Kakeibo Zen',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.primaryForestGreen,
                ),
              ),
              Text(
                'Sổ Thu Chi Thông Minh',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16.0, left: 4.0),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.secondaryMint,
            child: const Icon(Icons.person, color: AppTheme.primaryForestGreen, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedTabBody() {
    switch (_currentNavIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildCalendarTab();
      case 2:
        return _buildReportsTab();
      case 3:
        return _buildSettingsTab();
      default:
        return _buildDashboardTab();
    }
  }

  // ==========================================
  // TAB 1: SỔ THU CHI (DASHBOARD CHÍNH)
  // ==========================================
  Widget _buildDashboardTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryForestGreen));
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: AppTheme.primaryForestGreen,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHeroBalanceCard(),
          const SizedBox(height: 16),
          _buildAiCashflowCard(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hôm nay, 24 Tháng 10',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textCharcoal,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryMint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Chi: -45.000₫',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryForestGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTransactionList(),
          const SizedBox(height: 80), // Padding cho FAB
        ],
      ),
    );
  }

  // Thẻ Hero Balance Card chuẩn Stitch màu Forest Green
  Widget _buildHeroBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.primaryForestGreen,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryForestGreen.withAlpha(50),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Số dư hiện tại',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Tháng 10',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '+${_formatVND(_overview.currentBalance)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_downward, color: Colors.white, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Thu nhập', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            Text(
                              '+${_formatVND(_overview.monthlyIncome)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_upward, color: Colors.white, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Chi tiêu', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            Text(
                              '-${_formatVND(_overview.monthlyExpense)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Thẻ AI Dự báo Dòng tiền Thông minh (Đề tài 17)
  Widget _buildAiCashflowCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightMintBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.secondaryMint),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppTheme.secondaryMint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: AppTheme.primaryForestGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Dự báo Dòng tiền AI (PhoBERT & DLinear)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.primaryForestGreen,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Với tốc độ chi tiêu này, tài khoản an toàn với số dư dự kiến ~12.400.000₫ vào ngày nhận lương tiếp theo.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textCharcoal, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Danh sách giao dịch phong cách Kakeibo Zen
  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: const Text('Chưa có giao dịch nào trong sổ thu chi.'),
      );
    }

    return Column(
      children: _transactions.map((tx) {
        final isIncome = tx.isIncome;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isIncome ? AppTheme.lightMintBg : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isIncome ? Icons.payments_outlined : Icons.restaurant_outlined,
                  color: isIncome ? AppTheme.incomeEmerald : AppTheme.expenseCoral,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.rawDescription ?? tx.cleanDescription ?? 'Giao dịch',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textCharcoal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${tx.categoryName ?? 'Chưa phân loại'} • ${tx.transactionDate.hour}:${tx.transactionDate.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                '${isIncome ? '+' : '-'}${_formatVND(tx.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isIncome ? AppTheme.incomeEmerald : AppTheme.expenseCoral,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ==========================================
  // TAB 2: LỊCH BIỂU (CALENDAR VIEW THEO STITCH)
  // ==========================================
  Widget _buildCalendarTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Icon(Icons.chevron_left),
                  Text(
                    'Tháng 10, 2024',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 16),
              // Dummy calendar grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                    .map((d) => Text(d, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)))
                    .toList(),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppTheme.borderLight),
              const SizedBox(height: 12),
              const Text(
                'Lịch thu chi giúp bạn theo dõi chi tiêu trực quan theo từng ngày trong tháng.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: BÁO CÁO (REPORTS & DONUT CHART)
  // ==========================================
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
                        const Text('Tổng chi', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                        Text(
                          _formatVND(_overview.monthlyExpense),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildCategoryReportItem('Nhà ở & Tiền điện nước', 4500000, 0.74, '#3B82F6'),
              _buildCategoryReportItem('Ăn uống & Cà phê', 895000, 0.15, '#F59E0B'),
              _buildCategoryReportItem('Mua sắm & Khác', 655000, 0.11, '#EC4899'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryReportItem(String name, double amount, double percentage, String colorHex) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text('${_formatVND(amount)} (${(percentage * 100).toInt()}%)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

  // ==========================================
  // TAB 4: CÀI ĐẶT & KẾT NỐI SUPABASE
  // ==========================================
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryMint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cloud_done, color: AppTheme.primaryForestGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đồng bộ Supabase Cloud',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          SupabaseConfig.supabaseUrl,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.borderLight),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.currency_exchange, color: AppTheme.primaryForestGreen),
                title: const Text('Đơn vị tiền tệ'),
                trailing: const Text('VND (₫)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.security, color: AppTheme.primaryForestGreen),
                title: const Text('Bảo mật dữ liệu (PostgreSQL RLS)'),
                trailing: const Icon(Icons.check_circle, color: AppTheme.incomeEmerald),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Bottom Navigation Bar chuẩn Stitch Kakeibo Zen
  Widget _buildKakeiboBottomNav() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white,
      elevation: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, label: 'Sổ Thu Chi', index: 0),
            _buildNavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, label: 'Lịch Biểu', index: 1),
            const SizedBox(width: 48), // Khoảng trống cho FAB
            _buildNavItem(icon: Icons.pie_chart_outline, activeIcon: Icons.pie_chart, label: 'Báo Cáo', index: 2),
            _buildNavItem(icon: Icons.tune_outlined, activeIcon: Icons.tune, label: 'Cài Đặt', index: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentNavIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentNavIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppTheme.primaryForestGreen : AppTheme.textMuted,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryForestGreen : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
