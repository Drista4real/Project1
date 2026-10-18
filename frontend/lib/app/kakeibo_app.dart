import 'package:flutter/material.dart';
import 'package:project_one/app/app_router.dart';
import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/settings/cubit/app_preferences.dart';

class KakeiboZenApp extends StatelessWidget {
  const KakeiboZenApp({super.key, this.preferences});
  final AppPreferences? preferences;
  @override
  Widget build(BuildContext context) {
    final source = preferences ?? AppDependencies.preferences;
    return ListenableBuilder(
      listenable: source,
      builder: (context, _) => MaterialApp.router(
        title: 'Kakeibo Zen - Sổ Thu Chi & Dự Báo Dòng Tiền AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.kakeiboTheme,
        darkTheme: AppTheme.kakeiboDarkTheme,
        themeMode: source.themeMode,
        routerConfig: appRouter,
      ),
    );
  }
}
