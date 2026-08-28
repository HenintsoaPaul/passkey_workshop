import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The most prominent component in the system: a full-width pill button with
/// a leading icon, per `DESIGN.md` § Passkey Authentication Buttons.
///
/// While [busy] is set the icon is replaced by a spinner and taps are ignored.
class PasskeyButton extends StatelessWidget {
  const PasskeyButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.enabled = true,
  }) : _outlined = false,
       color = null;

  /// Secondary variant: same shape, outlined instead of filled.
  const PasskeyButton.outlined({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.enabled = true,
    this.color,
  }) : _outlined = true;

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool busy;
  final bool enabled;
  final bool _outlined;

  /// Overrides the outline/foreground colour, used for destructive actions.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final callback = (busy || !enabled) ? null : onPressed;

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _outlined
                  ? (color ?? AppColors.primary)
                  : AppColors.onPrimary,
            ),
          )
        else
          Icon(icon, size: 20),

        const SizedBox(width: AppSpacing.sm),

        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return SizedBox(
      width: double.infinity,
      child: _outlined
          ? OutlinedButton(
              onPressed: callback,
              style: color == null
                  ? null
                  : OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color!),
                    ),
              child: child,
            )
          : FilledButton(
              onPressed: callback,
              child: child,
            ),
    );
  }
}
