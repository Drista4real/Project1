import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/features/auth/cubit/auth_cubit.dart';
import 'package:flutter/material.dart';

import 'package:project_one/core/config/supabase_config.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final _cubit = AuthCubit(SupabaseConfig.client.auth);
  bool get _register => _cubit.state.register;
  bool get _busy => _cubit.state.busy;
  String? get _message => _cubit.state.message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _cubit.close();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_busy && _form.currentState!.validate()) {
      await _cubit.submit(_email.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<AuthCubit, AuthState>(
    bloc: _cubit,
    listenWhen: (previous, current) =>
        !previous.authenticated && current.authenticated,
    listener: (context, state) => Navigator.pop(context, true),
    builder: (context, state) => _buildContent(context),
  );

  Widget _buildContent(BuildContext context) => Scaffold(
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
              Icon(
                Icons.spa,
                size: 52,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Kakeibo Zen',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                container: true,
                identifier: 'auth-email',
                child: TextFormField(
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
              ),
              const SizedBox(height: 16),
              Semantics(
                container: true,
                identifier: 'auth-password',
                child: TextFormField(
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
              ),
              const SizedBox(height: 16),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_message!),
                ),
              Semantics(
                container: true,
                identifier: 'auth-submit',
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(
                    _busy
                        ? 'Đang xử lý...'
                        : _register
                        ? 'Đăng ký'
                        : 'Đăng nhập',
                  ),
                ),
              ),
              Semantics(
                container: true,
                identifier: 'auth-toggle-mode',
                child: TextButton(
                  onPressed: _busy ? null : () => _cubit.toggleMode(),
                  child: Text(
                    _register
                        ? 'Đã có tài khoản? Đăng nhập'
                        : 'Chưa có tài khoản? Đăng ký',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
