import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project_one/core/network/auth_error_message.dart';

class AuthState {
  const AuthState({
    this.register = false,
    this.busy = false,
    this.message,
    this.authenticated = false,
  });
  final bool register;
  final bool busy;
  final String? message;
  final bool authenticated;
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this.auth) : super(const AuthState());
  final GoTrueClient auth;

  void toggleMode() {
    if (!state.busy) emit(AuthState(register: !state.register));
  }

  Future<void> submit(String email, String password) async {
    if (isClosed || state.busy) return;
    final register = state.register;
    emit(AuthState(register: register, busy: true));
    try {
      final response = register
          ? await auth.signUp(email: email.trim(), password: password)
          : await auth.signInWithPassword(
              email: email.trim(),
              password: password,
            );
      if (isClosed) return;
      emit(
        AuthState(
          register: register,
          authenticated: response.session != null,
          message: response.session == null
              ? 'Kiểm tra email để xác nhận tài khoản, sau đó đăng nhập.'
              : null,
        ),
      );
    } on AuthException catch (error) {
      if (!isClosed) {
        emit(AuthState(register: register, message: authErrorMessage(error)));
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          AuthState(
            register: register,
            message: 'Không thể kết nối. Vui lòng thử lại.',
          ),
        );
      }
    }
  }
}
