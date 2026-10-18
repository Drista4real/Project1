import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project_one/core/network/auth_error_message.dart';

enum AuthMode { login, register, otp, recovery, link }

enum AuthStep { credentials, code, password }

class AuthState {
  const AuthState({
    this.mode = AuthMode.login,
    this.step = AuthStep.credentials,
    this.email = '',
    this.busy = false,
    this.message,
    this.authenticated = false,
    this.resendAt,
  });
  final AuthMode mode;
  final AuthStep step;
  final String email;
  final bool busy;
  final String? message;
  final bool authenticated;
  final DateTime? resendAt;
  bool get register => mode == AuthMode.register;

  AuthState copyWith({
    AuthStep? step,
    bool busy = false,
    String? message,
    bool authenticated = false,
    DateTime? resendAt,
  }) => AuthState(
    mode: mode,
    step: step ?? this.step,
    email: email,
    busy: busy,
    message: message,
    authenticated: authenticated,
    resendAt: resendAt ?? this.resendAt,
  );
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(
    this.auth, {
    AuthMode initialMode = AuthMode.login,
    DateTime Function()? now,
    bool recoverySession = false,
  }) : _now = now ?? DateTime.now,
       super(AuthState(mode: initialMode)) {
    if (recoverySession) _acceptRecovery();
    _subscription = auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.passwordRecovery && !isClosed) {
        _acceptRecovery();
      }
    });
  }

  final GoTrueClient auth;
  final DateTime Function() _now;
  late final StreamSubscription<dynamic> _subscription;
  String? _passwordSessionToken;
  String? _linkUserId;

  bool get _ownsPasswordSession =>
      _passwordSessionToken != null &&
      auth.currentSession?.accessToken == _passwordSessionToken;

  void _acceptRecovery() {
    final session = auth.currentSession;
    if (session == null) return;
    _passwordSessionToken = session.accessToken;
    emit(
      AuthState(
        mode: AuthMode.recovery,
        step: AuthStep.password,
        email: session.user.email ?? '',
        busy: state.busy,
      ),
    );
  }

  void toggleMode() =>
      setMode(state.register ? AuthMode.login : AuthMode.register);

  void setMode(AuthMode mode) {
    if (isClosed || state.busy || _passwordSessionToken != null) return;
    if (auth.currentUser?.isAnonymous == true && mode != AuthMode.link) return;
    emit(AuthState(mode: mode));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (isClosed || state.busy) return;
    emit(state.copyWith(busy: true));
    try {
      await action();
    } on AuthException catch (error) {
      if (!isClosed) emit(state.copyWith(message: authErrorMessage(error)));
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(message: 'Không thể kết nối. Vui lòng thử lại.'));
      }
    }
  }

  DateTime get _nextResend => _now().add(const Duration(seconds: 60));

  Future<void> submit(String email, String password) => _run(() async {
    final mode = state.mode;
    final address = email.trim();
    if (auth.currentUser?.isAnonymous == true && mode != AuthMode.link) {
      throw const AuthException('Link the guest account first');
    }
    AuthResponse? response;
    var linkedImmediately = false;
    switch (mode) {
      case AuthMode.login:
        response = await auth.signInWithPassword(
          email: address,
          password: password,
        );
      case AuthMode.register:
        response = await auth.signUp(email: address, password: password);
      case AuthMode.otp:
        await auth.signInWithOtp(email: address, shouldCreateUser: false);
      case AuthMode.recovery:
        await auth.resetPasswordForEmail(address);
      case AuthMode.link:
        final user = auth.currentUser;
        if (user == null || !user.isAnonymous) {
          throw const AuthException(
            'Guest session missing',
            code: 'session_not_found',
          );
        }
        _linkUserId = user.id;
        final linked = await auth.updateUser(UserAttributes(email: address));
        linkedImmediately =
            linked.user?.id == _linkUserId &&
            linked.user?.isAnonymous == false &&
            linked.user?.email == address;
        if (linkedImmediately) {
          _passwordSessionToken = auth.currentSession?.accessToken;
        }
    }
    if (isClosed) return;
    final authenticated = response?.session != null;
    emit(
      AuthState(
        mode: mode,
        email: address,
        authenticated: authenticated,
        step: linkedImmediately
            ? AuthStep.password
            : authenticated || mode == AuthMode.login
            ? AuthStep.credentials
            : AuthStep.code,
        resendAt: _nextResend,
        message: linkedImmediately
            ? 'Đã liên kết email. Bạn có thể đặt mật khẩu hoặc tiếp tục bằng OTP.'
            : authenticated
            ? null
            : 'Nếu email hợp lệ, bạn sẽ nhận được mã xác minh. Kiểm tra cả thư mục spam.',
      ),
    );
  });

  Future<void> resend() async {
    if (state.step != AuthStep.code ||
        (state.resendAt?.isAfter(_now()) ?? false)) {
      return;
    }
    await _run(() async {
      switch (state.mode) {
        case AuthMode.register:
          await auth.resend(email: state.email, type: OtpType.signup);
        case AuthMode.otp:
          await auth.signInWithOtp(email: state.email, shouldCreateUser: false);
        case AuthMode.recovery:
          await auth.resetPasswordForEmail(state.email);
        case AuthMode.link:
          _checkLinkOwner();
          await auth.resend(email: state.email, type: OtpType.emailChange);
        case AuthMode.login:
          return;
      }
      if (!isClosed) {
        emit(
          state.copyWith(
            resendAt: _nextResend,
            message: 'Đã yêu cầu gửi lại mã. Vui lòng kiểm tra email.',
          ),
        );
      }
    });
  }

  void _checkLinkOwner() {
    if (_linkUserId == null || auth.currentUser?.id != _linkUserId) {
      throw const AuthException('Session changed', code: 'session_not_found');
    }
  }

  Future<void> verify(String code) async {
    if (state.step != AuthStep.code) return;
    await _run(() async {
      final mode = state.mode;
      if (mode == AuthMode.link) _checkLinkOwner();
      final response = await auth.verifyOTP(
        email: state.email,
        token: code.trim(),
        type: switch (mode) {
          AuthMode.recovery => OtpType.recovery,
          AuthMode.link => OtpType.emailChange,
          _ => OtpType.email,
        },
      );
      if (isClosed) return;
      final session = response.session;
      if (session == null) {
        emit(
          state.copyWith(
            message: 'Chưa xác minh xong. Kiểm tra email và nhập mã tiếp theo.',
          ),
        );
        return;
      }
      if (mode == AuthMode.recovery || mode == AuthMode.link) {
        if (mode == AuthMode.link &&
            (session.user.id != _linkUserId || session.user.isAnonymous)) {
          throw const AuthException(
            'Identity not linked',
            code: 'session_not_found',
          );
        }
        _passwordSessionToken = session.accessToken;
        emit(
          state.copyWith(
            step: AuthStep.password,
            message: mode == AuthMode.link
                ? 'Đã liên kết email. Bạn có thể đặt mật khẩu hoặc tiếp tục bằng OTP.'
                : null,
          ),
        );
      } else {
        emit(state.copyWith(authenticated: true));
      }
    });
  }

  Future<void> savePassword(String password) async {
    if (state.step != AuthStep.password) return;
    await _run(() async {
      if (!_ownsPasswordSession) {
        throw const AuthException('Session changed', code: 'session_not_found');
      }
      final recovery = state.mode == AuthMode.recovery;
      await auth.updateUser(UserAttributes(password: password));
      if (isClosed) return;
      if (recovery) {
        if (_ownsPasswordSession) await auth.signOut(scope: SignOutScope.local);
        _passwordSessionToken = null;
        if (!isClosed) {
          emit(
            const AuthState(
              message: 'Đã đổi mật khẩu. Vui lòng đăng nhập lại.',
            ),
          );
        }
      } else {
        _passwordSessionToken = null;
        emit(state.copyWith(authenticated: true));
      }
    });
  }

  void finishLink() {
    if (state.mode == AuthMode.link &&
        state.step == AuthStep.password &&
        _ownsPasswordSession) {
      _passwordSessionToken = null;
      emit(state.copyWith(authenticated: true));
    }
  }

  Future<void> cancel() async {
    if (isClosed || state.busy) return;
    await _run(() async {
      if (state.mode == AuthMode.recovery && _ownsPasswordSession) {
        await auth.signOut(scope: SignOutScope.local);
      }
      _passwordSessionToken = null;
      if (!isClosed) {
        emit(
          AuthState(
            mode: state.mode == AuthMode.link ? AuthMode.link : AuthMode.login,
          ),
        );
      }
    });
  }

  Future<void> continueAsGuest() => _run(() async {
    if (auth.currentSession == null) await auth.signInAnonymously();
    if (!isClosed) {
      emit(state.copyWith(authenticated: auth.currentSession != null));
    }
  });

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
