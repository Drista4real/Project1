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
    runApp(KakeiboZenApp(auth: SupabaseConfig.client.auth));
  } catch (_) {
    await AppDependencies.preferences.loadUser(null);
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Không thể khởi tạo ứng dụng. Vui lòng kiểm tra kết nối và mở lại app.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
