import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';

import 'package:project_one/app/kakeibo_app.dart';
import 'package:project_one/core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep the accessibility DOM available throughout browser automation runs.
  if (kIsWeb && const bool.fromEnvironment('ENABLE_WEB_SEMANTICS')) {
    SemanticsBinding.instance.ensureSemantics();
  }

  // Khởi tạo Supabase client
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  runApp(const KakeiboZenApp());
}
