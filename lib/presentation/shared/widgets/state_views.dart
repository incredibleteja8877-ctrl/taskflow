import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/error/app_exception.dart';

/// Full-screen spinner. Used while a first load is in flight.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// "Nothing here yet" — a successful load that returned zero rows.
///
/// Deliberately distinct from [ErrorView]: an empty list is not a failure, and
/// showing a red error for it is one of the most common UX mistakes in this
/// kind of app. Task 06 lists `empty` as its own state for exactly this reason.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders any failure, with an icon and message chosen per error type.
///
/// The `switch` below is exhaustive over the sealed [AppException] hierarchy —
/// add a new exception type and this file stops compiling until you decide how
/// it should look. That is the payoff for making AppException `sealed`: no
/// error can ever reach a user as a blank screen.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, message) = _describe(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (IconData, String) _describe(Object error) {
    if (error is! AppException) {
      // Anything that is not an AppException escaped a repository's guard.
      // Never show the raw object — it can contain internals.
      return (Icons.error_outline, 'Something went wrong. Please try again.');
    }

    return switch (error) {
      NotFoundException() => (Icons.search_off, error.message),
      NetworkTimeoutException() => (Icons.timer_off_outlined, error.message),
      OfflineException() => (Icons.cloud_off_outlined, error.message),
      UnauthorizedException() => (Icons.lock_outline, error.message),
      ForbiddenException() => (Icons.block_outlined, error.message),
      ValidationException() => (Icons.rule_outlined, error.message),
      UnknownException() => (Icons.error_outline, error.message),
    };
  }
}

/// A thin banner shown above stale content while offline.
/// Task 08: "clearly indicate when displayed data may be stale".
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.lastUpdated});

  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 18,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                lastUpdated == null
                    ? 'Offline — showing saved data.'
                    : 'Offline — data may be out of date.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
