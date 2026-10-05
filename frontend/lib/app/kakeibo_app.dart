import 'package:flutter/material.dart';

import 'package:project_one/app/app_router.dart';
import 'package:project_one/core/theme/app_theme.dart';

class KakeiboZenApp extends StatelessWidget {
  const KakeiboZenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kakeibo Zen - Sổ Thu Chi & Dự Báo Dòng Tiền AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.kakeiboTheme,
      routerConfig: appRouter,
    );
  }
}
