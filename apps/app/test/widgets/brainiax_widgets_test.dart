import 'package:app/shared/models/models.dart';
import 'package:app/shared/widgets/brainiax/brainiax_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }

  testWidgets('BrainiaxCard renders child and responds to tap', (
    WidgetTester tester,
  ) async {
    int tapCount = 0;

    await tester.pumpWidget(
      buildTestApp(
        BrainiaxCard(
          onTap: () => tapCount += 1,
          child: const Text('Shared Card'),
        ),
      ),
    );

    expect(find.text('Shared Card'), findsOneWidget);

    await tester.tap(find.text('Shared Card'));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets(
    'DifficultyChip renders selected, disabled, and read-only states',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Wrap(
            spacing: 8,
            children: [
              DifficultyChip(label: 'Easy', selected: true),
              DifficultyChip(label: 'Medium', enabled: false),
              DifficultyChip(label: 'Hard', readOnly: true),
            ],
          ),
        ),
      );

      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);

      final ChoiceChip easyChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Easy'),
      );
      final ChoiceChip mediumChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Medium'),
      );
      final ChoiceChip hardChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Hard'),
      );

      expect(easyChip.selected, isTrue);
      expect(mediumChip.onSelected, isNull);
      expect(hardChip.onSelected, isNull);
    },
  );

  testWidgets('FilterChipRow changes selected option', (
    WidgetTester tester,
  ) async {
    String selected = 'All';

    await tester.pumpWidget(
      buildTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            return FilterChipRow<String>(
              selectedValue: selected,
              onSelected: (value) {
                setState(() {
                  selected = value;
                });
              },
              options: const [
                FilterChipOption(value: 'All', label: 'All'),
                FilterChipOption(value: 'Completed', label: 'Completed'),
              ],
            );
          },
        ),
      ),
    );

    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All'))
          .selected,
      isTrue,
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pump();

    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Completed'))
          .selected,
      isTrue,
    );
  });

  testWidgets('EmptyStateCard renders title, body, and CTA', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        EmptyStateCard(
          title: 'No favourites yet',
          body: 'Star a puzzle to build your list.',
          action: ElevatedButton(
            onPressed: () {},
            child: const Text('Browse Puzzles'),
          ),
        ),
      ),
    );

    expect(find.text('No favourites yet'), findsOneWidget);
    expect(find.text('Star a puzzle to build your list.'), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'Browse Puzzles'),
      findsOneWidget,
    );
  });

  testWidgets('ModeSelectionCard renders selected and disabled states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        const Column(
          children: [
            ModeSelectionCard(
              title: 'Daily Challenge',
              subtitle: 'Same puzzle for everyone',
              secondaryLine: 'Resets in 8h 42m',
              selected: true,
            ),
            SizedBox(height: 12),
            ModeSelectionCard(
              title: 'Random Play',
              subtitle: 'Infinite variety',
              secondaryLine: 'Unique to you',
              enabled: false,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Daily Challenge'), findsOneWidget);
    expect(find.text('Random Play'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byType(Opacity), findsWidgets);
  });

  testWidgets('PuzzleIconBadge renders expected icons for puzzle types', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        const Row(
          children: [
            PuzzleIconBadge(puzzleType: PuzzleType.sudokuClassic),
            SizedBox(width: 12),
            PuzzleIconBadge(puzzleType: PuzzleType.nonogramMono),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.grid_on), findsOneWidget);
    expect(find.byIcon(Icons.crop_square), findsOneWidget);
  });
}
