import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// Horizontal progress bar with the completion count at the top right, per
/// `DESIGN.md` § Signature Progress Bar.
class SignatureProgress extends StatelessWidget {
  const SignatureProgress({
    super.key,
    required this.signedCount,
    required this.totalCount,
  });

  final int signedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final progress = totalCount == 0 ? 0.0 : signedCount / totalCount;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text(
                  'Progression des signatures',
                  style: AppTypography.headlineSm,
                ),
              ),
              Text(
                '$signedCount sur $totalCount signés',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.cardBorder,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
