import 'package:flutter/material.dart';

import 'package:project_one/app/kakeibo_app.dart';
import 'package:project_one/core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Supabase client
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  runApp(const KakeiboZenApp());
}
