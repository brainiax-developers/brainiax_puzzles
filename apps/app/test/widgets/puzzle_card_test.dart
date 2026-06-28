import 'package:app/shared/models/models.dart';
import 'package:app/shared/widgets/puzzle_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const PuzzleMetadata metadata = PuzzleMetadata(
    type: PuzzleType.sudokuClassic,
    displayName: 'Classic Sudoku',
    description:
        'Fill the grid so every row, column, and box contains each number once.',
    icon: Icons.grid_on,
    accentColors: [Color(0xFF2196F3), Color(0xFF1976D2)],
    supportedSizes: ['9x9', '6x6', '4x4'],
    supportedDifficulties: ['Easy', 'Medium', 'Hard', 'Expert'],
    supportsHints: true,
    category: PuzzleCategory.logic,
  );

  const PuzzleMetadata unavailableMetadata = PuzzleMetadata(
    type: PuzzleType.takuzuBinary,
    displayName: 'Binary Takuzu',
    description:
        'Fill the grid with 0s and 1s without three in a row.',
    icon: Icons.add_box,
    accentColors: [Color(0xFFFF9800), Color(0xFFF57C00)],
    supportedSizes: ['7x9'],
    supportedDifficulties: ['Easy'],
    supportsHints: true,
    category: PuzzleCategory.logic,
    isAvailable: false,
    availabilityBadgeLabel: 'Coming Soon',
    unavailableMessage: 'Takuzu is coming soon.',
  );

  Widget buildCard({
    PuzzleMetadata cardMetadata = metadata,
    bool isFavourite = false,
    bool isInProgress = false,
    VoidCallback? onTap,
    VoidCallback? onToggleFavourite,
    VoidCallback? onResume,
  }) {
    return MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: Scaffold(
        body: PuzzleCard(
          metadata: cardMetadata,
          isFavourite: isFavourite,
          isInProgress: isInProgress,
          onTap: onTap ?? () {},
          onToggleFavourite: onToggleFavourite ?? () {},
          onResume: onResume,
        ),
      ),
    );
  }

  testWidgets('shows library card content and difficulty chips', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildCard());

    expect(find.text('Classic Sudoku'), findsOneWidget);
    expect(find.text('Numbers'), findsOneWidget);
    expect(
      find.text(
        'Fill the grid so every row, column, and box contains each number once.',
      ),
      findsOneWidget,
    );
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    expect(find.text('Expert'), findsOneWidget);
    expect(find.text('In Progress'), findsNothing);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Best Time'), findsNothing);
    expect(find.text('Solved Count'), findsNothing);
    expect(find.text('Rank'), findsNothing);
  });

  testWidgets('shows in-progress affordances when a run exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildCard(isInProgress: true, onResume: () {}));

    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('star button toggles independently from card tap', (
    WidgetTester tester,
  ) async {
    int cardTaps = 0;
    int starTaps = 0;

    await tester.pumpWidget(
      buildCard(
        onTap: () => cardTaps += 1,
        onToggleFavourite: () => starTaps += 1,
      ),
    );

    await tester.tap(find.byIcon(Icons.star_outline));
    await tester.pump();

    expect(starTaps, 1);
    expect(cardTaps, 0);
  });

  testWidgets('coming soon cards show badge and hide continue action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildCard(
        cardMetadata: unavailableMetadata,
        isInProgress: true,
        onResume: () {},
      ),
    );

    expect(find.text('Coming Soon'), findsOneWidget);
    expect(find.text('Takuzu is coming soon.'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
  });
}
