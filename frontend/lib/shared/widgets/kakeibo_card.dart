import 'package:flutter/material.dart';

import 'package:project_one/core/theme/app_theme.dart';

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
