import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  // ProviderScope is the root of the dependency graph. Everything in
  // core/di/providers.dart is resolved from here, and a test can replace any
  // of it with `ProviderScope(overrides: [...])`.
  runApp(const ProviderScope(child: TaskFlowApp()));
}

class TaskFlowApp extends ConsumerWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Task 09 bonus: dark mode, driven by the OS setting.
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
