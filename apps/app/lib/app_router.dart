import 'package:go_router/go_router.dart';
import 'features/home/home_screen.dart';
import 'features/puzzles/puzzles_list_screen.dart';
import 'features/play/play_screen.dart';
import 'features/select/select_screen.dart';
import 'features/daily/daily_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/bench/bench_screen.dart';
import 'shared/models/models.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/puzzles', builder: (context, state) => const PuzzlesListScreen()),
    GoRoute(path: '/select', builder: (context, state) => const SelectScreen()),
    GoRoute(
      path: '/play/:puzzleType/:mode',
      builder: (context, state) {
        final puzzleTypeKey = state.pathParameters['puzzleType']!;
        final modeKey = state.pathParameters['mode']!;
        
        final puzzleType = PuzzleType.fromKey(puzzleTypeKey);
        final mode = PuzzleMode.fromKey(modeKey);
        
        if (puzzleType == null || mode == null) {
          // Redirect to select screen if invalid parameters
          return const SelectScreen();
        }
        
        return PlayScreen(
          puzzleType: puzzleType,
          mode: mode,
        );
      },
    ),
    // Legacy route for backward compatibility
    GoRoute(
      path: '/play/:type',
      builder: (context, state) => PlayScreen(
        puzzleType: PuzzleType.fromKey(state.pathParameters['type']!) ?? PuzzleType.sudokuClassic,
        mode: PuzzleMode.random,
      ),
    ),
    GoRoute(path: '/daily', builder: (context, state) => const DailyScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/bench', builder: (context, state) => const BenchScreen()),
  ],
);