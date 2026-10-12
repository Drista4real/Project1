import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/features/transactions/cubit/transaction_detail_cubit.dart';
import 'package:flutter/material.dart';

import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/finance/domain/entities/transaction.dart';
import 'package:project_one/features/finance/domain/repositories/finance_repository.dart';
import 'package:project_one/features/transactions/screens/quick_add_transaction_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final int transactionId;
  final FinanceRepository? repository;
  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
    this.repository,
  });
  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  FinanceRepository get _repository =>
      widget.repository ?? AppDependencies.financeRepository;
  late final _cubit = TransactionDetailCubit(_repository, widget.transactionId)
    ..refresh();
  Transaction? get _transaction => _cubit.state.transaction;
  String? get _error => _cubit.state.error;
  bool get _busy => _cubit.state.busy;
  bool _changed = false;

  Future<void> _load() => _cubit.refresh();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuickAddTransactionScreen(
          transaction: _transaction,
          repository: _repository,
        ),
      ),
    );
    if (saved == true && mounted) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa giao dịch?'),
        content: const Text(
          'Giao dịch sẽ bị xóa và số dư ví sẽ được cập nhật.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.expenseCoral,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _cubit.delete();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<TransactionDetailCubit, TransactionDetailState>(
        bloc: _cubit,
        listenWhen: (previous, current) => previous.busy && !current.busy,
        listener: (context, state) {
          if (state.deleted) Navigator.pop(context, true);
          if (state.deleteError != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.deleteError!)));
          }
        },
        builder: (context, state) => _buildContent(context),
      );

  Widget _buildContent(BuildContext context) {
    final tx = _transaction;
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết giao dịch'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _busy ? null : () => Navigator.pop(context, _changed),
          ),
        ),
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(onPressed: _load, child: const Text('Thử lại')),
                  ],
                ),
              )
            : tx == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            tx.transactionType == 'transfer'
                                ? Icons.swap_horiz
                                : tx.isIncome
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: AppTheme.primaryForestGreen,
                            size: 32,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${tx.amount.toStringAsFixed(2)} ₫',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryForestGreen,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            tx.rawDescription ??
                                tx.cleanDescription ??
                                'Giao dịch',
                            style: const TextStyle(fontSize: 17),
                          ),
                          const Divider(height: 32),
                          Text(
                            'Loại: ${tx.transactionType == 'transfer'
                                ? 'Chuyển tiền'
                                : tx.isIncome
                                ? 'Thu nhập'
                                : 'Chi tiêu'}',
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Danh mục: ${tx.categoryName ?? 'Chưa phân loại'}',
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Ngày: ${tx.transactionDate.day}/${tx.transactionDate.month}/${tx.transactionDate.year}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Sửa giao dịch'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Xóa giao dịch'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.expenseCoral,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
