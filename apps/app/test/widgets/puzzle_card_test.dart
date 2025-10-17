import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/widgets/puzzle_card.dart';

void main() {
  group('PuzzleCard', () {
    late PuzzleMetadata metadata;

    setUp(() {
      metadata = const PuzzleMetadata(
        type: PuzzleType.sudokuClassic,
        displayName: 'Classic Sudoku',
        icon: Icons.grid_on,
        accentColors: [Color(0xFF2196F3), Color(0xFF1976D2)],
        supportedSizes: ['9x9', '6x6', '4x4'],
        supportedDifficulties: ['Easy', 'Medium', 'Hard', 'Expert'],
        supportsHints: true,
        category: PuzzleCategory.logic,
      );
    });

    testWidgets('should display puzzle information correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PuzzleCard(metadata: metadata),
          ),
        ),
      );

      expect(find.text('Classic Sudoku'), findsOneWidget);
      expect(find.text('Logic'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Expert'), findsOneWidget);
      expect(find.text('Daily Challenge'), findsOneWidget);
    });

    testWidgets('should call onDailyChallenge when daily challenge button is tapped', (WidgetTester tester) async {
      bool dailyChallengeCalled = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PuzzleCard(
              metadata: metadata,
              onDailyChallenge: () => dailyChallengeCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Daily Challenge'));
      await tester.pump();

      expect(dailyChallengeCalled, isTrue);
    });

    // Random button removed in favor of Random Play flow

    testWidgets('should display correct icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PuzzleCard(metadata: metadata),
          ),
        ),
      );

      expect(find.byIcon(Icons.grid_on), findsOneWidget);
    });
  });
}
