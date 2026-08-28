import 'package:flutter/material.dart';

/// Colour tokens from `DESIGN.md` and the mockups in `mockup/`.
///
/// Where the design tokens and the mockup stylesheets disagree, the mockups
/// win, because they are what the reference screenshots actually render.
class AppColors {
  AppColors._();

  // Surfaces.
  static const background = Color(0xFF0F111A);
  static const surface = Color(0xFF11131C);
  static const surfaceContainerLow = Color(0xFF191B24);
  static const surfaceContainer = Color(0xFF1D1F29);
  static const surfaceContainerHigh = Color(0xFF282933);
  static const surfaceContainerHighest = Color(0xFF32343E);

  /// Level 1 elevation: cards sit on [card] with a [cardBorder] outline
  /// instead of a drop shadow.
  static const card = Color(0xFF1A1D2D);
  static const cardBorder = Color(0xFF252B44);

  // Content.
  static const onSurface = Color(0xFFE1E1EF);
  static const onSurfaceVariant = Color(0xFFD2C1D5);
  static const outline = Color(0xFF9B8C9E);
  static const outlineVariant = Color(0xFF4F4353);

  // Accents.
  static const primary = Color(0xFFE8B3FF);
  static const onPrimary = Color(0xFF500074);
  static const primaryContainer = Color(0xFFC961FF);
  static const onPrimaryContainer = Color(0xFF460066);
  static const secondaryFixed = Color(0xFFDDE1FF);
  static const tertiary = Color(0xFFFFB0CE);
  static const error = Color(0xFFFFB4AB);

  // Signature status colours.
  static const statusWaiting = Color(0xFFF59E0B);
  static const statusSigned = Color(0xFF10B981);
  static const statusDraft = Color(0xFF64748B);

  /// Partially signed: between waiting amber and signed green, and distinct
  /// from both so a half-signed document is never mistaken for either.
  static const statusPartial = Color(0xFF38BDF8);
}
