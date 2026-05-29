import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/kakuro/kakuro_board.dart';
import 'package:puzzle_core/src/kakuro/kakuro_generator.dart';
import 'package:puzzle_core/src/kakuro/kakuro_solver.dart';
import 'package:puzzle_core/src/generators/generator.dart';
import 'package:puzzle_core/src/solver/solver.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:test/test.dart';

void main() {
  test(
    'kakuro 9x9 bounded smoke test validates generation and uniqueness solve',
    () {
      const KakuroGenerator generator = KakuroGenerator(
        maxTemplateAttempts: 96,
        hardTimeLimitOverride: Duration(milliseconds: 5200),
        perAttemptTimeLimit: Duration(milliseconds: 1100),
      );
      const KakuroSolver solver = KakuroSolver();
      const SizeOpt size = SizeOpt(
        id: 'template9x9',
        description: 'Template 9x9',
        width: 9,
        height: 9,
      );

      const List<String> seeds = <String>[
        'kakuro_smoke_9x9_seed_0',
        'kakuro_smoke_9x9_seed_1',
      ];

      for (final String seedStr in seeds) {
        final int seed64 = Seed.fromString(seedStr);
        final PuzzleGenerationResult<KakuroBoard> generated = generator.generate(
          GeneratorContext(
            rng: SeededRng(seed64),
            seedStr: seedStr,
            seed64: seed64,
            size: size,
            difficulty: const DifficultyRequest(level: 'medium', hint: 0.6),
          ),
        );
        final SolverResult<KakuroBoard> solved = solver.solve(
          generated.board,
          SolverContext(rng: SeededRng(seed64 ^ 0x7f4a7c15), maxSolutions: 2),
        );

        expect(generated.board.width, 9, reason: seedStr);
        expect(generated.board.height, 9, reason: seedStr);
        expect(solved.hasSolution, isTrue, reason: seedStr);
        expect(solved.isUnique, isTrue, reason: seedStr);
      }
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
