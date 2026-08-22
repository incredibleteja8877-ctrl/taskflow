import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import 'state_views.dart';

/// Bottom-navigation shell around the four top-level destinations.
///
/// Uses go_router's StatefulShellRoute, so each tab keeps its own navigation
/// stack and scroll position — switching to Tasks and back to Projects does
/// not reset where you were. Task 09: "proper navigation and back-navigation
/// handling".
///
/// It also hosts the offline banner, so the stale-data warning appears on
/// every screen rather than being repeated in each one.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(
      mockApiConfigProvider.select((config) => config.isOffline),
    );
    final lastSynced = ref.watch(lastSyncedAtProvider).valueOrNull;

    return Scaffold(
      body: Column(
        children: [
          if (isOffline)
            SafeArea(
              bottom: false,
              child: OfflineBanner(lastUpdated: lastSynced),
            ),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the tab you are already on pops that branch back to its
          // root, which is what every native app does.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
