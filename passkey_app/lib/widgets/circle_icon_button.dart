import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Circular outlined icon action sized to the 44x44 minimum touch target
/// `DESIGN.md` requires for actions inside document cards.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Gives the button a container fill, as in the documents list.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.touchTarget,
      height: AppSpacing.touchTarget,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          backgroundColor: filled ? AppColors.surfaceContainer : null,
          side: const BorderSide(color: AppColors.outlineVariant),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}
