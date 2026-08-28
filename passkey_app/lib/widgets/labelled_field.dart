import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Input field with its label placed above it, per `DESIGN.md` § Input Fields.
class LabelledField extends StatelessWidget {
  const LabelledField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.enabled = true,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelMd),

        const SizedBox(height: AppSpacing.sm),

        TextField(
          controller: controller,
          enabled: enabled,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: onSubmitted,
          style: AppTypography.bodyMd,
          decoration: InputDecoration(hintText: hintText),
        ),
      ],
    );
  }
}
