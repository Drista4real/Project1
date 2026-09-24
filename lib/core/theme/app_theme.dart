import 'package:flutter/material.dart';

/// Design System: Kakeibo Zen (Từ Google Stitch)
class AppTheme {
  // Brand Colors từ Stitch "Kakeibo Zen"
  static const Color primaryForestGreen = Color(0xFF0D5C46); // Xanh rừng Kakeibo
  static const Color secondaryMint = Color(0xFFD8EDE2); // Xanh mint nhạt
  static const Color lightMintBg = Color(0xFFEBF5F0);
  static const Color bgCanvas = Color(0xFFF6F8F7); // Nền xám ngà siêu nhẹ
  static const Color cardSurface = Colors.white;

  // Accents & Signals
  static const Color expenseCoral = Color(0xFFDC2626); // Đỏ chi tiêu
  static const Color incomeEmerald = Color(0xFF16A34A); // Xanh lá thu nhập
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color textCharcoal = Color(0xFF1F2937); // Chữ đậm chính
  static const Color textMuted = Color(0xFF6B7280); // Chữ phụ mờ
  static const Color borderLight = Color(0xFFE5E7EB);

  static ThemeData get kakeiboTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: bgCanvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryForestGreen,
        primary: primaryForestGreen,
        secondary: secondaryMint,
        surface: cardSurface,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgCanvas,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textCharcoal,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: primaryForestGreen),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryForestGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }
}
