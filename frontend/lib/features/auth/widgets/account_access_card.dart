import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project_one/core/config/supabase_config.dart';
import 'package:project_one/core/network/auth_error_message.dart';
import 'package:project_one/features/auth/cubit/auth_cubit.dart';
import 'package:project_one/features/auth/screens/auth_screen.dart';
import 'package:project_one/features/auth/widgets/confirm_guest_exit.dart';

class AccountAccessCard extends StatefulWidget {
  const AccountAccessCard({super.key, this.auth});
  final GoTrueClient? auth;
  @override
  State<AccountAccessCard> createState() => _AccountAccessCardState();
}

class _AccountAccessCardState extends State<AccountAccessCard> {
  GoTrueClient get _auth => widget.auth ?? SupabaseConfig.client.auth;
  bool _busy = false;
  String? _error;

  Future<void> _open(AuthMode mode) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AuthScreen(auth: _auth, initialMode: mode),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _exit() async {
    if (_busy) return;
    final uid = _auth.currentUser?.id;
    if (_auth.currentUser?.isAnonymous == true) {
      if (!await confirmGuestExit(context)) return;
    }
    if (!mounted || _auth.currentUser?.id != uid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.signOut(scope: SignOutScope.local);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể đăng xuất. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _auth.onAuthStateChange,
    builder: (context, snapshot) {
      final user = _auth.currentUser;
      final guest = user?.isAnonymous == true;
      return Card(
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                guest ? Icons.person_outline : Icons.verified_user_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                guest
                    ? 'Khách'
                    : user?.email ?? 'Đăng nhập để quản lý giao dịch',
              ),
              subtitle: guest
                  ? const Text(
                      'Liên kết email để giữ dữ liệu và dùng trên thiết bị khác',
                    )
                  : null,
              isThreeLine: guest,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _busy
                            ? null
                            : () => guest
                                  ? _open(AuthMode.link)
                                  : user == null
                                  ? _open(AuthMode.login)
                                  : _exit(),
                        child: Text(
                          guest
                              ? 'Liên kết email'
                              : user == null
                              ? 'Đăng nhập'
                              : 'Đăng xuất',
                        ),
                      ),
                    ),
                  ),
                  if (guest)
                    PopupMenuButton<String>(
                      tooltip: 'Tùy chọn tài khoản',
                      enabled: !_busy,
                      onSelected: (_) => _exit(),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'exit', child: Text('Đăng xuất')),
                      ],
                    ),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          ],
        ),
      );
    },
  );
}
