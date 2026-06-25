import 'package:app/app_router.dart';
import 'package:app/features/home/home_screen.dart';
import 'package:app/features/profile/profile_screen.dart';
import 'package:app/features/select/select_screen.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/navigation/app_routes.dart';
import 'package:app/shared/services/generation_isolate.dart';
import 'package:app/shared/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_puzzle_data.dart';

class _ImmediatePuzzleGenerationWorker implements PuzzleGenerationWorker {
  _ImmediatePuzzleGenerationWorker(this._puzzle);

  final core.GeneratedPuzzle<dynamic> _puzzle;

  @override
  Future<core.GeneratedPuzzle<dynamic>> generate(
    PuzzleGenerationRequest request, {
    Duration? timeout,
  }) async {
    return _puzzle;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    core.EngineRegistry().clear();
  });

  tearDown(() {
    core.EngineRegistry().clear();
  });

  Future<GoRouter> pumpRouter(
    WidgetTester tester, {
    String initialLocation = AppRoutes.home,
    bool settle = true,
    Duration pumpDuration = const Duration(milliseconds: 100),
  }) async {
    final GoRouter router = createAppRouter(initialLocation: initialLocation);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(pumpDuration);
    }
    return router;
  }

  group('AppRouter shell routes', () {
    testWidgets('root renders Home inside the app shell', (
      WidgetTester tester,
    ) async {
      await pumpRouter(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        AppShellTab.home.index,
      );
    });

    testWidgets('daily route selects the Daily tab', (
      WidgetTester tester,
    ) async {
      await pumpRouter(tester, initialLocation: AppRoutes.daily);

      expect(find.text('Daily Challenges'), findsWidgets);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        AppShellTab.daily.index,
      );
    });

    testWidgets('puzzles route selects the Puzzles tab', (
      WidgetTester tester,
    ) async {
      await pumpRouter(tester, initialLocation: AppRoutes.puzzles);

      expect(find.byType(SelectScreen), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        AppShellTab.puzzles.index,
      );
    });

    testWidgets('profile route selects the Profile tab', (
      WidgetTester tester,
    ) async {
      await pumpRouter(tester, initialLocation: AppRoutes.profile);

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        AppShellTab.profile.index,
      );
    });

    testWidgets('legacy /select redirects to the puzzles tab', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpRouter(
        tester,
        initialLocation: AppRoutes.legacyPuzzles,
      );

      expect(find.byType(SelectScreen), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.puzzles);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        AppShellTab.puzzles.index,
      );
    });
  });

  group('Play and secondary routes', () {
    testWidgets('play route renders outside the shell', (
      WidgetTester tester,
    ) async {
      core.EngineRegistry().register(
        core.StubPuzzleEngine(engineId: PuzzleType.sudokuClassic.key),
      );
      final GoRouter router = createAppRouter(
        initialLocation: AppRoutes.play(
          PuzzleType.sudokuClassic.key,
          PuzzleMode.daily.key,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            puzzleGenerationWorkerProvider.overrideWithValue(
              _ImmediatePuzzleGenerationWorker(buildSudokuPuzzle()),
            ),
          ],
          child: MaterialApp.router(
            routeInformationProvider: router.routeInformationProvider,
            routeInformationParser: router.routeInformationParser,
            routerDelegate: router.routerDelegate,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NavigationBar), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('legacy play route still works for valid puzzle types', (
      WidgetTester tester,
    ) async {
      core.EngineRegistry().register(
        core.StubPuzzleEngine(engineId: PuzzleType.sudokuClassic.key),
      );
      final GoRouter router = createAppRouter(
        initialLocation: AppRoutes.legacyPlay(PuzzleType.sudokuClassic.key),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            puzzleGenerationWorkerProvider.overrideWithValue(
              _ImmediatePuzzleGenerationWorker(buildSudokuPuzzle()),
            ),
          ],
          child: MaterialApp.router(
            routeInformationProvider: router.routeInformationProvider,
            routeInformationParser: router.routeInformationParser,
            routerDelegate: router.routerDelegate,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NavigationBar), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('direct Kakuro route renders a safe coming soon state', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpRouter(
        tester,
        initialLocation: AppRoutes.play(
          PuzzleType.kakuroClassic.key,
          PuzzleMode.daily.key,
        ),
      );

      expect(find.text('Coming Soon'), findsOneWidget);
      expect(find.text('Kakuro is coming soon.'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.play(PuzzleType.kakuroClassic.key, PuzzleMode.daily.key),
      );
    });

    testWidgets('settings route stays outside the shell', (
      WidgetTester tester,
    ) async {
      await pumpRouter(tester, initialLocation: AppRoutes.settings);

      expect(find.text('Settings'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('bench route stays outside the shell', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1440, 2200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await pumpRouter(tester, initialLocation: AppRoutes.bench, settle: false);

      expect(find.text('Engine Bench'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('Invalid play parameters', () {
    testWidgets('invalid puzzle type redirects to puzzles', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpRouter(
        tester,
        initialLocation: AppRoutes.play('invalid_puzzle', PuzzleMode.daily.key),
      );

      expect(find.byType(SelectScreen), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.puzzles);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('invalid mode redirects to puzzles', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpRouter(
        tester,
        initialLocation: AppRoutes.play(
          PuzzleType.sudokuClassic.key,
          'invalid_mode',
        ),
      );

      expect(find.byType(SelectScreen), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.puzzles);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('invalid legacy play route redirects to puzzles', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpRouter(
        tester,
        initialLocation: AppRoutes.legacyPlay('invalid_puzzle'),
      );

      expect(find.byType(SelectScreen), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.puzzles);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('Route parameter validation', () {
    test('should validate puzzle type parameters', () {
      expect(PuzzleType.isValidKey('sudoku_classic'), isTrue);
      expect(PuzzleType.isValidKey('nonogram_mono'), isTrue);
      expect(PuzzleType.isValidKey('kakuro_classic'), isTrue);
      expect(PuzzleType.isValidKey('slitherlink_loop'), isTrue);
      expect(PuzzleType.isValidKey('mathdoku_classic'), isTrue);
      expect(PuzzleType.isValidKey('killer_queens'), isTrue);
      expect(PuzzleType.isValidKey('takuzu_binary'), isTrue);

      expect(PuzzleType.isValidKey('invalid_type'), isFalse);
      expect(PuzzleType.isValidKey(''), isFalse);
    });

    test('should validate puzzle mode parameters', () {
      expect(PuzzleMode.isValidKey('daily'), isTrue);
      expect(PuzzleMode.isValidKey('random'), isTrue);

      expect(PuzzleMode.isValidKey('invalid_mode'), isFalse);
      expect(PuzzleMode.isValidKey(''), isFalse);
    });

    test('should parse puzzle type from key', () {
      expect(
        PuzzleType.fromKey('sudoku_classic'),
        equals(PuzzleType.sudokuClassic),
      );
      expect(
        PuzzleType.fromKey('nonogram_mono'),
        equals(PuzzleType.nonogramMono),
      );
      expect(PuzzleType.fromKey('invalid_type'), isNull);
    });

    test('should parse puzzle mode from key', () {
      expect(PuzzleMode.fromKey('daily'), equals(PuzzleMode.daily));
      expect(PuzzleMode.fromKey('random'), equals(PuzzleMode.random));
      expect(PuzzleMode.fromKey('invalid_mode'), isNull);
    });
  });
}
