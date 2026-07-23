import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/badges/presentation/badge_celebration.dart';
import '../../features/widget/home_widget_sync.dart';
import '../constants/app_strings.dart';

/// Bottom-navigation scaffold hosting the four main tabs.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BadgeCelebrationListener(
        child: HomeWidgetSyncListener(child: navigationShell),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny_rounded),
            label: AppStrings.navToday,
          ),
          NavigationDestination(
            icon: Icon(Icons.restart_alt_outlined),
            selectedIcon: Icon(Icons.restart_alt_rounded),
            label: AppStrings.navReset,
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: AppStrings.navProgress,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: AppStrings.navProfile,
          ),
        ],
      ),
    );
  }
}
