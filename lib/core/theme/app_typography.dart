import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const text = TextTheme(
    headlineSmall: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
    titleMedium: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
    bodyMedium: TextStyle(color: AppColors.secondaryText),
  );
}
