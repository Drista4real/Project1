import 'package:flutter/material.dart';
import '../models/envelope_pillar.dart';

class EnvelopeBanner extends StatelessWidget {
  const EnvelopeBanner({
    super.key,
    this.eyebrow = 'HỆ THỐNG PHONG BAO KAKEIBO',
    this.title = 'Quản lý & phân bổ danh mục',
  });
  final String eyebrow, title;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/envelope_zen_header.jpg',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: EnvelopeStyle.primary),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xDD14422D), Color(0x772D5A43)],
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 112,
            minWidth: double.infinity,
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFBCEECF),
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
