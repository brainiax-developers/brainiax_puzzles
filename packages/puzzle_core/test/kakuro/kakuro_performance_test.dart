import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/kakuro/kakuro_engine.dart';
import 'package:puzzle_core/src/kakuro/kakuro_board.dart';
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
  test(
    'kakuro benchmark prints generation and uniqueness-solve p95/p99',
    () {
      final KakuroEngine engine = KakuroEngine();
      const KakuroSolver solver = KakuroSolver();
      const SizeOpt size = SizeOpt(
        id: 'template9x9',
        description: 'Template 9x9',
        width: 9,
        height: 9,
      );

      const int samples = 30;
      final List<int> generationDurationsUs = <int>[];
      final List<int> uniquenessSolveDurationsUs = <int>[];

      for (int i = 0; i < samples; i++) {
        final String seedStr = 'kakuro_benchmark_$i';
        final int seed64 = Seed.fromString(seedStr);

        final Stopwatch generationWatch = Stopwatch()..start();
        final GeneratedPuzzle<KakuroBoard> generated = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size,
          difficulty: const DifficultyScore(value: 0.6, level: 'medium'),
        );
        generationWatch.stop();
        generationDurationsUs.add(generationWatch.elapsedMicroseconds);

        final Stopwatch solveWatch = Stopwatch()..start();
        final SolverResult<KakuroBoard> solved = solver.solve(
          generated.state,
          SolverContext(rng: SeededRng(seed64 ^ 0x7f4a7c15), maxSolutions: 2),
        );
        solveWatch.stop();

        expect(solved.hasSolution, isTrue, reason: seedStr);
        expect(solved.isUnique, isTrue, reason: seedStr);
        uniquenessSolveDurationsUs.add(solveWatch.elapsedMicroseconds);
      }

      final int generationP95Us = _percentile(generationDurationsUs, 0.95);
      final int generationP99Us = _percentile(generationDurationsUs, 0.99);
      final int uniquenessP95Us = _percentile(uniquenessSolveDurationsUs, 0.95);
      final int uniquenessP99Us = _percentile(uniquenessSolveDurationsUs, 0.99);

      print(
        'Kakuro generation benchmark: '
        'p95=${(generationP95Us / 1000).toStringAsFixed(2)}ms, '
        'p99=${(generationP99Us / 1000).toStringAsFixed(2)}ms',
      );
      print(
        'Kakuro uniqueness-solve benchmark: '
        'p95=${(uniquenessP95Us / 1000).toStringAsFixed(2)}ms, '
        'p99=${(uniquenessP99Us / 1000).toStringAsFixed(2)}ms',
      );

      expect(generationP95Us, greaterThan(0));
      expect(generationP99Us, greaterThanOrEqualTo(generationP95Us));
      expect(uniquenessP95Us, greaterThan(0));
      expect(uniquenessP99Us, greaterThanOrEqualTo(uniquenessP95Us));
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
