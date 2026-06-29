import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:app/shared/theme/app_theme.dart';
import 'package:app/shared/widgets/sudoku_renderer.dart';
import 'package:app/shared/widgets/nonogram_renderer.dart';

import 'package:app/shared/widgets/slitherlink_renderer.dart';
import 'package:app/shared/widgets/mathdoku_renderer.dart';
import 'package:app/shared/widgets/killer_queens_renderer.dart';
import 'package:app/shared/widgets/takuzu_renderer.dart';

import '../helpers/test_puzzle_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadAppFonts();
  });

  final Map<String, ThemeData> themes = {
    'light': AppTheme.light(),
    'dark': AppTheme.dark(),
    'high_contrast': AppTheme.light(Contrast.high),
  };

  group('Renderer goldens', () {
    themes.forEach((themeName, theme) {
      testGoldens('sudoku_$themeName', (tester) async {
        await tester.pumpWidgetBuilder(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 360,
                  child: SudokuRendererWidget(
                    puzzle: buildSudokuPuzzle(),
                  ),
                ),
              ),
            ),
          ),
          surfaceSize: const Size(420, 420),
        );
        await screenMatchesGolden(tester, 'sudoku_$themeName');
      });

      testGoldens('nonogram_$themeName', (tester) async {
        await tester.pumpWidgetBuilder(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 360,
                  child: NonogramRendererWidget(
                    puzzle: buildNonogramPuzzle(),
                  ),
                ),
              ),
            ),
          ),
          surfaceSize: const Size(420, 420),
        );
        await screenMatchesGolden(tester, 'nonogram_$themeName');
      });



      testGoldens('slitherlink_$themeName', (tester) async {
        await tester.pumpWidgetBuilder(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 360,
                  child: SlitherlinkRendererWidget(
                    puzzle: buildSlitherlinkPuzzle(),
                  ),
                ),
              ),
            ),
          ),
          surfaceSize: const Size(420, 420),
        );
        await screenMatchesGolden(tester, 'slitherlink_$themeName');
      });

      testGoldens('mathdoku_$themeName', (tester) async {
        await tester.pumpWidgetBuilder(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 360,
                  child: MathdokuRendererWidget(
                    puzzle: buildMathdokuPuzzle(),
                  ),
                ),
              ),
            ),
          ),
          surfaceSize: const Size(420, 420),
        );
        await screenMatchesGolden(tester, 'mathdoku_$themeName');
      });

      testGoldens('killer_queens_$themeName', (tester) async {
        await tester.pumpWidgetBuilder(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 360,
                  child: KillerQueensRendererWidget(
                    puzzle: buildKillerQueensPuzzle(),
                  ),
                ),
              ),
            ),
          ),
          surfaceSize: const Size(420, 420),
        );
        await screenMatchesGolden(tester, 'killer_queens_$themeName');
      });

      testGoldens('takuzu_$themeName', (tester) async {
        await tester.pumpWidgetBuilder(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 360,
                  child: TakuzuRendererWidget(
                    puzzle: buildTakuzuPuzzle(),
                  ),
                ),
              ),
            ),
          ),
          surfaceSize: const Size(420, 420),
        );
        await screenMatchesGolden(tester, 'takuzu_$themeName');
      });
    });
  });
}
