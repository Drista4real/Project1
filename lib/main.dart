import 'package:flutter/material.dart';
import 'core/constants/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/dashboard_screen.dart';

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

class KakeiboZenApp extends StatelessWidget {
  const KakeiboZenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kakeibo Zen - Sổ Thu Chi & Dự Báo Dòng Tiền AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.kakeiboTheme,
      home: const DashboardScreen(),
    );
  }
}
