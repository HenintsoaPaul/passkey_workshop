import 'package:flutter/material.dart';

import '../session/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Bottom sheet listing the passkey ceremony trace held by [AppSession].
///
/// This is real diagnostic output, not a placeholder: every entry is written
/// by the register/login flows on the auth screen.
Future<void> showLogsSheet(BuildContext context, AppSession session) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _LogsSheet(session: session),
  );
}

class _LogsSheet extends StatelessWidget {
  const _LogsSheet({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: AnimatedBuilder(
        animation: session,
        builder: (context, _) {
          final logs = session.logs;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.terminal, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(
                      child: Text(
                        'Journaux de débogage',
                        style: AppTypography.headlineSm,
                      ),
                    ),
                    Text(
                      '${logs.length} entrée${logs.length > 1 ? 's' : ''}',
                      style: AppTypography.labelMd,
                    ),
                  ],
                ),
              ),

              const Divider(),

              Expanded(
                child: logs.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun journal pour le moment',
                          style: AppTypography.bodyMd,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: logs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) => Text(
                          logs[index],
                          style: AppTypography.labelMd,
                        ),
                      ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md +
                      MediaQuery.of(context).padding.bottom,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: logs.isEmpty
                        ? null
                        : () {
                            session.clearLogs();
                            Navigator.pop(context);
                          },
                    child: const Text('Effacer les journaux'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
