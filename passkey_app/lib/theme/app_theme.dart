import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles the dark, security-first theme described in `DESIGN.md`.
///
/// Component themes are configured here so screens can stay declarative and
/// avoid restating the same paddings, radii and colours.
ThemeData buildAppTheme() {
  const colorScheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.secondaryFixed,
    onSecondary: AppColors.onPrimary,
    tertiary: AppColors.tertiary,
    error: AppColors.error,
    onError: AppColors.onPrimary,
    surface: AppColors.background,
    onSurface: AppColors.onSurface,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surfaceContainerLow,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerHigh: AppColors.surfaceContainerHigh,
    surfaceContainerHighest: AppColors.surfaceContainerHighest,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
  );

  const textTheme = TextTheme(
    headlineLarge: AppTypography.headlineLg,
    headlineMedium: AppTypography.headlineMd,
    headlineSmall: AppTypography.headlineSm,
    titleMedium: AppTypography.headlineSm,
    bodyLarge: AppTypography.bodyLg,
    bodyMedium: AppTypography.bodyMd,
    labelLarge: AppTypography.button,
    labelMedium: AppTypography.labelMd,
    labelSmall: AppTypography.labelSm,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    textTheme: textTheme,
    fontFamily: AppTypography.fontFamily,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    dividerColor: AppColors.outlineVariant,

    dividerTheme: const DividerThemeData(
      color: AppColors.outlineVariant,
      thickness: 1,
      space: 1,
    ),

    iconTheme: const IconThemeData(
      color: AppColors.onSurfaceVariant,
      size: 24,
    ),

    // Interaction shifts the fill rather than raising an elevation, per
    // DESIGN.md's "Elevation & Depth" section.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.surfaceContainerHigh,
        disabledForegroundColor: AppColors.outline,
        textStyle: AppTypography.button,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.gutter,
        ),
        elevation: 0,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppTypography.button,
        side: const BorderSide(color: AppColors.primary),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.gutter,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppTypography.labelMd.copyWith(
          color: AppColors.primary,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.background,
      hintStyle: AppTypography.bodyMd.copyWith(
        color: AppColors.outline,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.gutter,
      ),
      border: _inputBorder(AppColors.cardBorder),
      enabledBorder: _inputBorder(AppColors.cardBorder),
      focusedBorder: _inputBorder(AppColors.primary),
      errorBorder: _inputBorder(AppColors.error),
      focusedErrorBorder: _inputBorder(AppColors.error),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceContainerHigh,
      contentTextStyle: AppTypography.bodyMd,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
    ),
  );
}

OutlineInputBorder _inputBorder(Color color) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: BorderSide(color: color),
  );
}
