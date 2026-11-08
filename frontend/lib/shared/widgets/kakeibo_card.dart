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
    // The card paints a background, so a tile inside it needs its own
    // Material ancestor; otherwise its ink splashes stay invisible.
    child: Material(type: MaterialType.transparency, child: child),
  );
}
