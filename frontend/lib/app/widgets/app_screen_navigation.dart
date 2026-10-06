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
    final saved = await context.push<bool>(AppRoutes.addTransaction);
    if (saved == true) await onTransactionAdded?.call();
  }

  @override
  Widget build(BuildContext context) {
    const routes = [
      AppRoutes.ledger,
      AppRoutes.reports,
      '',
      AppRoutes.budget,
      AppRoutes.settings,
    ];
    const items = [
      (Icons.menu_book_outlined, Icons.menu_book, 'Sổ thu chi'),
      (Icons.pie_chart_outline, Icons.pie_chart, 'Báo cáo'),
      (Icons.add, Icons.add, ''),
      (
        Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet,
        'Ngân sách',
      ),
      (Icons.tune_outlined, Icons.tune, 'Cài đặt'),
    ];
    return BottomAppBar(
      color: const Color(0xFFF6FBF5),
      elevation: 0,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 68,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: i == 2
                    ? Align(
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
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 29,
                              ),
                            ),
                          ),
                        ),
                      )
                    : InkWell(
                        onTap: () {
                          final routeIndex = i < 2 ? i : i - 1;
                          if (routeIndex != selectedIndex) {
                            context.go(routes[i]);
                          } else {
                            onSelectedTab?.call();
                          }
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              selectedIndex == (i < 2 ? i : i - 1)
                                  ? items[i].$2
                                  : items[i].$1,
                              color: selectedIndex == (i < 2 ? i : i - 1)
                                  ? AppTheme.primaryForestGreen
                                  : AppTheme.textMuted,
                              size: 21,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              items[i].$3,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: selectedIndex == (i < 2 ? i : i - 1)
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: selectedIndex == (i < 2 ? i : i - 1)
                                    ? AppTheme.primaryForestGreen
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
