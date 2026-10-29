import 'package:flutter/material.dart';

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
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );
}
