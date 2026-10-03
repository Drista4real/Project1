import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../finance/domain/entities/category.dart';
import '../../../finance/domain/entities/account.dart';
import '../../../finance/domain/entities/transaction.dart';
import '../../../finance/domain/repositories/finance_repository.dart';

class QuickAddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;
  final FinanceRepository? repository;
  final String? initialDescription;
  const QuickAddTransactionScreen({
    super.key,
    this.transaction,
    this.repository,
    this.initialDescription,
  });
  @override
  State<QuickAddTransactionScreen> createState() =>
      _QuickAddTransactionScreenState();
}

class _QuickAddTransactionScreenState extends State<QuickAddTransactionScreen> {
  FinanceRepository get _repository =>
      widget.repository ?? AppDependencies.financeRepository;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  List<Category> _categories = [];
  List<Account> _accounts = [];
  int? _accountId;
  int? _toAccountId;
  DateTime _date = DateTime.now();
  String? _loadError;
  Category? _selected;
  String _type = 'expense';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _note.text = widget.initialDescription ?? '';
    final transaction = widget.transaction;
    if (transaction != null) {
      _amount.text = transaction.amount.toStringAsFixed(2).replaceAll('.', ',');
      _note.text =
          transaction.rawDescription ?? transaction.cleanDescription ?? '';
      _type = transaction.transactionType;
      _accountId = transaction.accountId;
      _toAccountId = transaction.toAccountId;
      _date = transaction.transactionDate;
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final values = await _repository.getCategories();
      final accounts = await _repository.getAccounts();
      if (mounted) {
        setState(() {
          _categories = values;
          _accounts = accounts;
          _accountId ??= accounts.isEmpty ? null : accounts.first.id;
          for (final category in values) {
            if (category.id == widget.transaction?.categoryId) {
              _selected = category;
            }
          }
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = '$error';
        });
      }
    }
  }

  Future<void> _save() async {
    final input = _amount.text.trim();
    final value = double.tryParse(
      _amount.text.replaceAll('.', '').replaceAll(',', '.').trim(),
    );
    if (value == null ||
        !value.isFinite ||
        (input.contains(',') && input.split(',').last.length > 2) ||
        value <= 0 ||
        value > 9999999999999) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ.')),
      );
      return;
    }
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ví để lưu giao dịch.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.transaction != null) {
        await _repository.updateTransaction(widget.transaction!.id, {
          'amount': value.toStringAsFixed(2),
          'transaction_type': _type,
          'raw_description': _note.text.trim(),
          'clean_description': _note.text.trim(),
          'category_id': _type == 'transfer' ? null : _selected?.id,
          'account_id': _accountId,
          'to_account_id': _type == 'transfer' ? _toAccountId : null,
          'transaction_date': _date.toUtc().toIso8601String(),
        });
      } else {
        await _repository.addTransaction(
          amount: value,
          transactionType: _type,
          description: _note.text.trim().isEmpty
              ? 'Giao dịch'
              : _note.text.trim(),
          categoryId: _selected?.id,
          categoryName: _selected?.name,
          accountId: _accountId,
          transactionDate: _date,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
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
    final income = _type == 'income';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction == null ? 'Ghi chép nhanh' : 'Sửa giao dịch',
        ),
        leading: IconButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          if (_type == 'transfer')
            const ListTile(
              leading: Icon(Icons.swap_horiz),
              title: Text('Chuyển tiền giữa các ví'),
            )
          else
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8EDE8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TypeChoice(
                      label: 'Chi tiêu',
                      icon: Icons.arrow_upward,
                      selected: !income,
                      onTap: () {
                        if (!_saving) {
                          setState(() {
                            _type = 'expense';
                            _selected = null;
                          });
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: _TypeChoice(
                      label: 'Thu nhập',
                      icon: Icons.arrow_downward,
                      selected: income,
                      onTap: () {
                        if (!_saving) {
                          setState(() {
                            _type = 'income';
                            _selected = null;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 26),
          if (_loadError != null)
            Text(
              _loadError!,
              style: const TextStyle(color: AppTheme.expenseCoral),
            ),
          if (_loadError != null)
            TextButton(
              onPressed: _loadCategories,
              child: const Text('Thử lại'),
            ),
          DropdownButtonFormField<int>(
            initialValue: _accounts.any((a) => a.id == _accountId)
                ? _accountId
                : null,
            decoration: const InputDecoration(labelText: 'Ví / Tài khoản'),
            items: _accounts
                .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                .toList(),
            onChanged: _saving
                ? null
                : (value) => setState(() => _accountId = value),
          ),
          if (_type == 'transfer')
            DropdownButtonFormField<int>(
              initialValue: _accounts.any((a) => a.id == _toAccountId)
                  ? _toAccountId
                  : null,
              decoration: const InputDecoration(labelText: 'Ví nhận'),
              items: _accounts
                  .map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _toAccountId = value),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.calendar_today,
              color: AppTheme.primaryForestGreen,
            ),
            title: Text('${_date.day}/${_date.month}/${_date.year}'),
            trailing: const Icon(Icons.edit_calendar),
            onTap: _saving
                ? null
                : () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                    );
                    if (date != null && mounted) {
                      setState(
                        () => _date = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          _date.hour,
                          _date.minute,
                        ),
                      );
                    }
                  },
          ),
          const Text(
            'SỐ TIỀN',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey('transactionAmount'),
            controller: _amount,
            enabled: !_saving,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: income
                  ? AppTheme.incomeEmerald
                  : AppTheme.primaryForestGreen,
            ),
            decoration: const InputDecoration(
              hintText: '0',
              helperText: 'Ví dụ: 45.000 hoặc 45.000,50',
              suffixText: '₫',
              border: InputBorder.none,
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 22),
          const Text(
            'DANH MỤC',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_categories.isEmpty)
            const Text('Chưa có danh mục. Bạn vẫn có thể lưu giao dịch.'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories
                .where((c) => _type != 'transfer' && c.isIncome == income)
                .map((category) {
                  final selected = category.id == _selected?.id;
                  return ChoiceChip(
                    label: Text(category.name),
                    selected: selected,
                    onSelected: _saving
                        ? null
                        : (_) => setState(
                            () => _selected = selected ? null : category,
                          ),
                    selectedColor: const Color(0xFFD8E9DC),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: selected
                          ? AppTheme.primaryForestGreen
                          : AppTheme.borderLight,
                    ),
                  );
                })
                .toList(),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _note,
            enabled: !_saving,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Ghi chú',
              hintText: 'Ví dụ: Cà phê sáng, tiền điện...',
              prefixIcon: const Icon(Icons.edit_note),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.spa_outlined,
                  color: AppTheme.primaryForestGreen,
                  size: 19,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Ghi lại một khoản nhỏ cũng giúp bạn hiểu rõ dòng tiền của mình.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving || _loading || _loadError != null
                  ? null
                  : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryForestGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
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
              label: Text(_saving ? 'Đang lưu...' : 'Lưu giao dịch'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChoice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
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
            size: 17,
            color: selected ? Colors.white : AppTheme.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    ),
  );
}
