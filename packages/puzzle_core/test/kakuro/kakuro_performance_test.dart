import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/generators/generator.dart';
import 'package:puzzle_core/src/kakuro/kakuro_board.dart';
import 'package:puzzle_core/src/kakuro/kakuro_generator.dart';
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
    'kakuro solver p95 under 150ms on bounded deterministic generated puzzles',
    () {
      const KakuroGenerator generator = KakuroGenerator(
        maxTemplateAttempts: 28,
        perAttemptTimeLimit: Duration(milliseconds: 450),
        hardTimeLimitOverride: Duration(milliseconds: 1200),
      );
      const KakuroSolver solver = KakuroSolver();
      const SizeOpt size = SizeOpt(
        id: 'template8x8',
        description: 'Template 8x8',
        width: 8,
        height: 8,
      );

      const int targetSamples = 2;
      const int maxAttempts = 6;
      final List<int> durationsUs = <int>[];

      for (int attempt = 0; attempt < maxAttempts && durationsUs.length < targetSamples; attempt++) {
        final String seedStr = 'kakuro_perf_bounded_$attempt';
        final int seed64 = Seed.fromString(seedStr);

        PuzzleGenerationResult<KakuroBoard>? generated;
        try {
          generated = generator.generate(
            GeneratorContext(
              rng: SeededRng(seed64),
              seedStr: seedStr,
              seed64: seed64,
              size: size,
              difficulty: const DifficultyRequest(level: 'easy'),
            ),
          );
        } catch (_) {
          continue;
        }

        final Stopwatch stopwatch = Stopwatch()..start();
        final SolverResult<KakuroBoard> solved = solver.solve(
          generated.board,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 1),
        );
        stopwatch.stop();

        expect(solved.hasSolution, isTrue, reason: 'solver failed for seed $seedStr');
        durationsUs.add(stopwatch.elapsedMicroseconds);
      }

      expect(
        durationsUs.length,
        targetSamples,
        reason: 'Only collected ${durationsUs.length}/$targetSamples samples in $maxAttempts attempts',
      );

      final int p95Us = _percentile(durationsUs, 0.95);
      expect(p95Us, lessThan(150000));
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
