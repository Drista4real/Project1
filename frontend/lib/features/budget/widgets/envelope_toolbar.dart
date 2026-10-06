import 'package:flutter/material.dart';
import '../models/envelope_pillar.dart';

class EnvelopeToolbar extends StatelessWidget {
  const EnvelopeToolbar({
    super.key,
    required this.month,
    required this.search,
    required this.onSearch,
    required this.onMonth,
    required this.onAdd,
    required this.onRebalance,
  });
  final DateTime month;
  final TextEditingController search;
  final VoidCallback onSearch, onAdd, onRebalance;
  final ValueChanged<int> onMonth;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Phong bao tháng ${month.month}/${month.year}',
              style: const TextStyle(fontSize: 12, color: EnvelopeStyle.muted),
            ),
          ),
          IconButton(
            tooltip: 'Tháng trước',
            onPressed: () => onMonth(-1),
            icon: const Icon(Icons.chevron_left, size: 22),
          ),
          IconButton(
            tooltip: 'Tháng sau',
            onPressed: () => onMonth(1),
            icon: const Icon(Icons.chevron_right, size: 22),
          ),
        ],
      ),
      TextField(
        key: const ValueKey('category-search'),
        controller: search,
        onChanged: (_) => onSearch(),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm danh mục chi tiêu...',
          hintStyle: const TextStyle(fontSize: 12, color: EnvelopeStyle.muted),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: IconButton(
            tooltip: 'Xóa tìm kiếm',
            onPressed: () {
              search.clear();
              onSearch();
            },
            icon: const Icon(Icons.close, size: 17),
          ),
          filled: true,
          fillColor: EnvelopeStyle.soft,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline, size: 17),
              label: const Text(
                'Thêm danh mục mới',
                textAlign: TextAlign.center,
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onRebalance,
              icon: const Icon(Icons.tune, size: 17),
              label: const Text('Tái cân bằng %'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
