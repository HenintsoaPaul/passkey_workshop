import 'package:flutter/material.dart';

import '../models/document.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'app_card.dart';

/// Vertical audit trail: a rule with a dot per entry, the newest highlighted
/// in the primary colour.
class AuditTimeline extends StatelessWidget {
  const AuditTimeline({super.key, required this.events});

  final List<AuditEvent> events;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < events.length; i++)
            _TimelineEntry(
              event: events[i],
              isFirst: i == 0,
              isLast: i == events.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  final AuditEvent event;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final titleColor =
        isFirst ? AppColors.onSurface : AppColors.onSurfaceVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TimelineRule(isFirst: isFirst, isLast: isLast),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTypography.button.copyWith(color: titleColor),
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  Text(
                    event.description,
                    style: AppTypography.bodyMd.copyWith(
                      color: isFirst
                          ? AppColors.onSurfaceVariant
                          : AppColors.outline,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  Text(
                    formatAuditTimestamp(event.timestamp),
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  _ActorChip(
                    icon: event.icon,
                    name: event.actor,
                    highlighted: isFirst,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRule extends StatelessWidget {
  const _TimelineRule({required this.isFirst, required this.isLast});

  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      child: Column(
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: AppSpacing.xs),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFirst ? AppColors.primary : AppColors.outline,
            ),
          ),
          if (!isLast)
            const Expanded(
              child: VerticalDivider(
                color: AppColors.outlineVariant,
                thickness: 1,
                width: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActorChip extends StatelessWidget {
  const _ActorChip({
    required this.icon,
    required this.name,
    required this.highlighted,
  });

  final IconData icon;
  final String name;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: highlighted
                ? AppColors.primary
                : AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMd,
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: highlighted ? chip : Opacity(opacity: 0.7, child: chip),
    );
  }
}
