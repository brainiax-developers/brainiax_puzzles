import '../generators/generator.dart';
import '../solver/solver.dart';
import '../util/determinism.dart';
import '../util/seeded_rng.dart';
import 'sudoku_board.dart';
import 'sudoku_solver.dart';

const int _generatorSolverSalt = 0x7dce3a5f4b2916c3;

class SudokuGenerator extends PuzzleGenerator<SudokuBoard> {
  const SudokuGenerator({this.minClues = 26});

  final int minClues;

  @override
  PuzzleGenerationResult<SudokuBoard> generate(GeneratorContext context) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final _RandomSudokuBuilder builder = _RandomSudokuBuilder(context.rng);
    final List<int> solutionCells = builder.buildSolution();

    final List<int> puzzleCells = List<int>.from(solutionCells);
    final List<bool> fixed = List<bool>.filled(SudokuBoard.cellCount, true);

    final List<int> removalOrder = List<int>.generate(SudokuBoard.cellCount, (int i) => i);
    context.rng.shuffle(removalOrder);

    int removals = 0;
    int uniquenessChecks = 0;
    final SudokuSolver solver = const SudokuSolver();

    for (final int index in removalOrder) {
      final int backup = puzzleCells[index];
      if (backup == 0) {
        continue;
      }
      puzzleCells[index] = 0;
      fixed[index] = false;

      if (_countClues(puzzleCells) < minClues) {
        puzzleCells[index] = backup;
        fixed[index] = true;
        continue;
      }

      final SudokuBoard candidate = SudokuBoard(cells: puzzleCells, fixed: fixed);
      final SolverResult<SudokuBoard> result = solver.solve(
        candidate,
        SolverContext(
          rng: SeededRng(context.seed64 ^ _generatorSolverSalt ^ index),
          maxSolutions: 2,
        ),
      );
      uniquenessChecks++;
      if (result.solutions.length != 1) {
        puzzleCells[index] = backup;
        fixed[index] = true;
      } else {
        removals++;
      }
    }

    final SudokuBoard puzzle = SudokuBoard(cells: puzzleCells, fixed: fixed);

    stopwatch.stop();

    final Map<String, Object?> telemetry = <String, Object?>{
      'durationUs': stopwatch.elapsedMicroseconds,
      'removals': removals,
      'uniquenessChecks': uniquenessChecks,
      'clues': puzzle.clueCount,
      'solutionSignature': solutionCells.join(),
    };

    DeterminismGuard.assertNoFloatsOrDateTimes(telemetry);

    return PuzzleGenerationResult<SudokuBoard>(
      board: puzzle,
      snapshot: GenerationSnapshot(telemetry: telemetry),
    );
  }

  int _countClues(List<int> cells) {
    int count = 0;
    for (final int value in cells) {
      if (value != 0) {
        count++;
      }
    }
    return count;
  }
}

class _RandomSudokuBuilder {
  _RandomSudokuBuilder(this.rng);

  final SeededRng rng;

  List<int> buildSolution() {
    final List<int> cells = List<int>.filled(SudokuBoard.cellCount, 0);
    if (!_fill(cells)) {
      throw StateError('Failed to generate Sudoku solution');
    }
    return cells;
  }

  bool _fill(List<int> cells) {
    int index = _selectCell(cells);
    if (index == -1) {
      return true;
    }
    final List<int> digits = _availableDigits(cells, index);
    if (digits.isEmpty) {
      return false;
    }
    rng.shuffle(digits);
    for (final int digit in digits) {
      cells[index] = digit;
      if (_fill(cells)) {
        return true;
      }
      cells[index] = 0;
    }
    return false;
  }

  int _selectCell(List<int> cells) {
    int bestIndex = -1;
    int bestCount = 10;
    for (int i = 0; i < SudokuBoard.cellCount; i++) {
      if (cells[i] == 0) {
        final int count = _availableDigits(cells, i).length;
        if (count < bestCount) {
          bestCount = count;
          bestIndex = i;
          if (count == 1) {
            break;
          }
        }
      }
    }
    return bestIndex;
  }

  List<int> _availableDigits(List<int> cells, int index) {
    final Set<int> used = <int>{};
    for (final int peer in SudokuBoard.peers[index]) {
      final int value = cells[peer];
      if (value != 0) {
        used.add(value);
      }
    }
    final List<int> digits = <int>[];
    for (int digit = 1; digit <= 9; digit++) {
      if (!used.contains(digit)) {
        digits.add(digit);
      }
    }
    return digits;
  }
}
