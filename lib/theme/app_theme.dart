import 'package:flutter/material.dart';

/// Paleta extraída do theme.css do projeto Figma original.
/// As cores em oklch foram convertidas para os equivalentes RGB mais próximos.
class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const foreground = Color(0xFF252525); // oklch(0.145 0 0)
  static const card = Color(0xFFFFFFFF);
  static const cardForeground = Color(0xFF252525);
  static const primary = Color(0xFF030213);
  static const primaryForeground = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFF0F0F4);
  static const secondaryForeground = Color(0xFF030213);
  static const muted = Color(0xFFECECF0);
  static const mutedForeground = Color(0xFF717182);
  static const accent = Color(0xFFE9EBEF);
  static const accentForeground = Color(0xFF030213);
  static const destructive = Color(0xFFD4183D);
  static const destructiveForeground = Color(0xFFFFFFFF);
  static const border = Color(0x1A000000); // rgba(0,0,0,0.1)
  static const inputBackground = Color(0xFFF3F3F5);

  // Cores auxiliares usadas em estatísticas e gráficos (equivalentes ao Tailwind)
  static const green600 = Color(0xFF16A34A);
  static const green100 = Color(0xFFDCFCE7);
  static const green700 = Color(0xFF15803D);
  static const red600 = Color(0xFFDC2626);
  static const red100 = Color(0xFFFEE2E2);
  static const red700 = Color(0xFFB91C1C);
  static const yellow600 = Color(0xFFCA8A04);
  static const blue600 = Color(0xFF2563EB);
  static const blue50 = Color(0xFFEFF6FF);
  static const blue200 = Color(0xFFBFDBFE);
  static const indigo50 = Color(0xFFEEF2FF);

  // Cores dos gráficos de pizza/barra (mesmas do array COLORS em finances.tsx)
  static const chart = [
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];
}

class AppTheme {
  static ThemeData get light {
    const radius = 10.0; // --radius: 0.625rem
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.primaryForeground,
        secondary: AppColors.secondary,
        onSecondary: AppColors.secondaryForeground,
        surface: AppColors.card,
        onSurface: AppColors.cardForeground,
        error: AppColors.destructive,
        onError: AppColors.destructiveForeground,
      ),
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.foreground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 2),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 2),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 2),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryForeground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius - 2),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.foreground,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius - 2),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    );
  }
}
