import 'dart:async';

import 'package:app/shared/models/models.dart';
import 'package:app/shared/providers/daily_status_provider.dart';
import 'package:app/shared/widgets/daily_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('overall surface shows loading state', (
    WidgetTester tester,
  ) async {
    final completer = Completer<Map<PuzzleType, DailyStatus>>();
    await tester.pumpWidget(
      _surfaceApp(
        const DailySurface(),
        overrides: [
          dailyStatusProvider.overrideWith((ref) => completer.future),
        ],
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('overall surface shows error state', (WidgetTester tester) async {
    await tester.pumpWidget(
      _surfaceApp(
        const DailySurface(),
        overrides: [
          dailyStatusProvider.overrideWith((ref) async {
            throw StateError('daily unavailable');
          }),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Unable to load daily status'), findsOneWidget);
  });

  testWidgets('overall surface renders completion progress and opens hub', (
    WidgetTester tester,
  ) async {
    final router = _routerFor(
      const DailySurface(compact: true),
      overrides: [
        dailyPuzzleTypesProvider.overrideWith(
          (ref) => const <PuzzleType>[
            PuzzleType.sudokuClassic,
            PuzzleType.kakuro,
          ],
        ),
        dailyStatusProvider.overrideWith(
          (ref) async => <PuzzleType, DailyStatus>{
            PuzzleType.sudokuClassic: _status(
              PuzzleType.sudokuClassic,
              completed: true,
              reset: const Duration(hours: 1, minutes: 5),
            ),
            PuzzleType.kakuro: _status(
              PuzzleType.kakuro,
              completed: false,
              reset: const Duration(hours: 1, minutes: 5),
            ),
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: router.overrides,
        child: MaterialApp.router(
          routerConfig: router.router,
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Daily Challenges'), findsOneWidget);
    expect(find.text('1 of 2 completed'), findsOneWidget);
    expect(find.text('1h 5m'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Start Daily'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Start Daily'));
    await tester.pumpAndSettle();

    expect(find.text('daily hub route'), findsOneWidget);
  });

  testWidgets('puzzle surface renders completed and available states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _surfaceApp(
        const Column(
          children: <Widget>[
            DailySurface(
              puzzleType: PuzzleType.sudokuClassic,
              showPuzzleName: true,
            ),
            DailySurface(puzzleType: PuzzleType.kakuro, compact: true),
          ],
        ),
        overrides: [
          dailyStatusProvider.overrideWith(
            (ref) async => <PuzzleType, DailyStatus>{
              PuzzleType.sudokuClassic: _status(
                PuzzleType.sudokuClassic,
                completed: true,
                reset: const Duration(minutes: 42),
              ),
              PuzzleType.kakuro: _status(
                PuzzleType.kakuro,
                completed: false,
                reset: const Duration(minutes: 42),
              ),
            },
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Daily Classic Sudoku'), findsOneWidget);
    expect(find.text('Daily Challenge'), findsOneWidget);
    expect(find.text('42m'), findsWidgets);
    expect(find.widgetWithText(ElevatedButton, 'View Daily'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Start Daily'), findsOneWidget);
  });

  testWidgets('puzzle action opens the daily play route', (
    WidgetTester tester,
  ) async {
    final router = _routerFor(
      const DailySurface(puzzleType: PuzzleType.kakuro),
      overrides: [
        dailyStatusProvider.overrideWith(
          (ref) async => <PuzzleType, DailyStatus>{
            PuzzleType.kakuro: _status(
              PuzzleType.kakuro,
              completed: false,
              reset: const Duration(hours: 2),
            ),
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: router.overrides,
        child: MaterialApp.router(
          routerConfig: router.router,
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Start Daily'));
    await tester.pumpAndSettle();

    expect(find.text('/play/kakuro/daily'), findsOneWidget);
  });

  testWidgets('missing puzzle status renders no puzzle-specific surface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _surfaceApp(
        const DailySurface(puzzleType: PuzzleType.kakuro),
        overrides: [
          dailyStatusProvider.overrideWith(
            (ref) async => <PuzzleType, DailyStatus>{},
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.text('Daily Challenge'), findsNothing);
  });
}

Widget _surfaceApp(Widget child, {required dynamic overrides}) {
  final router = _routerFor(child, overrides: overrides);
  return ProviderScope(
    overrides: router.overrides,
    child: MaterialApp.router(
      routerConfig: router.router,
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
    ),
  );
}

({GoRouter router, dynamic overrides}) _routerFor(
  Widget child, {
  required dynamic overrides,
}) {
  return (
    overrides: overrides,
    router: GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(body: child),
        ),
        GoRoute(
          path: '/daily',
          builder: (context, state) =>
              const Scaffold(body: Text('daily hub route')),
        ),
        GoRoute(
          path: '/play/:puzzleType/:mode',
          builder: (context, state) => Scaffold(body: Text(state.uri.path)),
        ),
      ],
    ),
  );
}

DailyStatus _status(
  PuzzleType puzzleType, {
  required bool completed,
  required Duration reset,
}) {
  return DailyStatus(
    puzzleType: puzzleType,
    isCompleted: completed,
    completedAt: completed ? DateTime.utc(2026, 7, 1) : null,
    timeUntilReset: reset,
  );
}
