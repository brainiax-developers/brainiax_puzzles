import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/kakuro/kakuro_board.dart';
import 'package:puzzle_core/src/kakuro/kakuro_engine.dart';
import 'package:puzzle_core/src/kakuro/kakuro_solver.dart';
import 'package:puzzle_core/src/solver/solver.dart';
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
  test('kakuro solver p95 under 150ms across generated puzzles', () {
    final KakuroEngine engine = KakuroEngine();
    const KakuroSolver solver = KakuroSolver();
    final SizeOpt size = const SizeOpt(
      id: 'template9x9',
      description: 'Template 9x9',
      width: 9,
      height: 9,
    );
    const DifficultyScore difficulty = DifficultyScore(value: 0.0, level: 'auto');

    final List<int> durationsUs = <int>[];
    for (int i = 0; i < 12; i++) {
      final String seedStr = 'kakuro_perf_$i';
      final int seed64 = Seed.fromString(seedStr);
      final generated = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: size,
        difficulty: difficulty,
      );
      final Stopwatch stopwatch = Stopwatch()..start();
      final SolverResult<KakuroBoard> solved = solver.solve(
        generated.state,
        SolverContext(rng: SeededRng(seed64), maxSolutions: 1),
      );
      stopwatch.stop();
      expect(solved.hasSolution, isTrue);
      durationsUs.add(stopwatch.elapsedMicroseconds);
    }

    final int p95Us = _percentile(durationsUs, 0.95);
    expect(p95Us, lessThan(150000));
  });
}
