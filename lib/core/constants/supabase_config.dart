import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://syjigvtyxfkmmqipxufm.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_gexOlWlrEdiPuyda9jixOA_cujZIIOX';

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
