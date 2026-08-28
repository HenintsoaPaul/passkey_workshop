import 'package:flutter/material.dart';

import '../app_config.dart';
import '../session/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/placeholders.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/logs_sheet.dart';
import '../widgets/passkey_button.dart';

/// Account, diagnostics and sign-out.
///
/// No mockup exists for this tab, so the layout is derived from the design
/// system's card and list conventions.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        children: [
          const Text('Paramètres', style: AppTypography.headlineLg),

          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: Row(
              children: [
                const UserAvatar(size: 48),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.username ?? 'Invité',
                        style: AppTypography.headlineSm,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Connecté via passkey',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.terminal,
                  title: 'Journaux de débogage',
                  subtitle: 'Trace des cérémonies passkey',
                  onTap: () => showLogsSheet(context, session),
                ),

                const Divider(indent: AppSpacing.md, endIndent: AppSpacing.md),

                _SettingsRow(
                  icon: Icons.dns,
                  title: 'Hôte du serveur',
                  subtitle: AppConfig.apiBaseUrl,
                  // Read-only: the host is set in assets/config.json.
                  onTap: null,
                ),

                const Divider(indent: AppSpacing.md, endIndent: AppSpacing.md),

                _SettingsRow(
                  icon: Icons.info_outline,
                  title: 'À propos',
                  subtitle: 'SignApp Passkey',
                  onTap: () => showComingSoon(context, 'À propos'),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Clearing the session is enough: the root widget listens to it and
          // swaps back to the auth screen.
          PasskeyButton.outlined(
            label: 'Se déconnecter',
            icon: Icons.logout,
            color: AppColors.error,
            onPressed: session.signOut,
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTypography.bodyLg),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelMd,
      ),
      trailing: onTap == null
          ? null
          : const Icon(
              Icons.chevron_right,
              color: AppColors.onSurfaceVariant,
            ),
    );
  }
}
