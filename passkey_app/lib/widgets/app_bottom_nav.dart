import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// One destination of the bottom navigation bar.
class AppNavDestination {
  const AppNavDestination({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

const appNavDestinations = [
  AppNavDestination(icon: Icons.dashboard, label: 'Dashboard'),
  AppNavDestination(icon: Icons.description, label: 'Documents'),
  AppNavDestination(icon: Icons.verified_user, label: 'Verify'),
  AppNavDestination(icon: Icons.settings, label: 'Settings'),
];

/// 80px navigation bar. The selected destination is a filled pill, matching
/// the mockups; unselected destinations are plain icon + label.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainer,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              for (var i = 0; i < appNavDestinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: appNavDestinations[i],
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutter,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color:
                  selected ? AppColors.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(destination.icon, color: color),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMd.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
