import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/validators.dart';
import '../providers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Field errors returned by the "server", keyed by field name.
  /// Cleared the moment the user edits the offending field.
  Map<String, String> _serverErrors = const {};

  bool _obscurePassword = true;

  @override
  void dispose() {
    // Controllers hold native resources. Forgetting this is the most common
    // memory leak in Flutter, and Task 13 lists "no obvious memory leaks".
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _serverErrors = const {});
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    ref.read(authControllerProvider.notifier).login(
          email: _emailController.text,
          password: _passwordController.text,
        );
    // Deliberately no navigation here. The router's redirect owns that.
  }

  void _clearServerError(String field) {
    if (!_serverErrors.containsKey(field)) return;
    setState(() => _serverErrors = {..._serverErrors}..remove(field));
  }

  void _showFailure(Object error) {
    if (!mounted) return;

    if (error is ValidationException && error.fieldErrors.isNotEmpty) {
      setState(() => _serverErrors = error.fieldErrors);
      _formKey.currentState?.validate();
      return;
    }

    final message =
        error is AppException ? error.message : 'Something went wrong.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final isBusy = state.isLoading;
    final theme = Theme.of(context);

    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) _showFailure(next.error!);
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              // Task 09: responsive. On a tablet the form stops stretching
              // rather than becoming one unreadable full-width line.
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Welcome back',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Sign in to continue to TaskFlow',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextFormField(
                      controller: _emailController,
                      enabled: !isBusy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) =>
                          Validators.email(value) ?? _serverErrors['email'],
                      onChanged: (_) => _clearServerError('email'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !isBusy,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? 'Show' : 'Hide',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (value) =>
                          Validators.password(value) ??
                          _serverErrors['password'],
                      onChanged: (_) => _clearServerError('password'),
                      onFieldSubmitted: isBusy ? null : (_) => _submit(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: isBusy ? null : _submit,
                      child: isBusy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed:
                          isBusy ? null : () => context.push(Routes.register),
                      child: const Text(
                        "Don't have an account? Create one",
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
