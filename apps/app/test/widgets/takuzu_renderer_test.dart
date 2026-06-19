import 'package:app/shared/widgets/takuzu_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

void main() {
  test('counts rows and columns without counting empty cells', () {
    final counts = TakuzuCounts.fromBoard(
      core.TakuzuBoard(
        size: 4,
        cells: const <int>[
          0,
          1,
          core.TakuzuBoard.emptyValue,
          core.TakuzuBoard.emptyValue,
          0,
          0,
          1,
          core.TakuzuBoard.emptyValue,
          1,
          core.TakuzuBoard.emptyValue,
          1,
          0,
          core.TakuzuBoard.emptyValue,
          core.TakuzuBoard.emptyValue,
          0,
          1,
        ],
        fixed: List<bool>.filled(16, false),
      ),
    );

    expect(counts.rows[0].zeros, 1);
    expect(counts.rows[0].ones, 1);
    expect(counts.rows[1].zeros, 2);
    expect(counts.rows[1].ones, 1);
    expect(counts.columns[0].zeros, 2);
    expect(counts.columns[0].ones, 1);
    expect(counts.columns[3].zeros, 1);
    expect(counts.columns[3].ones, 1);
  });

  test('line count warns only after exceeding allowed count', () {
    expect(const TakuzuLineCount(zeros: 2, ones: 1).exceeds(2), isFalse);
    expect(const TakuzuLineCount(zeros: 3, ones: 1).exceeds(2), isTrue);
    expect(const TakuzuLineCount(zeros: 1, ones: 3).exceeds(2), isTrue);
  });

  test('counter layout reserves compact space on small boards', () {
    final compact = TakuzuCounterLayout.forSize(const Size(240, 240));
    final regular = TakuzuCounterLayout.forSize(const Size(360, 360));

    expect(compact.rowCounterWidth, lessThan(regular.rowCounterWidth));
    expect(compact.columnCounterHeight, lessThan(regular.columnCounterHeight));
  });
}
