import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/auth/screens/auth_screen.dart';
import 'package:project_one/features/settings/cubit/app_preferences.dart';

/// Keep the auth form mounted until its operation finishes, even when verifying
/// a recovery code or linking an identity emits a new session in the SDK.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.preferences,
    required this.signedInBuilder,
  });
  final GoTrueClient auth;
  final AppPreferences preferences;
  final WidgetBuilder signedInBuilder;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late bool _showAuth = widget.auth.currentSession == null;
  bool _recovery = false;
  late final StreamSubscription<dynamic> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      if (event.event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          _recovery = true;
          _showAuth = true;
        });
      } else if (event.event == AuthChangeEvent.signedOut) {
        // The mounted recovery form owns completion and its success message.
        if (!_showAuth) setState(() => _showAuth = true);
        unawaited(widget.preferences.loadUser(null));
      } else if (!_showAuth) {
        unawaited(_syncAccount());
      }
    });
  }

  Future<void> _syncAccount() async {
    await widget.preferences.loadUser(widget.auth.currentUser?.id);
    if (mounted) setState(() {});
  }

  Future<void> _complete() async {
    final id = widget.auth.currentUser?.id;
    if (id == null) return;
    await widget.preferences.loadUser(id);
    if (mounted && widget.auth.currentUser?.id == id) {
      setState(() {
        _showAuth = false;
        _recovery = false;
      });
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showAuth) return widget.signedInBuilder(context);
    return ListenableBuilder(
      listenable: widget.preferences,
      builder: (context, _) => MaterialApp(
        title: 'Kakeibo Zen',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.kakeiboTheme,
        darkTheme: AppTheme.kakeiboDarkTheme,
        themeMode: widget.preferences.themeMode,
        home: AuthScreen(
          auth: widget.auth,
          recoverySession: _recovery,
          allowGuest: true,
          onAuthenticated: _complete,
        ),
      ),
    );
  }
}
