import 'package:flutter/material.dart';

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
