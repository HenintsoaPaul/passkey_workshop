import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// 64px top bar with the brand lockup, matching every mockup.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key})
      : title = null,
        showBackButton = false;

  /// Variant used on pushed routes: back arrow, centred title, avatar.
  const AppTopBar.withBack({super.key, this.title})
      : showBackButton = true;

  final String? title;
  final bool showBackButton;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    // Scaffold allots preferredSize plus the status bar inset, so the bar
    // sizes itself around a SafeArea rather than pinning an outer height.
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
          ),
          child: Row(
            children: [
              if (showBackButton)
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  color: AppColors.primary,
                  tooltip: 'Retour',
                )
              else
                const Icon(
                  Icons.security,
                  color: AppColors.primary,
                ),

              const SizedBox(width: AppSpacing.sm),

              Expanded(
                child: Text(
                  title ?? 'SignApp Passkey',
                  textAlign:
                      showBackButton ? TextAlign.center : TextAlign.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (showBackButton
                          ? AppTypography.headlineSm
                          : AppTypography.headlineMd)
                      .copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              const UserAvatar(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular avatar placeholder.
///
/// The mockups point at `lh3.googleusercontent.com` URLs that are not part of
/// this project, and `mes_documents` already falls back to an icon, so the
/// icon treatment is used everywhere for consistency.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceContainerHigh,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Icon(
        Icons.person,
        size: size * 0.6,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}
