import '../api_types.dart';
import '../difficulty/difficulty_config.dart';
import '../engine/pipeline_engine.dart';
import '../solver/solver.dart';
import '../util/determinism.dart';
import '../util/kakuro_dictionary.dart';
import '../util/seeded_rng.dart';
import '../validation/validator.dart';
import 'kakuro_board.dart';
import 'kakuro_difficulty.dart';
import 'kakuro_generator.dart';
import 'kakuro_move.dart';
import 'kakuro_solver.dart';
import 'kakuro_validator.dart';

DifficultyBucketConfig _loadKakuroDifficultyConfig() {
  return const DifficultyConfigLoader().loadSync(
    'assets/kakuro_difficulty_thresholds.json',
  );
}

class KakuroEngine extends PipelinePuzzleEngine<KakuroBoard, KakuroMove> {
  KakuroEngine({DifficultyBucketConfig? config, KakuroGenerator? generator})
    : super(
        engineId: 'kakuro_classic',
        engineName: 'Classic Kakuro',
        engineVersion: '1.2.0',
        generator: generator ?? const KakuroGenerator(),
        solver: const KakuroSolver(),
        validator: const KakuroValidator(),
        difficultyScorer: const KakuroDifficultyScorer(),
        difficultyConfig: config ?? _loadKakuroDifficultyConfig(),
        enforceDifficulty:
            false, // Disable strict difficulty enforcement for Kakuro
      );

  @override
  PuzzleCapabilities get capabilities =>
      const PuzzleCapabilities(supportsHints: true);

  @override
  MoveResult<KakuroBoard> validateMove({
    required KakuroBoard currentState,
    required KakuroMove move,
  }) {
    if (move.row < 0 || move.row >= currentState.height) {
      return MoveResult.failure('row_out_of_range');
    }
    if (move.col < 0 || move.col >= currentState.width) {
      return MoveResult.failure('col_out_of_range');
    }
    if (move.digit < 0 || move.digit > 9) {
      return MoveResult.failure('digit_out_of_range');
    }

    final int index = currentState.indexOf(move.row, move.col);
    if (!currentState.isPlayableIndex(index)) {
      return MoveResult.failure('cell_not_playable');
    }

    final KakuroBoard updated = currentState.setValue(index, move.digit);
    final ValidationSummary summary = validator.validatePuzzle(updated);
    if (!summary.isValid) {
      return MoveResult.failure(summary.issues.join(','));
    }

    DeterminismGuard.assertNoFloatsOrDateTimes(updated.toJson());

    return MoveResult.success(updated);
  }

  @override
  PuzzleHint? requestHint({
    required KakuroBoard currentState,
    PuzzleHintRequest? request,
  }) {
    // 1. Check for warnings (duplicate digits, overfilled/incorrect sums)
    final ValidationSummary summary = validator.validatePuzzle(currentState);
    if (!summary.isValid) {
      for (final String issue in summary.issues) {
        if (issue.startsWith('duplicate_digit:')) {
          final int entryId = int.parse(issue.split(':')[1]);
          final KakuroEntry entry = currentState.entries[entryId];
          final Map<int, List<int>> valueToCells = <int, List<int>>{};
          for (final int index in entry.cells) {
            final int value = currentState.values[index];
            if (value > 0) {
              valueToCells.putIfAbsent(value, () => <int>[]).add(index);
            }
          }
          final List<PuzzleHintCell> highlight = <PuzzleHintCell>[];
          for (final List<int> indices in valueToCells.values) {
            if (indices.length > 1) {
              for (final int idx in indices) {
                highlight.add(PuzzleHintCell(
                  row: idx ~/ currentState.width,
                  column: idx % currentState.width,
                  metadata: const <String, Object?>{},
                ));
              }
            }
          }
          if (highlight.isNotEmpty) {
            return PuzzleHint(
              cells: highlight,
              metadata: <String, Object?>{
                'engineId': engineId,
                'kind': 'duplicate_digit_in_run',
              },
            );
          }
        }
        if (issue.startsWith('sum_exceeded:') || issue.startsWith('entry_sum:')) {
          final int entryId = int.parse(issue.split(':')[1]);
          final KakuroEntry entry = currentState.entries[entryId];
          final List<PuzzleHintCell> highlight = entry.cells.map((int idx) {
            return PuzzleHintCell(
              row: idx ~/ currentState.width,
              column: idx % currentState.width,
              metadata: const <String, Object?>{},
            );
          }).toList();
          return PuzzleHint(
            cells: highlight,
            metadata: <String, Object?>{
              'engineId': engineId,
              'kind': issue.startsWith('sum_exceeded:') ? 'run_sum_exceeded' : 'run_completed_incorrectly',
            },
          );
        }
      }
    }

    // 2. Single possible candidate cell from solver propagation
    final List<int> empty = <int>[];
    for (int i = 0; i < currentState.cellCount; i++) {
      if (currentState.isPlayableIndex(i) && currentState.values[i] == 0) {
        empty.add(i);
      }
    }

    if (empty.isEmpty) {
      return null;
    }

    for (final int cellIndex in empty) {
      int validCount = 0;
      for (int digit = 1; digit <= 9; digit++) {
        if (_isValidCandidate(currentState, cellIndex, digit)) {
          validCount++;
        }
      }
      if (validCount == 1) {
        return PuzzleHint(
          cells: <PuzzleHintCell>[
            PuzzleHintCell(
              row: cellIndex ~/ currentState.width,
              column: cellIndex % currentState.width,
              metadata: const <String, Object?>{},
            ),
          ],
          metadata: <String, Object?>{
            'engineId': engineId,
            'kind': 'single_candidate_cell',
          },
        );
      }
    }

    // 3. Fallback reveal
    final int seed = request?.seed64 ?? currentState.hashCode;
    final KakuroSolver solver = const KakuroSolver();
    final SolverContext context = SolverContext(
      rng: SeededRng(seed),
      maxSolutions: 1,
    );
    final SolverResult<KakuroBoard> result = solver.solve(
      currentState,
      context,
    );

    if (!result.hasSolution) {
      return null;
    }
    final KakuroBoard solution = result.solutions.first;
    if (solution.values.length != currentState.values.length) {
      return null;
    }

    final int iteration = request?.iteration ?? 0;
    final SeededRng rng = SeededRng(seed ^ 0x9e3779b97f4a7c15 ^ iteration);
    final int chosenIndex = empty[rng.nextIntInRange(empty.length)];
    final int row = chosenIndex ~/ currentState.width;
    final int col = chosenIndex % currentState.width;
    final int digit = solution.values[chosenIndex];
    if (digit <= 0 || digit > 9) {
      return null;
    }

    final PuzzleHintCell cell = PuzzleHintCell(
      row: row,
      column: col,
      metadata: <String, Object?>{'digit': digit},
    );

    return PuzzleHint(
      cells: <PuzzleHintCell>[cell],
      metadata: <String, Object?>{
        'engineId': engineId,
        'kind': 'fill_single_cell',
      },
    );
  }

  bool _isValidCandidate(KakuroBoard board, int index, int digit) {
    final KakuroBoard testBoard = board.setValue(index, digit);
    if (!validator.validatePuzzle(testBoard).isValid) {
      return false;
    }
    
    final int acrossId = testBoard.acrossEntryForCell[index];
    if (acrossId >= 0) {
      if (!_hasValidCombination(testBoard, testBoard.entries[acrossId])) {
        return false;
      }
    }
    
    final int downId = testBoard.downEntryForCell[index];
    if (downId >= 0) {
      if (!_hasValidCombination(testBoard, testBoard.entries[downId])) {
        return false;
      }
    }
    
    return true;
  }

  bool _hasValidCombination(KakuroBoard board, KakuroEntry entry) {
    final Set<int>? combos = KakuroDictionary.getCombinations(entry.cells.length, entry.sum);
    if (combos == null || combos.isEmpty) return false;
    
    int placedMask = 0;
    for (final int idx in entry.cells) {
      final int value = board.values[idx];
      if (value > 0) {
        placedMask |= (1 << value);
      }
    }
    
    for (final int combo in combos) {
      if ((combo & placedMask) == placedMask) {
        return true;
      }
    }
    return false;
  }
}
