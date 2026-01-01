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

        // Collect operations
        final Set<MathdokuOperation> ops = generated.state.cages
            .map((c) => c.operation)
            .toSet();

        if (level == 'easy') {
          // Only equality (single) and addition expected.
            expect(ops.every((op) => op == MathdokuOperation.addition || op == MathdokuOperation.equality), isTrue,
              reason: 'Easy should restrict to addition/equality, got: $ops');
        } else if (level == 'medium') {
          // No division/multiplication.
          expect(ops.contains(MathdokuOperation.division), isFalse);
          expect(ops.contains(MathdokuOperation.multiplication), isFalse);
        } else if (level == 'hard') {
          // Allow multiplication & subtraction; division excluded.
          expect(ops.contains(MathdokuOperation.multiplication) || ops.contains(MathdokuOperation.subtraction), isTrue);
          expect(ops.contains(MathdokuOperation.division), isFalse);
        } else if (level == 'expert') {
          // All ops potentially allowed (at least one advanced op besides addition).
          expect(ops.contains(MathdokuOperation.division) || ops.contains(MathdokuOperation.multiplication) || ops.contains(MathdokuOperation.subtraction), isTrue);
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
