import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale from `DESIGN.md`.
///
/// The system is unified under a single family: labels get their technical
/// feel from a medium weight plus 0.05em tracking rather than a mono face.
/// `letterSpacing` is expressed in logical pixels, so the em values from the
/// design tokens are multiplied by their font size.
class AppTypography {
  AppTypography._();

  static const fontFamily = 'HankenGrotesk';

  static const headlineLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.56,
    color: AppColors.onSurface,
  );

  static const headlineMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.22,
    color: AppColors.onSurface,
  );

  static const headlineSm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  static const bodyLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static const bodyMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static const button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w600,
  );

  static const labelMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
    color: AppColors.onSurfaceVariant,
  );

  static const labelSm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    height: 14 / 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: AppColors.onSurfaceVariant,
  );
}
