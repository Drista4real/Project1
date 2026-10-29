import 'package:flutter/material.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import 'package:project_one/features/management/config/management_metadata.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';
import '../models/envelope_pillar.dart';

class CategoryEnvelopeTile extends StatelessWidget {
  const CategoryEnvelopeTile({
    super.key,
    required this.category,
    required this.budget,
    required this.onEdit,
    required this.onAction,
    required this.onDisable,
    this.pillar,
  });
  final FinanceRecord category;
  final FinanceRecord? budget;
  final EnvelopePillar? pillar;
  final VoidCallback onEdit;
  final ValueChanged<String> onAction;
  final Future<void> Function() onDisable;

  @override
  Widget build(BuildContext context) {
    final color =
        pillar?.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final system = category['user_id'] == null;
    final name = '${category['name']}';
    final tile = Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      pillar?.tint ??
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, size: 22, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tooltip(
                      message: name,
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (budget == null)
                      Text(
                        'Chưa đặt hạn mức tháng',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Hạn mức: ',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            TextSpan(
                              text: formatVnd(
                                financeAmount(budget!['limit_amount']),
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            TextSpan(
                              text: '/tháng',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 11),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Chỉnh sửa $name',
                onPressed: onEdit,
                icon: Icon(
                  Icons.edit_outlined,
                  size: 19,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Thao tác với $name',
                icon: Icon(
                  Icons.more_vert,
                  size: 19,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onSelected: onAction,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(
                      system ? 'Chỉnh sửa hạn mức' : 'Chỉnh sửa danh mục',
                    ),
                  ),
                  if (budget != null)
                    const PopupMenuItem(
                      value: 'disable',
                      child: Text('Tắt phong bao tháng này'),
                    ),
                  if (!system)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Xóa danh mục'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Dismissible(
        key: ValueKey('envelope-${category['id']}'),
        direction: budget == null
            ? DismissDirection.none
            : DismissDirection.endToStart,
        confirmDismiss: (_) async {
          await onDisable();
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'Tắt phong bao',
            style: TextStyle(color: Color(0xFFA0401C)),
          ),
        ),
        child: tile,
      ),
    );
  }

  IconData get _icon =>
      managementAppearanceIcons[category['icon']] ??
      const {
        'local_cafe': Icons.coffee_outlined,
        'medical_services': Icons.medical_services_outlined,
        'menu_book': Icons.menu_book_outlined,
        'sports_esports': Icons.sports_esports_outlined,
        'fitness_center': Icons.fitness_center,
        'receipt_long': Icons.receipt_long_outlined,
        'flight_takeoff': Icons.flight_takeoff,
        'volunteer_activism': Icons.volunteer_activism_outlined,
        'build': Icons.build_outlined,
        'more_horiz': Icons.more_horiz,
      }[category['icon']] ??
      Icons.category_outlined;
}
