import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/app_routes.dart';

enum AppShellTab {
  home(
    route: AppRoutes.home,
    label: 'Home',
    title: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  daily(
    route: AppRoutes.daily,
    label: 'Daily',
    title: 'Daily Challenges',
    icon: Icons.calendar_today_outlined,
    selectedIcon: Icons.calendar_today,
  ),
  puzzles(
    route: AppRoutes.puzzles,
    label: 'Puzzles',
    title: 'Puzzles',
    icon: Icons.extension_outlined,
    selectedIcon: Icons.extension,
  ),
  profile(
    route: AppRoutes.profile,
    label: 'Profile',
    title: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  );

  const AppShellTab({
    required this.route,
    required this.label,
    required this.title,
    required this.icon,
    required this.selectedIcon,
  });

  final String route;
  final String label;
  final String title;
  final IconData icon;
  final IconData selectedIcon;

  static AppShellTab fromLocation(String location) {
    if (location == AppRoutes.daily ||
        location.startsWith('${AppRoutes.daily}/')) {
      return AppShellTab.daily;
    }
    if (location == AppRoutes.puzzles ||
        location == AppRoutes.legacyPuzzles ||
        location.startsWith('${AppRoutes.puzzles}/')) {
      return AppShellTab.puzzles;
    }
    if (location == AppRoutes.profile ||
        location.startsWith('${AppRoutes.profile}/')) {
      return AppShellTab.profile;
    }
    return AppShellTab.home;
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.location,
  });

  final StatefulNavigationShell navigationShell;
  final String location;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _homeTitleTapCount = 0;
  DateTime? _lastHomeTitleTapAt;

  @override
  Widget build(BuildContext context) {
    final AppShellTab currentTab = AppShellTab.fromLocation(widget.location);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: currentTab == AppShellTab.home ? _handleHomeTitleTap : null,
          child: Text(currentTab.title),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab.index,
        onDestinationSelected: (index) {
          if (index == currentTab.index) {
            return;
          }
          widget.navigationShell.goBranch(index);
        },
        destinations: [
          for (final tab in AppShellTab.values)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }

  void _handleHomeTitleTap() {
    final DateTime now = DateTime.now();
    if (_lastHomeTitleTapAt != null &&
        now.difference(_lastHomeTitleTapAt!).inSeconds < 2) {
      _homeTitleTapCount += 1;
    } else {
      _homeTitleTapCount = 1;
    }
    _lastHomeTitleTapAt = now;

    if (_homeTitleTapCount >= 5) {
      _homeTitleTapCount = 0;
      context.push(AppRoutes.bench);
    }
  }
}
