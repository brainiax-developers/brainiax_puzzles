import 'package:puzzle_core/src/difficulty/telemetry.dart';
import 'package:puzzle_core/src/kakuro/kakuro_board.dart';
import 'package:puzzle_core/src/kakuro/kakuro_difficulty.dart';
import 'package:puzzle_core/src/kakuro/kakuro_generator.dart';
import 'package:test/test.dart';

void main() {
  test(
    'numeric difficulties 0..3 normalize to Easy..Expert',
    () {
      final Map<String, String> expectation = {
        '0': 'easy',
        '1': 'medium',
        '2': 'hard',
        '3': 'expert',
      };

      expectation.forEach((input, expected) {
        final requested = KakuroGenerator.normalizeDifficultyForTest(input);
        expect(requested, expected);
      });
    },
    timeout: const Timeout(Duration(seconds: 2)),
  );

  test(
    'text difficulties pass through including expert',
    () {
      for (final level in ['easy', 'medium', 'hard', 'expert']) {
        final requested = KakuroGenerator.normalizeDifficultyForTest(level);
        expect(requested, level);
      }
    },
    timeout: const Timeout(Duration(seconds: 2)),
  );

  test(
    'synthetic telemetry difficulty scores are strictly ordered',
    () {
      const KakuroDifficultyScorer scorer = KakuroDifficultyScorer();
      final KakuroBoard board = _stubBoard();

      final double easy = scorer
          .score(
            puzzle: board,
            solution: board,
            context: DifficultyContext(
              generatorTelemetry: const <String, Object?>{},
              solverTelemetry: _telemetry(
                searchNodes: 16,
                backtracks: 6,
                maxDepth: 3,
                maxBranchingFactor: 3,
                avgRunCombinationCount: 2.1,
                singleComboRunRatio: 0.35,
                propagationRounds: 40,
              ),
            ),
          )
          .rawScore;

      final double medium = scorer
          .score(
            puzzle: board,
            solution: board,
            context: DifficultyContext(
              generatorTelemetry: const <String, Object?>{},
              solverTelemetry: _telemetry(
                searchNodes: 52,
                backtracks: 18,
                maxDepth: 6,
                maxBranchingFactor: 5,
                avgRunCombinationCount: 3.6,
                singleComboRunRatio: 0.18,
                propagationRounds: 110,
              ),
            ),
          )
          .rawScore;

      final double hard = scorer
          .score(
            puzzle: board,
            solution: board,
            context: DifficultyContext(
              generatorTelemetry: const <String, Object?>{},
              solverTelemetry: _telemetry(
                searchNodes: 130,
                backtracks: 56,
                maxDepth: 9,
                maxBranchingFactor: 7,
                avgRunCombinationCount: 4.9,
                singleComboRunRatio: 0.08,
                propagationRounds: 220,
              ),
            ),
          )
          .rawScore;

      final double expert = scorer
          .score(
            puzzle: board,
            solution: board,
            context: DifficultyContext(
              generatorTelemetry: const <String, Object?>{},
              solverTelemetry: _telemetry(
                searchNodes: 320,
                backtracks: 170,
                maxDepth: 13,
                maxBranchingFactor: 9,
                avgRunCombinationCount: 6.3,
                singleComboRunRatio: 0.01,
                propagationRounds: 410,
              ),
            ),
          )
          .rawScore;

      expect(easy, lessThan(medium));
      expect(medium, lessThan(hard));
      expect(hard, lessThan(expert));
    },
    timeout: const Timeout(Duration(seconds: 2)),
  );
}

Map<String, Object?> _telemetry({
  required int searchNodes,
  required int backtracks,
  required int maxDepth,
  required int maxBranchingFactor,
  required double avgRunCombinationCount,
  required double singleComboRunRatio,
  required int propagationRounds,
}) {
  return <String, Object?>{
    'searchNodes': searchNodes,
    'backtracks': backtracks,
    'maxDepth': maxDepth,
    'maxBranchingFactor': maxBranchingFactor,
    'avgRunCombinationCount': avgRunCombinationCount,
    'singleComboRunRatio': singleComboRunRatio,
    'propagationRounds': propagationRounds,
    'forcedAssignments': 20,
    'candidateRemovals': 60,
    'candidateShrinkPercent': 0.3,
    'maxRunLength': 5,
    'runCount': 12,
    'whiteCellCount': 24,
  };
}

KakuroBoard _stubBoard() {
  return KakuroBoard(
    width: 1,
    height: 1,
    kinds: const <KakuroCellKind>[KakuroCellKind.block],
    values: const <int>[0],
    acrossClues: const <int?>[null],
    downClues: const <int?>[null],
    entries: const <KakuroEntry>[],
    acrossEntryForCell: const <int>[-1],
    downEntryForCell: const <int>[-1],
  );
}
