import 'package:go_router/go_router.dart';
import 'features/home/home_screen.dart';
import 'features/puzzles/puzzles_list_screen.dart';
import 'features/play/play_screen.dart';
import 'features/daily/daily_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/settings/settings_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/puzzles', builder: (context, state) => const PuzzlesListScreen()),
    GoRoute(
      path: '/play/:type',
      builder: (context, state) => PlayScreen(type: state.pathParameters['type']!),
    ),
    GoRoute(path: '/daily', builder: (context, state) => const DailyScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
  ],
);