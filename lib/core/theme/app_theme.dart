import 'package:flutter/material.dart';

import 'tokens.dart';

/// Light + dark themes built from [AppTokens]. No green anywhere; success
/// feedback uses textPrimary/white + check icon (UI spec §5).
class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.light(
      primary: AppTokens.primaryLight,
      onPrimary: AppTokens.onPrimaryLight,
      surface: AppTokens.surfaceLight,
      error: AppTokens.dangerLight,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppTokens.backgroundLight,
      dividerColor: AppTokens.dividerLight,
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.dark(
      primary: AppTokens.primaryDark,
      onPrimary: AppTokens.onPrimaryDark,
      surface: AppTokens.surfaceDark,
      error: AppTokens.dangerDark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppTokens.backgroundDark,
      dividerColor: AppTokens.dividerDark,
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }

  /// Camera screens (S05, S06) are always dark regardless of system theme.
  static ThemeData camera() => dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      );
}
