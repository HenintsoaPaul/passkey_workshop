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
    this.helperText,
    this.enabled = true,
    this.obscureText = false,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;

  /// Explains what the field is for, under the input.
  final String? helperText;

  final bool enabled;
  final bool obscureText;
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
          obscureText: obscureText,
          autocorrect: false,
          enableSuggestions: !obscureText,
          textInputAction: TextInputAction.done,
          onSubmitted: onSubmitted,
          style: AppTypography.bodyMd,
          decoration: InputDecoration(
            hintText: hintText,
            helperText: helperText,
            helperMaxLines: 3,
            helperStyle: AppTypography.labelSm,
          ),
        ),
      ],
    );
  }
}
