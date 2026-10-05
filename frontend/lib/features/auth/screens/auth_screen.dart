import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:project_one/core/config/supabase_config.dart';
import 'package:project_one/core/network/auth_error_message.dart';
import 'package:project_one/core/theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final response = _register
          ? await SupabaseConfig.client.auth.signUp(
              email: _email.text.trim(),
              password: _password.text,
            )
          : await SupabaseConfig.client.auth.signInWithPassword(
              email: _email.text.trim(),
              password: _password.text,
            );
      if (!mounted) return;
      if (response.session != null) {
        Navigator.pop(context, true);
      } else {
        setState(
          () => _message =
              'Kiểm tra email để xác nhận tài khoản, sau đó đăng nhập.',
        );
      }
    } on AuthException catch (error) {
      debugPrint(
        'Supabase Auth failed: status=${error.statusCode}, code=${error.code}',
      );
      if (mounted) {
        setState(() => _message = authErrorMessage(error));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Không thể kết nối. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_register ? 'Tạo tài khoản' : 'Đăng nhập')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Form(
          key: _form,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.spa,
                size: 52,
                color: AppTheme.primaryForestGreen,
              ),
              const SizedBox(height: 20),
              const Text(
                'Kakeibo Zen',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryForestGreen,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (value) =>
                    value != null &&
                        RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(value.trim())
                    ? null
                    : 'Nhập email hợp lệ',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (value) => value != null && value.length >= 6
                    ? null
                    : 'Nhập mật khẩu ít nhất 6 ký tự',
              ),
              const SizedBox(height: 16),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_message!),
                ),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(
                  _busy
                      ? 'Đang xử lý...'
                      : _register
                      ? 'Đăng ký'
                      : 'Đăng nhập',
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _register = !_register;
                        _message = null;
                      }),
                child: Text(
                  _register
                      ? 'Đã có tài khoản? Đăng nhập'
                      : 'Chưa có tài khoản? Đăng ký',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
