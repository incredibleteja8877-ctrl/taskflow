import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/di/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/local_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolved before the first frame so no screen has to handle "the cache is
  // not ready yet". The provider itself is override-only, which keeps the
  // async plugin setup out of the widget tree.
  final preferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      // ProviderScope is the root of the dependency graph. Everything in
      // core/di/providers.dart resolves from here, and a test can replace any
      // of it via ProviderScope(overrides: [...]).
      overrides: [
        localCacheProvider.overrideWithValue(
          SharedPrefsLocalCache(preferences),
        ),
      ],
      child: const TaskFlowApp(),
    ),
  );
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
