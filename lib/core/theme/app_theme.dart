import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light => build();
  static ThemeData build({
    bool highContrast = false,
    bool largeButtons = false,
  }) {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
      primary: highContrast ? const Color(0xff004536) : AppColors.primary,
      secondary: highContrast ? const Color(0xff005838) : AppColors.community,
      error: highContrast ? const Color(0xff971523) : AppColors.sos,
      onSurfaceVariant: highContrast ? Colors.black87 : null,
      surface: Colors.white,
      onSurface: AppColors.ink,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: highContrast
          ? AppTypography.text.apply(
              bodyColor: Colors.black,
              displayColor: Colors.black,
            )
          : AppTypography.text,
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: largeButtons ? largeStyle : null,
      ),
      textButtonTheme: TextButtonThemeData(
        style: largeButtons ? largeStyle : null,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: largeButtons
            ? const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size.square(56)),
              )
            : null,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: largeButtons ? 88 : null,
        backgroundColor: Colors.white,
        indicatorColor: Color(0xffd9f2e7),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: shape.copyWith(side: const BorderSide(color: AppColors.border)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size.square(largeButtons ? 56 : 48),
          padding: largeButtons
              ? const EdgeInsets.symmetric(vertical: 16, horizontal: 20)
              : null,
          shape: shape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: shape.borderRadius as BorderRadius,
        ),
      ),
    );
  }

  static const largeStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size.square(56)),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    ),
  );
}
