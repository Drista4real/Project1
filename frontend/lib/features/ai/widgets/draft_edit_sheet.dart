import 'package:flutter/material.dart';
import 'package:project_one/features/finance/domain/entities/account.dart';
import 'package:project_one/features/finance/domain/entities/category.dart';
import '../models/transaction_draft.dart';

class DraftEditSheet extends StatefulWidget {
  const DraftEditSheet({
    required this.item,
    required this.accounts,
    required this.categories,
    super.key,
  });
  final ReviewTransaction item;
  final List<Account> accounts;
  final List<Category> categories;
  @override
  State<DraftEditSheet> createState() => _DraftEditSheetState();
}

class _DraftEditSheetState extends State<DraftEditSheet> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.item.amount?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
  );
  late final _note = TextEditingController(text: widget.item.description);
  late String _type = widget.item.type == 'income' ? 'income' : 'expense';
  late int? _accountId = widget.item.accountId;
  late int? _categoryId = widget.item.categoryId;
  late DateTime _date = widget.item.date;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      widget.item.edited(
        description: _note.text.trim(),
        amount: double.parse(
          _amount.text.trim().replaceAll('.', '').replaceAll(',', '.'),
        ),
        type: _type,
        accountId: _accountId!,
        categoryId: _categoryId,
        date: _date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      16,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Form(
      key: _form,
      child: ListView(
        shrinkWrap: true,
        children: [
          const Text(
            'Kiểm tra giao dịch',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'expense',
                label: Text('Chi tiêu'),
                icon: Icon(Icons.north_east),
              ),
              ButtonSegment(
                value: 'income',
                label: Text('Thu nhập'),
                icon: Icon(Icons.south_west),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (values) => setState(() {
              _type = values.single;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('draftAmount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Số tiền (VND)'),
            validator: (value) {
              final input = (value ?? '').trim();
              final amount = double.tryParse(
                input.replaceAll('.', '').replaceAll(',', '.'),
              );
              if (!RegExp(
                    r'^(?:\d+|\d{1,3}(?:\.\d{3})+)(?:,\d{1,2})?$',
                  ).hasMatch(input) ||
                  amount == null ||
                  !amount.isFinite ||
                  amount <= 0 ||
                  amount > 9999999999999) {
                return 'Nhập số tiền hợp lệ, ví dụ 65.000 hoặc 65.000,50';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _note,
            maxLength: 2000,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Nội dung'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nhập nội dung giao dịch'
                : null,
          ),
          DropdownButtonFormField<int>(
            initialValue: _accountId,
            decoration: const InputDecoration(labelText: 'Ví thanh toán'),
            items: [
              for (final account in widget.accounts)
                DropdownMenuItem(value: account.id, child: Text(account.name)),
            ],
            onChanged: (value) => setState(() => _accountId = value),
            validator: (value) => value == null ? 'Hãy chọn ví' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('draftCategory-$_type'),
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Danh mục'),
            items: [
              for (final category in widget.categories.where(
                (c) => c.isIncome == (_type == 'income'),
              ))
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                ),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
            validator: (value) =>
                value == null ? 'Hãy chọn danh mục để gán phong bao' : null,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text('Ngày ${_date.day}/${_date.month}/${_date.year}'),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
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
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _confirm,
            child: const Text('Áp dụng thay đổi'),
          ),
        ],
      ),
    ),
  );
}
