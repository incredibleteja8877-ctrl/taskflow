import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';

/// Shown while [AuthController.build] checks for a stored session.
///
/// It has no logic of its own on purpose. The router decides when to leave;
/// this screen just occupies the moment. Screens that navigate themselves are
/// how you end up with two competing sources of truth about where the user is.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('TaskFlow', style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
