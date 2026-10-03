import 'package:flutter/material.dart';

/// Design System: Kakeibo Zen
class AppTheme {
  // Brand Colors từ Stitch "Kakeibo Zen"
  static const Color primaryForestGreen = Color(0xFF2D5A43); // Deep sage
  static const Color secondaryMint = Color(0xFFD8EDE2); // Soft mint
  static const Color lightMintBg = Color(0xFFF1F5F0);
  static const Color bgCanvas = Color(0xFFF6FBF5); // Warm porcelain
  static const Color cardSurface = Colors.white;

  // Accents & Signals
  static const Color expenseCoral = Color(0xFFD96B43); // Terracotta outflow
  static const Color incomeEmerald = Color(0xFF4E9F86); // Soft jade
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color textCharcoal = Color(0xFF1F2421); // Sumi charcoal
  static const Color textMuted = Color(0xFF7B8782); // Slate stone
  static const Color borderLight = Color(0xFFE5E7DF);

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
