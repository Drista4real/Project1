import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';

import 'package:project_one/app/kakeibo_app.dart';
import 'package:project_one/core/config/supabase_config.dart';
import 'package:project_one/app/app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep the accessibility DOM available throughout browser automation runs.
  if (kIsWeb && const bool.fromEnvironment('ENABLE_WEB_SEMANTICS')) {
    SemanticsBinding.instance.ensureSemantics();
  }

  // Khởi tạo Supabase client
  try {
    await SupabaseConfig.initialize();
    await AppDependencies.preferences.loadUser(SupabaseConfig.currentUser?.id);
    SupabaseConfig.client.auth.onAuthStateChange.listen((event) async {
      if (event.event.name == 'signedIn' || event.event.name == 'signedOut') {
        await AppDependencies.preferences.loadUser(event.session?.user.id);
      }
    });
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
    await AppDependencies.preferences.loadUser(null);
  }
  runApp(const KakeiboZenApp());
}
