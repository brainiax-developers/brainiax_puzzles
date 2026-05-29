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
    'kakuro bounded smoke test validates generation and uniqueness solve across fast V1 sizes',
    () {
      const KakuroGenerator generator = KakuroGenerator(
        maxTemplateAttempts: 64,
        hardTimeLimitOverride: Duration(milliseconds: 4200),
        perAttemptTimeLimit: Duration(milliseconds: 900),
      );
      const KakuroSolver solver = KakuroSolver();
      const List<({String difficulty, SizeOpt size, String seedStr})> samples =
          <({String difficulty, SizeOpt size, String seedStr})>[
            (
              difficulty: 'easy',
              size: SizeOpt(id: '7x7', description: '7x7', width: 7, height: 7),
              seedStr: 'kakuro_smoke_7x7_easy_seed_0',
            ),
            (
              difficulty: 'medium',
              size: SizeOpt(
                id: 'template9x9',
                description: 'Template 9x9',
                width: 9,
                height: 9,
              ),
              seedStr: 'kakuro_smoke_9x9_medium_seed_0',
            ),
            (
              difficulty: 'easy',
              size: SizeOpt(
                id: '5x5',
                description: '5x5',
                width: 5,
                height: 5,
              ),
              seedStr: 'kakuro_smoke_5x5_easy_seed_0',
            ),
          ];

      for (final ({String difficulty, SizeOpt size, String seedStr}) sample
          in samples) {
        final String seedStr = sample.seedStr;
        final int seed64 = Seed.fromString(seedStr);
        final PuzzleGenerationResult<KakuroBoard> generated = generator
            .generate(
              GeneratorContext(
                rng: SeededRng(seed64),
                seedStr: seedStr,
                seed64: seed64,
                size: sample.size,
                difficulty: DifficultyRequest(
                  level: sample.difficulty,
                  hint: 0.6,
                ),
              ),
            );
        final SolverResult<KakuroBoard> solved = solver.solve(
          generated.board,
          SolverContext(rng: SeededRng(seed64 ^ 0x7f4a7c15), maxSolutions: 2),
        );

        expect(generated.board.width, sample.size.width, reason: seedStr);
        expect(generated.board.height, sample.size.height, reason: seedStr);
        expect(
          solved.solutionStatus,
          SolverStatus.unique,
          reason:
              '$seedStr expected unique; got ${solved.solutionStatus.name}',
        );
        expect(solved.hasSolution, isTrue, reason: seedStr);
        expect(solved.isUnique, isTrue, reason: seedStr);
      }
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
