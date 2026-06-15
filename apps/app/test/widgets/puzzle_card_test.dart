import 'package:app/shared/models/models.dart';
import 'package:app/shared/widgets/puzzle_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PuzzleCard', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('displays puzzle information and playable actions', (
      WidgetTester tester,
    ) async {
      const PuzzleMetadata metadata = PuzzleMetadata(
        type: PuzzleType.sudokuClassic,
        displayName: 'Classic Sudoku',
        icon: Icons.grid_on,
        accentColors: [Color(0xFF2196F3), Color(0xFF1976D2)],
        supportedSizes: ['9x9', '6x6', '4x4'],
        supportedDifficulties: ['Easy', 'Medium', 'Hard', 'Expert'],
        supportsHints: true,
        category: PuzzleCategory.logic,
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: PuzzleCard(metadata: metadata)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Classic Sudoku'), findsOneWidget);
      expect(find.text('Logic'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Expert'), findsOneWidget);
      expect(find.text('Start Daily'), findsOneWidget);
      expect(find.text('New Game'), findsOneWidget);
    });

    testWidgets(
      'slitherlink and killer queens are no longer marked coming soon',
      (WidgetTester tester) async {
        const List<PuzzleMetadata> playableMetadata = <PuzzleMetadata>[
          PuzzleMetadata(
            type: PuzzleType.slitherlinkLoop,
            displayName: 'Slitherlink Loop',
            icon: Icons.circle_outlined,
            accentColors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
            supportedSizes: ['5x5', '7x7', '10x10'],
            supportedDifficulties: ['Easy', 'Medium', 'Hard'],
            supportsHints: true,
            category: PuzzleCategory.logic,
          ),
          PuzzleMetadata(
            type: PuzzleType.killerQueens,
            displayName: 'Killer Queens',
            icon: Icons.catching_pokemon,
            accentColors: [Color(0xFF26C6DA), Color(0xFF00838F)],
            supportedSizes: ['6x6', '8x8', '10x10', '12x12'],
            supportedDifficulties: ['Easy', 'Medium', 'Hard', 'Expert'],
            supportsHints: true,
            category: PuzzleCategory.logic,
          ),
        ];

        for (final PuzzleMetadata metadata in playableMetadata) {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: Scaffold(body: PuzzleCard(metadata: metadata)),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Coming soon'), findsNothing);
          expect(
            find.text('This puzzle will be available in a future update.'),
            findsNothing,
          );
          expect(find.text('Start Daily'), findsOneWidget);
          expect(find.text('New Game'), findsOneWidget);
        }
      },
    );
  });
}
