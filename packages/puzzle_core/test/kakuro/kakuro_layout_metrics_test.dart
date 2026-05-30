import 'package:puzzle_core/src/kakuro/kakuro_generator.dart';
import 'package:test/test.dart';

void main() {
  group('Kakuro layout metrics', () {
    test('computeMetrics is deterministic and preserves entry extraction', () {
      final KakuroLayout layout = KakuroLayout.fromRows(const <String>[
        '#####',
        '#..##',
        '#...#',
        '##..#',
        '#####',
      ]);

      final KakuroLayoutMetrics first = layout.computeMetrics();
      final KakuroLayoutMetrics second = layout.computeMetrics();

      expect(first.toTelemetry(), equals(second.toTelemetry()));
      expect(layout.valueCellCount, equals(7));
      expect(layout.entries.length, equals(6));

      expect(first.whiteCellCount, equals(7));
      expect(first.blockCellCount, equals(18));
      expect(first.clueCellCount, equals(6));
      expect(first.whiteCellDensityMilli, equals(280));
      expect(first.clueCellDensityMilli, equals(240));
      expect(first.acrossRunCount, equals(3));
      expect(first.downRunCount, equals(3));
      expect(first.totalRunCount, equals(6));
      expect(first.runLengthHistogram, equals(<String, int>{'2': 4, '3': 2}));
      expect(first.maxRunLength, equals(3));
      expect(first.averageRunLengthMilli, equals(2333));
      expect(first.shortRunCount, equals(6));
      expect(first.longRunCount, equals(0));
      expect(first.shortRunRatioMilli, equals(1000));
      expect(first.longRunRatioMilli, equals(0));
      expect(first.runGraphEdgeCount, equals(7));
      expect(first.runGraphNodeCount, equals(6));
      expect(first.minRunGraphDegree, equals(2));
      expect(first.runGraphComponentCount, equals(1));
      expect(first.largestRunGraphComponentNodeCount, equals(6));
      expect(first.runGraphConnectivityMilli, equals(1000));
      expect(first.unpairedValueCellCount, equals(0));

      // Existing valid layouts should map each value cell to across/down runs.
      const int sharedCellIndex = 12; // row=2, col=2
      expect(layout.acrossEntryForCell[sharedCellIndex], equals(1));
      expect(layout.downEntryForCell[sharedCellIndex], equals(4));
    });
  });

  group('Kakuro layout pre-score gate', () {
    const KakuroLayoutPreScorer scorer = KakuroLayoutPreScorer();

    test('rejects structurally weak 9x9 layout before fill', () {
      final KakuroLayout weak = KakuroLayout.fromRows(const <String>[
        '#########',
        '#.......#',
        '#.......#',
        '#.......#',
        '#.......#',
        '#.......#',
        '#.......#',
        '#.......#',
        '#########',
      ]);

      final KakuroLayoutPreScoreResult verdict = scorer.score(
        layout: weak,
        difficulty: 'medium',
      );

      expect(verdict.accepted, isFalse);
      expect(
        verdict.reason,
        anyOf(
          equals('white_density_high'),
          equals('long_runs_heavy'),
          equals('short_runs_sparse'),
          equals('run_histogram_pathological'),
        ),
      );
    });

    test('keeps 7x7 easy gate permissive for valid layouts', () {
      final KakuroLayout easyLayout = KakuroLayout.fromRows(const <String>[
        '#######',
        '#.....#',
        '#.....#',
        '#.....#',
        '#.....#',
        '#.....#',
        '#######',
      ]);

      final KakuroLayoutPreScoreResult verdict = scorer.score(
        layout: easyLayout,
        difficulty: 'easy',
      );

      expect(verdict.accepted, isTrue);
      expect(verdict.reason, equals('gate_skipped'));
    });

    test('rejects invalid layout even when gate is skipped by size', () {
      final KakuroLayout invalid = KakuroLayout.fromRows(const <String>[
        '#####',
        '#..##',
        '###.#',
        '#####',
        '#####',
      ]);

      final KakuroLayoutPreScoreResult verdict = scorer.score(
        layout: invalid,
        difficulty: 'easy',
      );

      expect(verdict.accepted, isFalse);
      expect(verdict.reason, equals('invalid_unpaired_value_cells'));
    });
  });
}
