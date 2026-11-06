import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Must match the backend's SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY. A token
  // signed by another Supabase project is rejected with 401 by the backend.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wvzceuvziyeppmkrozqk.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind2emNldXZ6aXllcHBta3JvenFrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMyNTY2MTIsImV4cCI6MjEwODgzMjYxMn0.gTeom8Em0OG3Jhrf7XPK6LIe0-pVCkn1e6yY2JLD3gQ',
  );

  static Future<void> initialize() async {
    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
      );
    }
  }

  /// Shorthand truy cập Supabase client toàn cục
  static SupabaseClient get client => Supabase.instance.client;

  /// Kiểm tra xem người dùng hiện tại đã đăng nhập chưa
  static User? get currentUser => client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;
}
