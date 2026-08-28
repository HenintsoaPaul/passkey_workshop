import 'package:flutter/material.dart';

/// Feedback for actions whose backend does not exist yet.
///
/// Shown instead of doing nothing silently, so it is obvious in the running
/// app which affordances are still placeholders.
void showComingSoon(BuildContext context, String action) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$action : fonctionnalité à venir'),
        duration: const Duration(seconds: 2),
      ),
    );
}
