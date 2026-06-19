import 'package:app/app_router.dart';
import 'package:app/features/daily/daily_screen.dart';
import 'package:app/features/play/play_screen.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/navigation/app_routes.dart';
import 'package:app/shared/providers/daily_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<GoRouter> pumpDailyRouter(
    WidgetTester tester, {
    required List<PuzzleType> puzzleTypes,
    required Map<PuzzleType, DailyStatus> statuses,
  }) async {
    final GoRouter router = createAppRouter(initialLocation: AppRoutes.daily);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyPuzzleTypesProvider.overrideWith((ref) => puzzleTypes),
          dailyStatusProvider.overrideWith((ref) async => statuses),
        ],
        child: MaterialApp.router(
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('does not auto-navigate when all daily puzzles are complete', (
    WidgetTester tester,
  ) async {
    final List<PuzzleType> puzzleTypes = <PuzzleType>[
      PuzzleType.sudokuClassic,
      PuzzleType.nonogramMono,
    ];
    final Duration reset = const Duration(hours: 5, minutes: 30);
    final DateTime completedAt = DateTime.utc(2026, 6, 19);

    final GoRouter router = await pumpDailyRouter(
      tester,
      puzzleTypes: puzzleTypes,
      statuses: <PuzzleType, DailyStatus>{
        for (final PuzzleType type in puzzleTypes)
          type: DailyStatus(
            puzzleType: type,
            isCompleted: true,
            completedAt: completedAt,
            timeUntilReset: reset,
          ),
      },
    );

    expect(find.byType(DailyScreen), findsOneWidget);
    expect(find.text('All daily puzzles completed.'), findsOneWidget);
    expect(find.byType(PlayScreen), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.daily);
  });

  testWidgets('shows CTA for the first incomplete daily puzzle', (
    WidgetTester tester,
  ) async {
    final Duration reset = const Duration(hours: 4, minutes: 15);

    await pumpDailyRouter(
      tester,
      puzzleTypes: <PuzzleType>[
        PuzzleType.sudokuClassic,
        PuzzleType.nonogramMono,
      ],
      statuses: <PuzzleType, DailyStatus>{
        PuzzleType.sudokuClassic: DailyStatus(
          puzzleType: PuzzleType.sudokuClassic,
          isCompleted: false,
          completedAt: null,
          timeUntilReset: reset,
        ),
        PuzzleType.nonogramMono: DailyStatus(
          puzzleType: PuzzleType.nonogramMono,
          isCompleted: true,
          completedAt: DateTime.utc(2026, 6, 19),
          timeUntilReset: reset,
        ),
      },
    );

    expect(find.text('Start Classic Sudoku'), findsOneWidget);
    expect(find.text('Completed for today'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
  });
}
