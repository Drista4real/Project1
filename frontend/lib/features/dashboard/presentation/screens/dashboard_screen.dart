import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../finance/domain/entities/category.dart';
import '../../../finance/domain/entities/financial_overview.dart';
import '../../../finance/domain/entities/transaction.dart';
import '../../../finance/domain/repositories/finance_repository.dart';
import '../../../finance/domain/usecases/add_transaction.dart';
import 'app_screens.dart';
import 'auth_screen.dart';
import 'transaction_detail_screen.dart';

part 'ledger_tab.dart';

class DashboardScreen extends StatefulWidget {
  final FinanceRepository? repository;
  const DashboardScreen({super.key, this.repository});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  FinanceRepository get _repository =>
      widget.repository ?? AppDependencies.financeRepository;
  Future<FinancialOverview> _getOverview() => _repository.getOverview();
  Future<List<Transaction>> _getTransactions() => _repository.getTransactions();
  Future<List<Category>> _getCategories() => _repository.getCategories();
  AddTransaction get _addTransaction => AddTransaction(_repository);
  bool _showCalendar = true;
  DateTime _displayedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  bool _isLoading = false;
  String? _loadError;
  FinancialOverview _overview = FinancialOverview(
    currentBalance: 0,
    monthlyIncome: 0,
    monthlyExpense: 0,
  );
  List<Transaction> _transactions = [];
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final overview = await _getOverview();
      final txList = await _getTransactions();
      final catList = await _getCategories();

      if (mounted) {
        setState(() {
          _overview = overview;
          _transactions = txList;
          _categories = catList;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = '$error';
          _transactions = [];
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openTransaction(Transaction transaction) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(
          transactionId: transaction.id,
          repository: _repository,
        ),
      ),
    );
    if (changed == true && mounted) await _loadAllData();
  }

  Future<void> _signIn() async {
    final signedIn = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AuthScreen()));
    if (signedIn == true && mounted) await _loadAllData();
  }

  String _formatVND(double amount) {
    final formatted = amount
        .abs()
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return '$formatted₫';
  }

  // Kept for compatibility with the previous bottom-sheet flow.
  // ignore: unused_element
  void _showAddTransactionDialog() {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String type = 'expense';
    Category? selectedCategory = _categories.isNotEmpty
        ? _categories.first
        : null;

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
                            color: type == 'expense'
                                ? AppTheme.primaryForestGreen
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Chi tiêu',
                            style: TextStyle(
                              color: type == 'expense'
                                  ? Colors.white
                                  : AppTheme.textMuted,
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
                            color: type == 'income'
                                ? AppTheme.primaryForestGreen
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Thu nhập',
                            style: TextStyle(
                              color: type == 'income'
                                  ? Colors.white
                                  : AppTheme.textMuted,
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
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
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
                            color: isSelected
                                ? AppTheme.primaryForestGreen
                                : AppTheme.textCharcoal,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
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
                    final text = amountController.text
                        .replaceAll('.', '')
                        .trim();
                    final amount = double.tryParse(text) ?? 0.0;
                    if (amount <= 0) return;

                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    await _addTransaction(
                      amount: amount,
                      transactionType: type,
                      description: descController.text.trim().isEmpty
                          ? 'Giao dịch'
                          : descController.text.trim(),
                      categoryId: selectedCategory?.id,
                      categoryName: selectedCategory?.name,
                    );
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Đã ghi nhận giao dịch vào PostgreSQL!',
                          ),
                        ),
                      );
                      _loadAllData();
                    }
                  },
                  child: const Text(
                    'Lưu vào Sổ Thu Chi',
                    style: TextStyle(fontSize: 16),
                  ),
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
      body: _buildDashboardTab(),
      bottomNavigationBar: AppScreenNavigation(
        selectedIndex: 0,
        onTransactionAdded: _loadAllData,
      ),
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
            child: const Icon(
              Icons.spa,
              color: AppTheme.primaryForestGreen,
              size: 22,
            ),
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
            child: const Icon(
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
