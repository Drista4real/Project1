import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project_one/features/auth/widgets/auth_gate.dart';

import 'package:project_one/app/app_router.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/features/settings/widgets/app_lock_gate.dart';
import 'package:project_one/features/settings/cubit/app_preferences.dart';

class KakeiboZenApp extends StatelessWidget {
  const KakeiboZenApp({super.key, this.preferences, this.auth});
  final AppPreferences? preferences;
  final GoTrueClient? auth;

  @override
  Widget build(BuildContext context) {
    final source = preferences ?? AppDependencies.preferences;
    if (auth != null) {
      return AuthGate(
        auth: auth!,
        preferences: source,
        signedInBuilder: (_) => _buildAccount(source),
      );
    }
    return _buildAccount(source);
  }

  Widget _buildAccount(AppPreferences source) {
    return ListenableBuilder(
      listenable: source,
      builder: (context, _) =>
          _AccountApp(key: ValueKey(source.userId), preferences: source),
    );
  }
}

class _AccountApp extends StatefulWidget {
  const _AccountApp({super.key, required this.preferences});
  final AppPreferences preferences;
  @override
  State<_AccountApp> createState() => _AccountAppState();
}

class _AccountAppState extends State<_AccountApp> {
  final _router = createAppRouter();
  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Kakeibo Zen - Sổ Thu Chi & Dự Báo Dòng Tiền AI',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.kakeiboTheme,
    darkTheme: AppTheme.kakeiboDarkTheme,
    themeMode: widget.preferences.themeMode,
    builder: (context, child) => AppLockGate(
      preferences: widget.preferences,
      child: child ?? const SizedBox.shrink(),
    ),
    routerConfig: _router,
  );
}
