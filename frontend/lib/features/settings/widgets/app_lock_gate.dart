import 'package:flutter/material.dart';
import 'package:project_one/core/config/supabase_config.dart';
import 'package:project_one/features/settings/cubit/app_preferences.dart';
import 'package:project_one/features/auth/widgets/confirm_guest_exit.dart';

/// Covers all routes, including dialogs, when the app loses focus.
class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.preferences,
    required this.child,
  });
  final AppPreferences preferences;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _signingOut = false;
  String? _signOutError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.preferences.unlock();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      widget.preferences.lock();
    } else if (state == AppLifecycleState.resumed) {
      widget.preferences.unlock();
    }
  }

  Future<void> _signOut() async {
    final accountId = SupabaseConfig.currentUser?.id;
    if (SupabaseConfig.currentUser?.isAnonymous == true &&
        !await confirmGuestExit(context)) {
      return;
    }
    if (SupabaseConfig.currentUser?.id != accountId) return;
    if (!mounted) return;
    setState(() {
      _signingOut = true;
      _signOutError = null;
    });
    try {
      final previousUserId = widget.preferences.userId;
      await SupabaseConfig.client.auth.signOut();
      await widget.preferences.loadUser(null);
      if (previousUserId != null) {
        await widget.preferences.clearLockAfterSignOut(previousUserId);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _signOutError = 'Không thể đăng xuất: $error');
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.preferences,
    builder: (context, _) {
      final preferences = widget.preferences;
      return PopScope(
        canPop: !preferences.locked,
        child: Stack(
          children: [
            ExcludeFocus(
              excluding: preferences.locked,
              child: Offstage(
                offstage: preferences.locked,
                child: widget.child,
              ),
            ),
            if (preferences.locked)
              Positioned.fill(
                child: Scaffold(
                  body: SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_outline, size: 56),
                              const SizedBox(height: 16),
                              Text(
                                'Sổ tài chính đã khóa',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Dùng Face ID, vân tay hoặc mã khóa thiết bị để tiếp tục.',
                                textAlign: TextAlign.center,
                              ),
                              if (preferences.error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  preferences.error!,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed:
                                    preferences.authenticating || _signingOut
                                    ? null
                                    : preferences.unlock,
                                icon: const Icon(Icons.fingerprint),
                                label: Text(
                                  preferences.authenticating
                                      ? 'Đang xác thực...'
                                      : 'Mở khóa',
                                ),
                              ),
                              TextButton(
                                onPressed:
                                    preferences.authenticating || _signingOut
                                    ? null
                                    : _signOut,
                                child: const Text('Đăng xuất tài khoản'),
                              ),
                              if (_signOutError != null) Text(_signOutError!),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
