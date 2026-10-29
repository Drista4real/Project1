import 'package:flutter/material.dart';

class KakeiboLogo extends StatelessWidget {
  const KakeiboLogo({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/kakeibo_mark.png',
    width: size,
    height: size,
    semanticLabel: 'Kakeibo Zen',
    color: Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.primary
        : null,
  );
}
