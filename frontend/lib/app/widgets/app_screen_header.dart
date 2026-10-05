import 'package:flutter/material.dart';

import 'package:project_one/core/theme/app_theme.dart';

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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kakeibo Zen',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryForestGreen,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
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
