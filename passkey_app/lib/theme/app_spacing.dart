/// Spacing tokens from `DESIGN.md`, built on a 4px baseline grid.
class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const gutter = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;

  /// Side margin held on every mobile screen.
  static const pageMargin = 16.0;

  /// Minimum touch target for icon actions inside cards.
  static const touchTarget = 44.0;
}

/// Corner radii, following the mockups' Tailwind override rather than the
/// prose in `DESIGN.md`: `rounded-lg` is 8px and `rounded-xl` is 12px there.
class AppRadius {
  AppRadius._();

  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 16.0;
}
