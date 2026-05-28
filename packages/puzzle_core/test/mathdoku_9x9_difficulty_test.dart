import 'package:test/test.dart';
import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:puzzle_core/src/mathdoku/mathdoku_solver.dart';

void main() {
  group('Mathdoku 9x9 difficulty generation', () {
    final MathdokuEngine engine = MathdokuEngine();
    final SizeOpt size9 = const SizeOpt(id: 'latin9x9', description: 'Mathdoku 9x9', width: 9, height: 9);

    final List<String> difficulties = <String>['easy','medium','hard','expert'];

    for (final String level in difficulties) {
      test('operations respect difficulty: $level', () {
        final DifficultyScore diffScore = () {
          switch (level) {
            case 'easy': return const DifficultyScore(value: 0.3, level: 'easy');
            case 'medium': return const DifficultyScore(value: 0.6, level: 'medium');
            case 'hard': return const DifficultyScore(value: 0.9, level: 'hard');
            case 'expert': return const DifficultyScore(value: 1.2, level: 'expert');
            default: return const DifficultyScore(value: 0.6, level: 'medium');
          }
        }();

        final String seedStr = 'mathdoku9x9_${level}_seed';
        final int seed64 = Seed.fromString(seedStr);

        final GeneratedPuzzle<MathdokuBoard> generated = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size9,
          difficulty: diffScore,
        );

        expect(generated.state.size, equals(9));
        // Validate cages cover full grid
        final int expectedCells = 9 * 9;
        final Set<int> covered = <int>{};
        for (final MathdokuCage cage in generated.state.cages) {
          covered.addAll(cage.cells);
        }
        expect(covered.length, equals(expectedCells));

        // Production rule: only 2-cell cages may use subtraction/division.
        for (final MathdokuCage cage in generated.state.cages) {
          if (cage.cells.length == 1) {
            expect(cage.operation, equals(MathdokuOperation.equality));
            continue;
          }
          expect(cage.operation == MathdokuOperation.equality, isFalse);
          if (cage.cells.length > 2) {
            expect(
              cage.operation == MathdokuOperation.subtraction ||
                  cage.operation == MathdokuOperation.division,
              isFalse,
              reason:
                  'Cage size ${cage.cells.length} must not use subtraction/division: ${cage.operation}',
            );
          }
        }

        // Solve to ensure uniqueness still holds.
        final MathdokuSolver solver = const MathdokuSolver();
        final SolverResult<MathdokuBoard> result = solver.solve(
          generated.state,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
        );
        expect(result.hasSolution, isTrue);
        expect(result.isUnique, isTrue, reason: 'Generated 9x9 $level puzzle should be uniquely solvable');
      });
    }
  });
}
