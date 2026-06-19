import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/navigation/app_routes.dart';
import '../../shared/widgets/widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Welcome back',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Use this screen as the launch point for daily challenges, the full puzzle library, and your profile.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        const DailySurface(),
        const SizedBox(height: 24),
        Text(
          'Quick Access',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _HomeMenuTile(
          icon: Icons.calendar_today_outlined,
          title: 'Daily Challenges',
          subtitle: 'See today\'s puzzles and progress',
          onTap: () => context.go(AppRoutes.daily),
        ),
        _HomeMenuTile(
          icon: Icons.extension_outlined,
          title: 'Puzzles',
          subtitle: 'Browse all available puzzle types',
          onTap: () => context.go(AppRoutes.puzzles),
        ),
        _HomeMenuTile(
          icon: Icons.person_outline,
          title: 'Profile',
          subtitle: 'Open your profile and stats shell',
          onTap: () => context.go(AppRoutes.profile),
        ),
        _HomeMenuTile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Adjust app preferences',
          onTap: () => context.push(AppRoutes.settings),
        ),
      ],
    );
  }
}

class _HomeMenuTile extends StatelessWidget {
  const _HomeMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
