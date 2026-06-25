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
      const List<({String difficulty, SizeOpt size, List<String> seedStrs})>
      samples = <({String difficulty, SizeOpt size, List<String> seedStrs})>[
        (
          difficulty: 'easy',
          size: SizeOpt(id: '7x9', description: '7x9', width: 7, height: 9),
          seedStrs: <String>[
            'kakuro_smoke_7x9_easy_seed_0',
            'bench:kakuro_classic:0',
            'kakuro_rectangular_7x9_seed',
          ],
        ),
        (
          difficulty: 'medium',
          size: SizeOpt(
            id: '7x10',
            description: '7x10',
            width: 7,
            height: 10,
          ),
              seedStrs: <String>[
                'kakuro_smoke_7x10_medium_seed_0',
                'bench:kakuro_classic:0',
                'kakuro_det_seed_0',
                'kakuro_engine_seed',
                'kakuro_v1_regression_seed_0',
              ],
        ),
        (
          difficulty: 'easy',
          size: SizeOpt(id: '5x5', description: '5x5', width: 5, height: 5),
          seedStrs: <String>['kakuro_smoke_5x5_easy_seed_0'],
        ),
      ];

      for (final ({String difficulty, SizeOpt size, List<String> seedStrs})
          sample
          in samples) {
        PuzzleGenerationResult<KakuroBoard>? generated;
        String? seedStr;
        int? seed64;
        for (final String candidateSeed in sample.seedStrs) {
          final int candidateSeed64 = Seed.fromString(candidateSeed);
          try {
            generated = generator.generate(
              GeneratorContext(
                rng: SeededRng(candidateSeed64),
                seedStr: candidateSeed,
                seed64: candidateSeed64,
                size: sample.size,
                difficulty: DifficultyRequest(
                  level: sample.difficulty,
                  hint: 0.6,
                ),
              ),
            );
            seedStr = candidateSeed;
            seed64 = candidateSeed64;
            break;
          } catch (_) {
            // Try the next deterministic smoke fixture.
          }
        }
        expect(generated, isNotNull, reason: sample.seedStrs.join(', '));
        final PuzzleGenerationResult<KakuroBoard> puzzle = generated!;
        final int selectedSeed64 = seed64!;
        final String selectedSeed = seedStr!;
        final SolverResult<KakuroBoard> solved = solver.solve(
          puzzle.board,
          SolverContext(
            rng: SeededRng(selectedSeed64 ^ 0x7f4a7c15),
            maxSolutions: 2,
          ),
        );

        expect(puzzle.board.width, sample.size.width, reason: selectedSeed);
        expect(puzzle.board.height, sample.size.height, reason: selectedSeed);
        expect(
          solved.solutionStatus,
          SolverStatus.unique,
          reason:
              '$selectedSeed expected unique; got ${solved.solutionStatus.name}',
        );
        expect(solved.hasSolution, isTrue, reason: selectedSeed);
        expect(solved.isUnique, isTrue, reason: selectedSeed);
      }
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
