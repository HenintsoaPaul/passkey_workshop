import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Label/value row on a low surface, used for document metadata.
class MetaRow extends StatelessWidget {
  const MetaRow({
    super.key,
    required this.label,
    required this.value,
    this.tooltip,
  });

  final String label;
  final String value;

  /// Full text behind a truncated [value], e.g. a complete SHA-256 digest.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget valueText = Text(
      value,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.bodyMd,
    );

    if (tooltip != null) {
      valueText = Tooltip(message: tooltip!, child: valueText);
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Text(label, style: AppTypography.labelMd),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: valueText,
            ),
          ),
        ],
      ),
    );
  }
}
