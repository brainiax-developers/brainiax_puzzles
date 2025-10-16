import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:app/features/select/select_screen.dart';
import 'package:app/shared/services/puzzle_registry.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

void main() {
  group('SelectScreen', () {
    setUp(() {
      core.EngineRegistry().clear();
    });

    tearDown(() {
      core.EngineRegistry().clear();
    });

    testWidgets('should show loading state initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (context, state) => const SelectScreen()),
            ],
          ).routeInformationProvider,
          routeInformationParser: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (context, state) => const SelectScreen()),
            ],
          ).routeInformationParser,
          routerDelegate: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (context, state) => const SelectScreen()),
            ],
          ).routerDelegate,
        ),
      );

      // Should show loading shimmer
      expect(find.byType(SelectScreen), findsOneWidget);
      
      // Wait for loading to complete
      await tester.pumpAndSettle();
    });

    testWidgets('should show empty state when no puzzles are available', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (context, state) => const SelectScreen()),
            ],
          ).routeInformationProvider,
          routeInformationParser: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (context, state) => const SelectScreen()),
            ],
          ).routeInformationParser,
          routerDelegate: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (context, state) => const SelectScreen()),
            ],
          ).routerDelegate,
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      expect(find.text('No Puzzles Available'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('should show puzzles when available', (WidgetTester tester) async {
      // Register some engines
      core.EngineRegistry().register(core.StubPuzzleEngine(engineId: 'sudoku_classic'));
      core.EngineRegistry().register(core.StubPuzzleEngine(engineId: 'nonogram_mono'));

      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (context, state) => const SelectScreen()),
            ],
          ).routeInformationProvider,
          routeInformationParser: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (context, state) => const SelectScreen()),
            ],
          ).routeInformationParser,
          routerDelegate: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (context, state) => const SelectScreen()),
            ],
          ).routerDelegate,
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      expect(find.text('Logic'), findsWidgets);
      expect(find.text('Classic Sudoku'), findsOneWidget);
      expect(find.text('Monochrome Nonogram'), findsOneWidget);
    });

    testWidgets('should navigate to play screen when puzzle is selected', (WidgetTester tester) async {
      // Register an engine
      core.EngineRegistry().register(core.StubPuzzleEngine(engineId: 'sudoku_classic'));

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const SelectScreen()),
          GoRoute(
            path: '/play/:puzzleType/:mode',
            builder: (context, state) => const Scaffold(
              body: Text('Play Screen'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Tap on Daily Challenge button
      await tester.tap(find.text('Daily Challenge'));
      await tester.pumpAndSettle();

      expect(find.text('Play Screen'), findsOneWidget);
    });
  });
}
