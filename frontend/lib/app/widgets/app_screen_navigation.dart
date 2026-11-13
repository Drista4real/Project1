import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:project_one/app/app_routes.dart';
import 'package:project_one/core/theme/app_theme.dart';

class AppScreenNavigation extends StatelessWidget {
  final int selectedIndex;
  final Future<void> Function()? onTransactionAdded;
  final VoidCallback? onSelectedTab;

  const AppScreenNavigation({
    required this.selectedIndex,
    this.onTransactionAdded,
    this.onSelectedTab,
    super.key,
  });

  Future<void> _addTransaction(BuildContext context) async {
    final route = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.auto_fix_high,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Nhập nhanh AI'),
              subtitle: const Text('Gõ hoặc nói nội dung thu chi'),
              onTap: () => Navigator.pop(sheetContext, AppRoutes.aiQuickInput),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Nhập thủ công'),
              subtitle: const Text('Tự chọn số tiền và danh mục'),
              onTap: () =>
                  Navigator.pop(sheetContext, AppRoutes.addTransaction),
            ),
          ],
        ),
      ),
    );
    if (route == null || !context.mounted) return;
    final saved = await context.push<bool>(route);
    if (saved == true) await onTransactionAdded?.call();
  }

  /// The navigable destinations, in the order they appear in the bar.
  static const List<NavDestination> destinations = <NavDestination>[
    NavDestination(
      route: AppRoutes.home,
      outline: Icons.home_outlined,
      filled: Icons.home,
      label: 'Trang chủ',
      identifier: 'nav-home',
    ),
    NavDestination(
      route: AppRoutes.ledger,
      outline: Icons.menu_book_outlined,
      filled: Icons.menu_book,
      label: 'Sổ thu chi',
      identifier: 'nav-ledger',
    ),
    NavDestination(
      route: AppRoutes.reports,
      outline: Icons.pie_chart_outline,
      filled: Icons.pie_chart,
      label: 'Báo cáo',
      identifier: 'nav-reports',
    ),
    NavDestination(
      route: AppRoutes.budget,
      outline: Icons.account_balance_wallet_outlined,
      filled: Icons.account_balance_wallet,
      label: 'Ngân sách',
      identifier: 'nav-budget',
    ),
    NavDestination(
      route: AppRoutes.settings,
      outline: Icons.tune_outlined,
      filled: Icons.tune,
      label: 'Cài đặt',
      identifier: 'nav-settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 68,
        child: Row(
          children: [
            Expanded(child: _buildItem(context, 0)),
            Expanded(child: _buildItem(context, 1)),
            Expanded(child: _buildAddButton(context)),
            Expanded(child: _buildItem(context, 2)),
            Expanded(child: _buildItem(context, 3)),
            Expanded(child: _buildItem(context, 4)),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final destination = destinations[index];
    final isSelected = selectedIndex == index;
    return Semantics(
      container: true,
      identifier: destination.identifier,
      child: InkWell(
        onTap: () {
          if (!isSelected) {
            context.go(destination.route);
          } else {
            onSelectedTab?.call();
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? destination.filled : destination.outline,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 21,
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Transform.translate(
        offset: const Offset(0, -12),
        child: SizedBox(
          width: 54,
          height: 54,
          child: FloatingActionButton(
            heroTag: 'quick-add-navigation',
            onPressed: () => _addTransaction(context),
            backgroundColor: AppTheme.primaryForestGreen,
            elevation: 3,
            shape: const CircleBorder(),
            child: const Icon(Icons.add, color: Colors.white, size: 29),
          ),
        ),
      ),
    );
  }
}

class NavDestination {
  const NavDestination({
    required this.route,
    required this.outline,
    required this.filled,
    required this.label,
    required this.identifier,
  });

  final String route;
  final IconData outline;
  final IconData filled;
  final String label;
  final String identifier;
}
