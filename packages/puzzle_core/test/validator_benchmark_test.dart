import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:test/test.dart';

void main() {
  test('validator completes under 50ms on solved boards', () {
    final SudokuEngine engine = SudokuEngine();
    final SizeOpt size = SizeOpt(
      id: 'classic9x9',
      description: 'Classic 9x9',
      width: 9,
      height: 9,
    );
    const DifficultyScore difficulty = DifficultyScore(value: 0.0, level: 'auto');
    const String seedStr = 'benchmark-seed';
    final seed64 = Seed.fromString(seedStr);

    final puzzle = engine.generate(
      seedStr: seedStr,
      seed64: seed64,
      size: size,
      difficulty: difficulty,
    );

    final SudokuSolver solver = const SudokuSolver();
    final SolverResult<SudokuBoard> result = solver.solve(
      puzzle.state,
      SolverContext(rng: SeededRng(seed64), maxSolutions: 1),
    );
    final SudokuBoard solvedState = result.solutions.first;

    const iterations = 100;
    Duration total = Duration.zero;
    for (int i = 0; i < iterations; i++) {
      final summary = engine.validator.validateSolution(puzzle.state, solvedState);
      expect(summary.isValid, isTrue, reason: summary.issues.join(','));
      expect(summary.elapsed.inMilliseconds, lessThan(50));
      total += summary.elapsed;
    }

    final average = total ~/ iterations;
    expect(average.inMilliseconds, lessThan(10));

    final Duration p95 = _measureValidationP95(
      engine: engine,
      puzzle: puzzle.state,
      solved: solvedState,
      iterations: 1000,
    );
    expect(p95.inMilliseconds, lessThan(20));
  });
}

Duration _measureValidationP95({
  required SudokuEngine engine,
  required SudokuBoard puzzle,
  required SudokuBoard solved,
  required int iterations,
}) {
  final List<int> micros = List<int>.filled(iterations, 0);
  for (int i = 0; i < iterations; i++) {
    final ValidationSummary summary = engine.validator.validateSolution(puzzle, solved);
    expect(summary.isValid, isTrue, reason: summary.issues.join(','));
    micros[i] = summary.elapsed.inMicroseconds;
  }

  final List<int> sorted = List<int>.from(micros)..sort();
  final int p95Index = ((iterations - 1) * 95) ~/ 100;
  return Duration(microseconds: sorted[p95Index]);
}
