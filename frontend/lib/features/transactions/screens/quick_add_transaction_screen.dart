import 'package:flutter/material.dart';

import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/finance/domain/entities/category.dart';
import 'package:project_one/features/finance/domain/entities/account.dart';
import 'package:project_one/features/finance/domain/entities/transaction.dart';
import 'package:project_one/features/finance/domain/repositories/finance_repository.dart';
import 'package:project_one/shared/widgets/finance_form.dart';
import 'package:project_one/features/management/open_finance_module.dart';

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
  final _form = GlobalKey<FormState>();
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

  String? _validateAmount(String? text) {
    final input = (text ?? '').trim();
    final value = double.tryParse(
      input.replaceAll('.', '').replaceAll(',', '.'),
    );
    if (!RegExp(
          r'^(?:\d+|\d{1,3}(?:\.\d{3})+)(?:,\d{1,2})?$',
        ).hasMatch(input) ||
        value == null ||
        !value.isFinite ||
        value <= 0 ||
        value > 9999999999999) {
      return 'Nhập số tiền lớn hơn 0, ví dụ 45.000 hoặc 45.000,50';
    }
    return null;
  }

  Future<void> _manage(String resource, {bool create = false}) async {
    await openFinanceModule(context, resource, create: create);
    if (mounted) await _loadCategories();
  }

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
    if (_saving || !validateFinanceForm(_form)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final value = double.parse(
      _amount.text.replaceAll('.', '').replaceAll(',', '.').trim(),
    );
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
    final disabled = _saving || _loading || _loadError != null;
    final categories = _categories.where((c) => c.isIncome == income).toList();
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.transaction == null ? 'Thêm giao dịch' : 'Sửa giao dịch',
          ),
          leading: IconButton(
            tooltip: 'Đóng',
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ),
        bottomNavigationBar: FinanceSaveBar(
          busy: _saving,
          onSave: disabled || _accounts.isEmpty ? null : _save,
          label: 'Lưu giao dịch',
        ),
        body: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loading) const LinearProgressIndicator(),
                    if (_loadError != null)
                      FinanceFormSection(
                        title: 'Chưa tải được ví và danh mục',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _loadError!,
                              style: const TextStyle(
                                color: AppTheme.expenseCoral,
                              ),
                            ),
                            TextButton(
                              onPressed: _loadCategories,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    FinanceFormSection(
                      title: 'Khoản thu / chi',
                      child: Column(
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
                                color: AppTheme.lightMintBg,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  for (final type in ['expense', 'income'])
                                    Expanded(
                                      child: _TypeChoice(
                                        label: type == 'income'
                                            ? 'Thu nhập'
                                            : 'Chi tiêu',
                                        icon: type == 'income'
                                            ? Icons.arrow_downward
                                            : Icons.arrow_upward,
                                        selected: _type == type,
                                        onTap: () {
                                          if (!disabled && _type != type) {
                                            setState(() {
                                              _type = type;
                                              _selected = null;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 22),
                          TextFormField(
                            key: const ValueKey('transactionAmount'),
                            controller: _amount,
                            enabled: !_saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.done,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: income
                                  ? AppTheme.incomeEmerald
                                  : AppTheme.primaryForestGreen,
                            ),
                            decoration: financeInputDecoration(
                              'Số tiền *',
                              hint: '0',
                              helper: 'Ví dụ: 45.000 hoặc 45.000,50',
                              suffixText: '₫',
                            ),
                            validator: _validateAmount,
                          ),
                        ],
                      ),
                    ),
                    FinanceFormSection(
                      title: _type == 'transfer'
                          ? 'Ví chuyển và ví nhận'
                          : 'Ví và thời gian',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<int>(
                            key: ValueKey('account:$_accountId:$_loading'),
                            initialValue:
                                _accounts.any((a) => a.id == _accountId)
                                ? _accountId
                                : null,
                            isExpanded: true,
                            decoration: financeInputDecoration(
                              _type == 'transfer'
                                  ? 'Ví chuyển *'
                                  : 'Ví / Tài khoản *',
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                            items: _accounts
                                .map(
                                  (a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text(
                                      a.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: disabled
                                ? null
                                : (value) => setState(() => _accountId = value),
                            validator: (value) =>
                                value == null ? 'Vui lòng chọn ví' : null,
                          ),
                          if (!_loading &&
                              _loadError == null &&
                              _accounts.isEmpty) ...[
                            const SizedBox(height: 8),
                            const Text('Tạo ví đầu tiên để bắt đầu ghi chép.'),
                            TextButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => _manage('accounts', create: true),
                              icon: const Icon(Icons.add),
                              label: const Text('Tạo ví'),
                            ),
                          ],
                          if (_type == 'transfer') ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              key: ValueKey(
                                'toAccount:$_toAccountId:$_accountId',
                              ),
                              initialValue:
                                  _accounts.any((a) => a.id == _toAccountId)
                                  ? _toAccountId
                                  : null,
                              isExpanded: true,
                              decoration: financeInputDecoration(
                                'Ví nhận *',
                                icon: Icons.move_to_inbox_outlined,
                              ),
                              items: _accounts
                                  .map(
                                    (a) => DropdownMenuItem(
                                      value: a.id,
                                      child: Text(
                                        a.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: disabled
                                  ? null
                                  : (value) =>
                                        setState(() => _toAccountId = value),
                              validator: (value) => value == null
                                  ? 'Vui lòng chọn ví nhận'
                                  : value == _accountId
                                  ? 'Ví nhận phải khác ví chuyển'
                                  : null,
                            ),
                          ],
                          const SizedBox(height: 16),
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _saving
                                ? null
                                : () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _date,
                                      firstDate: DateTime(1900),
                                      lastDate: DateTime(2200),
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
                            child: InputDecorator(
                              decoration: financeInputDecoration(
                                'Ngày giao dịch',
                                icon: Icons.calendar_today_outlined,
                              ),
                              child: Text(
                                '${_date.day}/${_date.month}/${_date.year}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_type != 'transfer')
                      FinanceFormSection(
                        title: 'Danh mục',
                        subtitle:
                            'Chọn nhóm phù hợp để theo dõi chi tiêu. Có thể để trống.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!disabled && categories.isEmpty)
                              const Text('Chưa có danh mục phù hợp.'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: categories.map((category) {
                                final selected = category.id == _selected?.id;
                                return ChoiceChip(
                                  label: Text(category.name),
                                  selected: selected,
                                  onSelected: disabled
                                      ? null
                                      : (_) => setState(
                                          () => _selected = selected
                                              ? null
                                              : category,
                                        ),
                                  selectedColor: AppTheme.secondaryMint,
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: selected
                                        ? AppTheme.primaryForestGreen
                                        : AppTheme.borderLight,
                                  ),
                                );
                              }).toList(),
                            ),
                            TextButton.icon(
                              onPressed: disabled
                                  ? null
                                  : () => _manage('categories'),
                              icon: const Icon(Icons.tune, size: 18),
                              label: const Text('Quản lý danh mục'),
                            ),
                          ],
                        ),
                      ),
                    FinanceFormSection(
                      title: 'Ghi chú',
                      subtitle: 'Thêm nội dung để dễ tìm lại giao dịch.',
                      child: TextFormField(
                        controller: _note,
                        enabled: !_saving,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 2000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: financeInputDecoration(
                          'Nội dung (không bắt buộc)',
                          hint: 'Ví dụ: Cà phê sáng, tiền điện...',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
