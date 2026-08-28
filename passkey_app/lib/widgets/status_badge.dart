import 'package:flutter/material.dart';

import '../models/document.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Pill badge with a 10% fill and a 20% border of the status colour, over
/// fully opaque text — the recipe given in `DESIGN.md`.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  StatusBadge.document(DocumentStatus status, {super.key})
      : label = status.badgeLabel,
        color = status.color,
        icon = null;

  StatusBadge.signer(SignerStatus status, {super.key})
      : label = status.label,
        color = status.color,
        icon = status.icon;

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.labelSm.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
