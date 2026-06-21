import 'package:go_router/go_router.dart';

import 'features/bench/bench_screen.dart';
import 'features/daily/daily_screen.dart';
import 'features/home/home_screen.dart';
import 'features/play/play_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/select/select_screen.dart';
import 'features/settings/settings_screen.dart';
import 'shared/models/models.dart';
import 'shared/navigation/app_routes.dart';
import 'shared/widgets/app_shell.dart';

final GoRouter appRouter = createAppRouter();

GoRouter createAppRouter({String initialLocation = AppRoutes.home}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.legacyPuzzles,
        redirect: (context, state) => AppRoutes.puzzles,
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          location: state.uri.path,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.daily,
                builder: (context, state) => const DailyScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.puzzles,
                builder: (context, state) => const SelectScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/play/:puzzleType/:mode',
        redirect: (context, state) {
          final String puzzleTypeKey = state.pathParameters['puzzleType'] ?? '';
          final String modeKey = state.pathParameters['mode'] ?? '';
          if (!PuzzleType.isValidKey(puzzleTypeKey) ||
              !PuzzleMode.isValidKey(modeKey)) {
            return AppRoutes.puzzles;
          }
          return null;
        },
        builder: (context, state) {
          final PuzzleType puzzleType = PuzzleType.fromKey(
            state.pathParameters['puzzleType']!,
          )!;
          final PuzzleMode mode = PuzzleMode.fromKey(
            state.pathParameters['mode']!,
          )!;

          return PlayScreen(
            puzzleType: puzzleType,
            mode: mode,
            puzzleInstance: state.extra,
            difficulty: state.uri.queryParameters['difficulty'],
          );
        },
      ),
      GoRoute(
        path: '/play/:type',
        redirect: (context, state) {
          final String puzzleTypeKey = state.pathParameters['type'] ?? '';
          if (!PuzzleType.isValidKey(puzzleTypeKey)) {
            return AppRoutes.puzzles;
          }
          return null;
        },
        builder: (context, state) {
          final PuzzleType puzzleType = PuzzleType.fromKey(
            state.pathParameters['type']!,
          )!;

          return PlayScreen(
            puzzleType: puzzleType,
            mode: PuzzleMode.random,
            puzzleInstance: state.extra,
            difficulty: state.uri.queryParameters['difficulty'],
          );
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.bench,
        builder: (context, state) => const BenchScreen(),
      ),
    ],
  );
}
