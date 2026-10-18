import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show GoTrueClient;
import 'package:project_one/core/config/supabase_config.dart';
import 'package:project_one/features/auth/cubit/auth_cubit.dart';
import 'package:project_one/shared/widgets/kakeibo_logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.auth,
    this.initialMode = AuthMode.login,
    this.recoverySession = false,
    this.allowGuest = false,
    this.onAuthenticated,
  });
  final GoTrueClient? auth;
  final AuthMode initialMode;
  final bool recoverySession;
  final bool allowGuest;
  final Future<void> Function()? onAuthenticated;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _code = TextEditingController();
  late final _cubit = AuthCubit(
    widget.auth ?? SupabaseConfig.client.auth,
    initialMode: widget.initialMode,
    recoverySession: widget.recoverySession,
  );
  Timer? _timer;
  bool _obscure = true;
  AuthStep _previousStep = AuthStep.credentials;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _cubit.state.step == AuthStep.code) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    _code.dispose();
    _cubit.close();
    super.dispose();
  }

  void _mode(AuthMode mode) {
    _password.clear();
    _confirmation.clear();
    _code.clear();
    _form.currentState?.reset();
    _cubit.setMode(mode);
  }

  Future<void> _submit() async {
    if (_cubit.state.busy || !(_form.currentState?.validate() ?? false)) return;
    switch (_cubit.state.step) {
      case AuthStep.credentials:
        await _cubit.submit(_email.text, _password.text);
      case AuthStep.code:
        await _cubit.verify(_code.text);
      case AuthStep.password:
        await _cubit.savePassword(_password.text);
    }
  }

  Future<void> _back() async {
    if (_cubit.state.busy) return;
    if (_cubit.state.mode == AuthMode.link &&
        _cubit.state.step == AuthStep.password) {
      _cubit.finishLink();
      return;
    }
    if (_cubit.state.step != AuthStep.credentials) {
      await _cubit.cancel();
      _password.clear();
      _confirmation.clear();
      _code.clear();
    } else if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    } else {
      _mode(AuthMode.login);
    }
  }

  String _title(AuthState state) {
    if (state.step == AuthStep.code) return 'Kiểm tra email của bạn';
    if (state.step == AuthStep.password) return 'Đặt mật khẩu mới';
    return switch (state.mode) {
      AuthMode.login => 'Chào mừng trở lại',
      AuthMode.register => 'Tạo tài khoản',
      AuthMode.otp => 'Đăng nhập bằng OTP',
      AuthMode.recovery => 'Khôi phục mật khẩu',
      AuthMode.link => 'Giữ lại sổ tài chính của bạn',
    };
  }

  Widget _field(String identifier, Widget child) => Padding(
    key: ValueKey(identifier),
    padding: const EdgeInsets.only(bottom: 16),
    child: Semantics(container: true, identifier: identifier, child: child),
  );

  @override
  Widget build(BuildContext context) => BlocConsumer<AuthCubit, AuthState>(
    bloc: _cubit,
    listener: (context, state) {
      if (state.step != _previousStep) {
        _password.clear();
        _confirmation.clear();
      }
      _previousStep = state.step;
      if (state.authenticated) {
        TextInput.finishAutofillContext();
        if (widget.onAuthenticated != null) {
          unawaited(widget.onAuthenticated!());
        } else if (Navigator.of(context).canPop()) {
          Navigator.pop(context, true);
        }
      }
    },
    builder: (context, state) {
      final credentials = state.step == AuthStep.credentials;
      final passwordStep = state.step == AuthStep.password;
      final needsPassword =
          passwordStep ||
          (credentials &&
              (state.mode == AuthMode.login ||
                  state.mode == AuthMode.register));
      final confirmPassword = passwordStep || state.mode == AuthMode.register;
      final seconds =
          ((state.resendAt?.difference(DateTime.now()).inMilliseconds ?? 0) /
                  1000)
              .ceil()
              .clamp(0, 60);
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_back());
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: Navigator.of(context).canPop() || !credentials
                ? BackButton(onPressed: state.busy ? null : _back)
                : null,
            title: const Text('Kakeibo Zen'),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AutofillGroup(
                  child: Form(
                    key: _form,
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Center(child: KakeiboLogo(size: 80)),
                        const SizedBox(height: 20),
                        Text(
                          _title(state),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.mode == AuthMode.link
                              ? 'Liên kết email để giữ dữ liệu và truy cập trên thiết bị khác.'
                              : 'Một chút ghi chép, thêm nhiều an tâm.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        if (credentials)
                          _field(
                            'auth-email',
                            TextFormField(
                              key: const Key('auth-email-field'),
                              controller: _email,
                              enabled: !state.busy,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: needsPassword
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              onFieldSubmitted: needsPassword
                                  ? null
                                  : (_) => _submit(),
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
                        if (state.step == AuthStep.code) ...[
                          Text(state.email, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          _field(
                            'auth-code',
                            TextFormField(
                              key: const Key('auth-code-field'),
                              controller: _code,
                              enabled: !state.busy,
                              keyboardType: TextInputType.number,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Mã xác minh 6 chữ số',
                                prefixIcon: Icon(Icons.password),
                              ),
                              validator: (value) =>
                                  RegExp(r'^\d{6}$').hasMatch(value ?? '')
                                  ? null
                                  : 'Nhập đủ 6 chữ số',
                            ),
                          ),
                        ],
                        if (needsPassword)
                          _field(
                            'auth-password',
                            TextFormField(
                              key: const Key('auth-password-field'),
                              controller: _password,
                              enabled: !state.busy,
                              obscureText: _obscure,
                              autofillHints: [
                                confirmPassword
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              textInputAction: confirmPassword
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              onFieldSubmitted: confirmPassword
                                  ? null
                                  : (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: passwordStep
                                    ? 'Mật khẩu mới'
                                    : 'Mật khẩu',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscure
                                      ? 'Hiện mật khẩu'
                                      : 'Ẩn mật khẩu',
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  (value?.length ?? 0) >=
                                      (confirmPassword ? 8 : 1)
                                  ? null
                                  : confirmPassword
                                  ? 'Dùng mật khẩu ít nhất 8 ký tự'
                                  : 'Nhập mật khẩu',
                            ),
                          ),
                        if (needsPassword && confirmPassword)
                          _field(
                            'auth-confirm',
                            TextFormField(
                              key: const Key('auth-confirm-field'),
                              controller: _confirmation,
                              enabled: !state.busy,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Xác nhận mật khẩu',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              validator: (value) => value == _password.text
                                  ? null
                                  : 'Mật khẩu xác nhận chưa khớp',
                            ),
                          ),
                        if (state.message != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(state.message!),
                            ),
                          ),
                        Semantics(
                          key: const ValueKey('auth-submit'),
                          container: true,
                          identifier: 'auth-submit',
                          child: FilledButton(
                            onPressed: state.busy ? null : _submit,
                            child: Text(
                              state.busy
                                  ? 'Đang xử lý...'
                                  : passwordStep
                                  ? 'Lưu mật khẩu'
                                  : !credentials
                                  ? 'Xác minh mã'
                                  : switch (state.mode) {
                                      AuthMode.login => 'Đăng nhập',
                                      AuthMode.register => 'Đăng ký',
                                      AuthMode.otp => 'Gửi mã OTP',
                                      AuthMode.recovery => 'Gửi mã khôi phục',
                                      AuthMode.link => 'Gửi mã liên kết',
                                    },
                            ),
                          ),
                        ),
                        if (state.step == AuthStep.code) ...[
                          TextButton(
                            onPressed: state.busy || seconds > 0
                                ? null
                                : _cubit.resend,
                            child: Text(
                              seconds > 0
                                  ? 'Gửi lại mã sau ${seconds}s'
                                  : 'Gửi lại mã',
                            ),
                          ),
                          TextButton(
                            onPressed: state.busy ? null : _back,
                            child: const Text('Đổi email'),
                          ),
                        ],
                        if (passwordStep && state.mode == AuthMode.link)
                          TextButton(
                            onPressed: state.busy ? null : _cubit.finishLink,
                            child: const Text('Tiếp tục bằng OTP'),
                          ),
                        if (credentials && state.mode != AuthMode.link) ...[
                          if (state.mode == AuthMode.login) ...[
                            Semantics(
                              key: const ValueKey('auth-use-otp'),
                              identifier: 'auth-use-otp',
                              container: true,
                              child: TextButton(
                                onPressed: state.busy
                                    ? null
                                    : () => _mode(AuthMode.otp),
                                child: const Text('Đăng nhập bằng mã OTP'),
                              ),
                            ),
                            Semantics(
                              key: const ValueKey('auth-use-recovery'),
                              identifier: 'auth-use-recovery',
                              container: true,
                              child: TextButton(
                                onPressed: state.busy
                                    ? null
                                    : () => _mode(AuthMode.recovery),
                                child: const Text('Quên mật khẩu?'),
                              ),
                            ),
                          ],
                          Semantics(
                            key: const ValueKey('auth-toggle-mode'),
                            container: true,
                            identifier: 'auth-toggle-mode',
                            child: TextButton(
                              onPressed: state.busy
                                  ? null
                                  : () => _mode(
                                      state.mode == AuthMode.login
                                          ? AuthMode.register
                                          : AuthMode.login,
                                    ),
                              child: Text(
                                state.mode == AuthMode.login
                                    ? 'Chưa có tài khoản? Đăng ký'
                                    : 'Đã có tài khoản? Đăng nhập',
                              ),
                            ),
                          ),
                          if (widget.allowGuest) ...[
                            const Divider(height: 24),
                            Semantics(
                              key: const ValueKey('auth-guest'),
                              identifier: 'auth-guest',
                              container: true,
                              child: OutlinedButton.icon(
                                onPressed: state.busy
                                    ? null
                                    : _cubit.continueAsGuest,
                                icon: const Icon(Icons.person_outline),
                                label: const Text('Tiếp tục với tư cách khách'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Khách cần kết nối mạng. Liên kết email trước khi đăng xuất hoặc xóa app để giữ quyền truy cập dữ liệu.',
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
