import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:test/test.dart';

int _percentile(List<int> values, double percentile) {
  if (values.isEmpty) {
    return 0;
  }
  final List<int> sorted = List<int>.from(values)..sort();
  final int index = (percentile * (sorted.length - 1)).round();
  return sorted[index];
}

void main() {
  test('validator p95 under 50ms across generated seeds', () {
    final SudokuEngine engine = SudokuEngine();
    final SizeOpt size = SizeOpt(
      id: 'classic9x9',
      description: 'Classic 9x9',
      width: 9,
      height: 9,
    );
    const DifficultyScore difficulty = DifficultyScore(value: 0.0, level: 'auto');

    final List<int> durationsUs = <int>[];
    for (int i = 0; i < 25; i++) {
      final String seedStr = 'perf_seed_$i';
      final int seed64 = Seed.fromString(seedStr);
      final GeneratedPuzzle<SudokuBoard> puzzle = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: size,
        difficulty: difficulty,
      );
      final SudokuSolver solver = const SudokuSolver();
      final SolverResult<SudokuBoard> solved = solver.solve(
        puzzle.state,
        SolverContext(rng: SeededRng(seed64), maxSolutions: 1),
      );
      final SudokuBoard solution = solved.solutions.first;
      final ValidationSummary summary = engine.validator.validateSolution(
        puzzle.state,
        solution,
      );
      expect(summary.isValid, isTrue, reason: summary.issues.join(','));
      durationsUs.add(summary.elapsed.inMicroseconds);
    }

    final int p95Us = _percentile(durationsUs, 0.95);
    expect(p95Us, lessThan(50000));
  });
}
