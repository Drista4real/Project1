import 'package:flutter/material.dart';
import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/finance/domain/entities/financial_overview.dart';
import 'package:project_one/features/finance/domain/entities/transaction.dart';
import 'package:project_one/features/finance/domain/repositories/finance_repository.dart';
import 'package:project_one/features/finance/domain/repositories/management_repository.dart';
import 'package:project_one/features/management/open_finance_module.dart';
import 'package:project_one/app/widgets/app_screen_navigation.dart';
import 'package:project_one/features/auth/screens/auth_screen.dart';
import 'package:project_one/features/transactions/screens/transaction_detail_screen.dart';

part '../widgets/ledger_content.dart';

class LedgerScreen extends StatefulWidget {
  final FinanceRepository? repository;
  final ManagementRepository? managementRepository;
  const LedgerScreen({super.key, this.repository, this.managementRepository});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  FinanceRepository get _repository =>
      widget.repository ?? AppDependencies.financeRepository;
  Future<FinancialOverview> _getOverview() => _repository.getOverview();
  Future<List<Transaction>> _getTransactions() => _repository.getTransactions();
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

      if (mounted) {
        setState(() {
          _overview = overview;
          _transactions = txList;
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

  Future<void> _manageFinance(String resource) async {
    await openFinanceModule(
      context,
      resource,
      repository: widget.managementRepository,
    );
    if (mounted) await _loadAllData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildKakeiboAppBar(),
      body: _buildLedgerContent(),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Kakeibo Zen',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.primaryForestGreen,
                  ),
                ),
                Text(
                  'Sổ Thu Chi Thông Minh',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
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
