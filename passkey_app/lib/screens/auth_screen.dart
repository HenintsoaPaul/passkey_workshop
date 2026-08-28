import 'package:flutter/material.dart';

import '../api.dart';
import '../passkey_service.dart';
import '../session/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_card.dart';
import '../widgets/labelled_field.dart';
import '../widgets/logs_sheet.dart';
import '../widgets/passkey_button.dart';

/// Entry point of the app: authenticate with a passkey, or enroll one.
///
/// Both actions run the real WebAuthn ceremonies against the Django backend
/// configured in `assets/config.json`. On success the session is marked as
/// signed in and the root widget swaps this screen for the tab shell.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.passkeyService,
    required this.session,
  });

  final PasskeyService passkeyService;
  final AppSession session;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _PendingAction { none, login, register }

class _AuthScreenState extends State<AuthScreen> {
  final _usernameController = TextEditingController();

  _PendingAction _pending = _PendingAction.none;
  String? _message;
  bool _isError = false;

  bool get _busy => _pending != _PendingAction.none;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _setMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    setState(() {
      _message = message;
      _isError = isError;
    });
  }

  /// Returns the trimmed username, or null after reporting that it is missing.
  String? _readUsername() {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      _setMessage("Saisissez d'abord un nom d'utilisateur.", isError: true);
      return null;
    }

    return username;
  }

  Future<void> _register() async {
    final username = _readUsername();

    if (username == null) {
      return;
    }

    setState(() {
      _pending = _PendingAction.register;
      _message = null;
    });

    try {
      widget.session.addLog('Starting registration for $username');

      final options = await Api.registerOptions(username);
      widget.session.addLog('Registration options received');

      final credential =
          await widget.passkeyService.createPasskey(options);
      widget.session.addLog('Passkey created by Credential Manager');

      await Api.registerVerify(username, credential.toJson());
      widget.session.addLog('Registration successful for $username');

      _setMessage('Passkey créée. Vous pouvez vous connecter.');
    } catch (e) {
      widget.session.addLog('Registration error: $e');
      _setMessage('Échec de la création de la passkey.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _pending = _PendingAction.none);
      }
    }
  }

  Future<void> _login() async {
    final username = _readUsername();

    if (username == null) {
      return;
    }

    setState(() {
      _pending = _PendingAction.login;
      _message = null;
    });

    try {
      widget.session.addLog('Starting login for $username');

      final options = await Api.loginOptions(username);
      widget.session.addLog('Login options received');

      final credential =
          await widget.passkeyService.authenticate(options);
      widget.session.addLog('Passkey retrieved by Credential Manager');

      await Api.loginVerify(credential.toJson());
      widget.session.addLog('Login successful for $username');

      widget.session.signIn(username);
    } catch (e) {
      widget.session.addLog('Login error: $e');
      _setMessage('Échec de la connexion.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _pending = _PendingAction.none);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pageMargin),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _AuthHeader(),

                  const SizedBox(height: AppSpacing.xl),

                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LabelledField(
                          label: "NOM D'UTILISATEUR",
                          controller: _usernameController,
                          hintText: 'jean.dupont',
                          enabled: !_busy,
                          onSubmitted: (_) => _login(),
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        PasskeyButton(
                          label: 'Se connecter avec une passkey',
                          icon: Icons.key,
                          busy: _pending == _PendingAction.login,
                          enabled: !_busy,
                          onPressed: _login,
                        ),

                        const SizedBox(height: AppSpacing.gutter),

                        PasskeyButton.outlined(
                          label: 'Créer une passkey',
                          icon: Icons.add,
                          busy: _pending == _PendingAction.register,
                          enabled: !_busy,
                          onPressed: _register,
                        ),
                      ],
                    ),
                  ),

                  if (_message != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _StatusMessage(message: _message!, isError: _isError),
                  ],

                  const SizedBox(height: AppSpacing.md),

                  TextButton.icon(
                    onPressed: () =>
                        showLogsSheet(context, widget.session),
                    icon: const Icon(Icons.terminal, size: 16),
                    label: const Text('Voir les journaux'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.1),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: const Icon(
            Icons.security,
            size: 36,
            color: AppColors.primary,
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        Text(
          'SignApp Passkey',
          textAlign: TextAlign.center,
          style: AppTypography.headlineLg.copyWith(
            color: AppColors.primary,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        const Text(
          'Signez vos documents en toute sécurité, sans mot de passe.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMd,
        ),
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.statusSigned;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle,
            size: 18,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMd.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
