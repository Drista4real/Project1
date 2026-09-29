import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../finance/domain/entities/category.dart';

class QuickAddTransactionScreen extends StatefulWidget {
  const QuickAddTransactionScreen({super.key});
  @override
  State<QuickAddTransactionScreen> createState() =>
      _QuickAddTransactionScreenState();
}

class _QuickAddTransactionScreenState extends State<QuickAddTransactionScreen> {
  final _getCategories = AppDependencies.getCategories;
  final _addTransaction = AppDependencies.addTransaction;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  List<Category> _categories = [];
  Category? _selected;
  String _type = 'expense';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final values = await _getCategories();
      if (mounted) {
        setState(() {
          _categories = values;
          _selected = values.isEmpty ? null : values.first;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final value = double.tryParse(
      _amount.text.replaceAll('.', '').replaceAll(',', '').trim(),
    );
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _addTransaction(
        amount: value,
        transactionType: _type,
        description: _note.text.trim().isEmpty
            ? 'Giao dịch'
            : _note.text.trim(),
        categoryId: _selected?.id,
        categoryName: _selected?.name,
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
    final income = _type == 'income';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ghi chép nhanh'),
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.close),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
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
                    onTap: () => setState(() => _type = 'expense'),
                  ),
                ),
                Expanded(
                  child: _TypeChoice(
                    label: 'Thu nhập',
                    icon: Icons.arrow_downward,
                    selected: income,
                    onTap: () => setState(() => _type = 'income'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
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
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: income
                  ? AppTheme.incomeEmerald
                  : AppTheme.primaryForestGreen,
            ),
            decoration: const InputDecoration(
              hintText: '0',
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
            children: _categories.map((category) {
              final selected = category.id == _selected?.id;
              return ChoiceChip(
                label: Text(category.name),
                selected: selected,
                onSelected: (_) => setState(() => _selected = category),
                selectedColor: const Color(0xFFD8E9DC),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected
                      ? AppTheme.primaryForestGreen
                      : AppTheme.borderLight,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _note,
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
              onPressed: _saving ? null : _save,
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
