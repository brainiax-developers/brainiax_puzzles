import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/mathdoku/mathdoku_solver.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:puzzle_core/src/validation/validator.dart';
import 'package:test/test.dart';

void main() {
  group('Mathdoku engine pipeline', () {
    final MathdokuEngine engine = MathdokuEngine();
    final SizeOpt size4 = SizeOpt(
      id: 'latin4x4',
      description: 'Mathdoku 4x4',
      width: 4,
      height: 4,
    );
    final SizeOpt size6 = SizeOpt(
      id: 'latin6x6',
      description: 'Mathdoku 6x6',
      width: 6,
      height: 6,
    );
    const DifficultyScore difficulty = DifficultyScore(
      value: 0.0,
      level: 'auto',
    );

    List<MathdokuCage> _singletonCages({
      required int size,
      required Iterable<int> cellIndices,
      required int startingId,
      int target = 1,
    }) {
      int nextId = startingId;
      return cellIndices
          .map(
            (int index) => MathdokuCage(
              id: nextId++,
              cells: <int>[index],
              operation: MathdokuOperation.equality,
              target: target,
            ),
          )
          .toList(growable: false);
    }

    test('deterministic generation and unique solutions for 4x4 seeds', () {
      final List<String> seeds = <String>[
        'mathdoku_seed_0',
        'mathdoku_seed_1',
        'mathdoku_seed_2',
        'mathdoku_seed_3',
        'mathdoku_seed_4',
      ];

      for (final String seedStr in seeds) {
        final int seed64 = Seed.fromString(seedStr);
        final GeneratedPuzzle<MathdokuBoard> first = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size4,
          difficulty: difficulty,
        );
        final GeneratedPuzzle<MathdokuBoard> second = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size4,
          difficulty: difficulty,
        );

        expect(first.state, equals(second.state));
        final ValidationSummary puzzleValidation = engine.validator
            .validatePuzzle(first.state);
        expect(
          puzzleValidation.isValid,
          isTrue,
          reason: puzzleValidation.issues.join(','),
        );

        final MathdokuSolver solver = const MathdokuSolver();
        final SolverResult<MathdokuBoard> result = solver.solve(
          first.state,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
        );

        for (final MathdokuCage cage in first.state.cages) {
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

        expect(result.hasSolution, isTrue, reason: 'Puzzle should be solvable');
        expect(result.isUnique, isTrue, reason: 'Puzzle must be unique');

        final MathdokuBoard solution = result.solutions.first;
        final ValidationSummary validation = engine.validator.validateSolution(
          first.state,
          solution,
        );
        expect(validation.isValid, isTrue, reason: validation.issues.join(','));
        expect(engine.isSolved(solution), isTrue);
      }
    });

    test('deterministic generation for 6x6 seeds', () {
      for (int i = 0; i < 10; i++) {
        final String seedStr = 'mathdoku_property_$i';
        final int seed64 = Seed.fromString(seedStr);
        final GeneratedPuzzle<MathdokuBoard> generated = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size6,
          difficulty: difficulty,
        );
        final ValidationSummary puzzleValidation = engine.validator
            .validatePuzzle(generated.state);
        expect(
          puzzleValidation.isValid,
          isTrue,
          reason: puzzleValidation.issues.join(','),
        );

        final MathdokuSolver solver = const MathdokuSolver();
        final SolverResult<MathdokuBoard> result = solver.solve(
          generated.state,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
        );

        for (final MathdokuCage cage in generated.state.cages) {
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

        expect(result.solutions.length, equals(1));

        final GeneratedPuzzle<MathdokuBoard> regenerated = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size6,
          difficulty: difficulty,
        );
        expect(regenerated.state, equals(generated.state));
      }
    });

    test('validatePuzzle accepts empty structurally sound puzzle', () {
      final MathdokuBoard puzzle = MathdokuBoard(
        size: 4,
        cells: List<int>.filled(16, 0),
        cages: _singletonCages(
          size: 4,
          cellIndices: List<int>.generate(16, (int index) => index),
          startingId: 0,
        ),
      );

      final ValidationSummary summary = engine.validator.validatePuzzle(puzzle);
      expect(summary.isValid, isTrue, reason: summary.issues.join(','));
    });

    test('validatePuzzle rejects disconnected cages', () {
      final List<MathdokuCage> cages = <MathdokuCage>[
        MathdokuCage(
          id: 0,
          cells: const <int>[0, 5],
          operation: MathdokuOperation.addition,
          target: 4,
        ),
        ..._singletonCages(
          size: 4,
          cellIndices: List<int>.generate(
            16,
            (int index) => index,
          ).where((int index) => index != 0 && index != 5),
          startingId: 1,
        ),
      ];
      final MathdokuBoard puzzle = MathdokuBoard(
        size: 4,
        cells: List<int>.filled(16, 0),
        cages: cages,
      );

      final ValidationSummary summary = engine.validator.validatePuzzle(puzzle);
      expect(summary.isValid, isFalse);
      expect(summary.issues, contains('cage_0_disconnected'));
    });

    test('validatePuzzle rejects invalid subtraction/division cage sizes', () {
      final List<MathdokuCage> cages = <MathdokuCage>[
        MathdokuCage(
          id: 0,
          cells: const <int>[0, 1, 2],
          operation: MathdokuOperation.subtraction,
          target: 1,
        ),
        MathdokuCage(
          id: 1,
          cells: const <int>[3, 7, 11],
          operation: MathdokuOperation.division,
          target: 2,
        ),
        ..._singletonCages(
          size: 4,
          cellIndices: List<int>.generate(16, (int index) => index).where(
            (int index) => !const <int>{0, 1, 2, 3, 7, 11}.contains(index),
          ),
          startingId: 2,
        ),
      ];
      final MathdokuBoard puzzle = MathdokuBoard(
        size: 4,
        cells: List<int>.filled(16, 0),
        cages: cages,
      );

      final ValidationSummary summary = engine.validator.validatePuzzle(puzzle);
      expect(summary.isValid, isFalse);
      expect(summary.issues, contains('cage_0_invalid_subtract_size'));
      expect(summary.issues, contains('cage_1_invalid_divide_size'));
    });

    test('validatePuzzle rejects duplicate cage IDs', () {
      final List<MathdokuCage> cages = <MathdokuCage>[
        MathdokuCage(
          id: 42,
          cells: const <int>[0],
          operation: MathdokuOperation.equality,
          target: 1,
        ),
        MathdokuCage(
          id: 42,
          cells: const <int>[1],
          operation: MathdokuOperation.equality,
          target: 2,
        ),
        ..._singletonCages(
          size: 4,
          cellIndices: List<int>.generate(
            16,
            (int index) => index,
          ).where((int index) => index != 0 && index != 1),
          startingId: 100,
        ),
      ];
      final MathdokuBoard puzzle = MathdokuBoard(
        size: 4,
        cells: List<int>.filled(16, 0),
        cages: cages,
      );

      final ValidationSummary summary = engine.validator.validatePuzzle(puzzle);
      expect(summary.isValid, isFalse);
      expect(summary.issues, contains('duplicate_cage_id_42'));
    });

    test('validatePuzzle rejects implausible cage targets', () {
      final List<MathdokuCage> cages = <MathdokuCage>[
        MathdokuCage(
          id: 0,
          cells: const <int>[0, 1],
          operation: MathdokuOperation.addition,
          target: 0,
        ),
        MathdokuCage(
          id: 1,
          cells: const <int>[2, 3],
          operation: MathdokuOperation.division,
          target: 8,
        ),
        ..._singletonCages(
          size: 4,
          cellIndices: List<int>.generate(
            16,
            (int index) => index,
          ).where((int index) => index > 3),
          startingId: 2,
        ),
      ];
      final MathdokuBoard puzzle = MathdokuBoard(
        size: 4,
        cells: List<int>.filled(16, 0),
        cages: cages,
      );

      final ValidationSummary summary = engine.validator.validatePuzzle(puzzle);
      expect(summary.isValid, isFalse);
      expect(summary.issues, contains('cage_0_target_non_positive'));
      expect(summary.issues, contains('cage_1_target_out_of_range'));
    });
  });
}
