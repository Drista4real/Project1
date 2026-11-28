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
  // The single balance lives in the primary wallet.
  late final int? _accountId =
      widget.item.accountId ??
      (widget.accounts.isEmpty ? null : widget.accounts.first.id);
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
    final accountId = _accountId;
    if (accountId == null) return;
    Navigator.pop(
      context,
      widget.item.edited(
        description: _note.text.trim(),
        amount: double.parse(
          _amount.text.trim().replaceAll('.', '').replaceAll(',', '.'),
        ),
        type: _type,
        accountId: accountId,
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
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Kiểm tra giao dịch',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sửa thông tin nếu cần. Khoản này chưa được lưu.',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 13,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
            decoration: _decoration('Số tiền', suffix: 'đ'),
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
            decoration: _decoration('Nội dung').copyWith(counterText: ''),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nhập nội dung giao dịch'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('draftCategory-$_type'),
            initialValue: _categoryId,
            isExpanded: true,
            decoration: _decoration('Danh mục'),
            items: [
              for (final category in widget.categories.where(
                (c) => c.isIncome == (_type == 'income'),
              ))
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
            validator: (value) => value == null ? 'Hãy chọn danh mục' : null,
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
            style: FilledButton.styleFrom(
              textStyle: const TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Áp dụng thay đổi'),
          ),
        ],
      ),
    ),
  );

  InputDecoration _decoration(String label, {String? suffix}) =>
      InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      );
}
