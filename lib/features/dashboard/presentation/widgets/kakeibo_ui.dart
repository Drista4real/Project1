import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';

class AppScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  final String subtitle;

  const AppScreenHeader({required this.subtitle, super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    titleSpacing: 16,
    title: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.lightMintBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.spa,
            color: AppTheme.primaryForestGreen,
            size: 20,
          ),
        ),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kakeibo Zen',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryForestGreen,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ],
    ),
    actions: const [
      Padding(
        padding: EdgeInsets.only(right: 16),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: AppTheme.secondaryMint,
          child: Icon(
            Icons.person,
            color: AppTheme.primaryForestGreen,
            size: 19,
          ),
        ),
      ),
    ],
  );
}

class AppScreenNavigation extends StatelessWidget {
  final int selectedIndex;
  final Future<void> Function()? onTransactionAdded;

  const AppScreenNavigation({
    required this.selectedIndex,
    this.onTransactionAdded,
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

class KakeiboCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const KakeiboCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    super.key,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: AppTheme.borderLight),
    ),
    child: child,
  );
}

class KakeiboProgress extends StatelessWidget {
  final double value;
  final Color color;
  const KakeiboProgress({required this.value, required this.color, super.key});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0).toDouble(),
      minHeight: 7,
      color: color,
      backgroundColor: const Color(0xFFE8EDE8),
    ),
  );
}

String formatVnd(num amount) {
  final formatted = amount
      .abs()
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]}.',
      );
  return '$formatted ₫';
}
