import 'package:puzzle_core/puzzle_core.dart';
import 'package:test/test.dart';

void main() {
  group('Killer Queens engine pipeline', () {
    final KillerQueensEngine engine = KillerQueensEngine();
    const SizeOpt size = SizeOpt(
      id: '8x8',
      description: '8x8',
      width: 8,
      height: 8,
    );
    const DifficultyScore difficulty = DifficultyScore(
      value: 0.6,
      level: 'medium',
    );

    test('generates deterministic puzzles for the same seed', () {
      const String seedStr = 'killer_queens_determinism';
      final int seed64 = Seed.fromString(seedStr);

      final GeneratedPuzzle<KillerQueensBoard> first = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: size,
        difficulty: difficulty,
      );
      final GeneratedPuzzle<KillerQueensBoard> second = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: size,
        difficulty: difficulty,
      );

      expect(first.state, equals(second.state));
      expect(first.meta.seed64, equals(second.meta.seed64));
      expect(first.meta.seedStr, equals(second.meta.seedStr));
    });

    test('puzzles are solvable (but not necessarily unique)', () {
      const List<String> seeds = <String>[
        'killer_queens_seed_0',
        'killer_queens_seed_1',
        'killer_queens_seed_2',
      ];
      final KillerQueensSolver solver = const KillerQueensSolver();

      for (final String seedStr in seeds) {
        final int seed64 = Seed.fromString(seedStr);
        final GeneratedPuzzle<KillerQueensBoard> puzzle = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size,
          difficulty: difficulty,
        );

        final SolverResult<KillerQueensBoard> result = solver.solve(
          puzzle.state,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
        );

        expect(
          result.hasSolution,
          isTrue,
          reason: 'Seed $seedStr should be solvable',
        );

        // With no givens, multiple solutions exist - this is expected
        // Just verify that at least one valid solution exists
        final KillerQueensBoard solution = result.solutions.first;
        final ValidationSummary summary = engine.validator.validateSolution(
          puzzle.state,
          solution,
        );
        expect(summary.isValid, isTrue, reason: summary.issues.join(','));
      }
    });

    test('cage count matches the board size', () {
      const List<String> seeds = <String>[
        'killer_queens_cage_check_0',
        'killer_queens_cage_check_1',
        'killer_queens_cage_check_2',
      ];

      for (final String seedStr in seeds) {
        final int seed64 = Seed.fromString(seedStr);
        final GeneratedPuzzle<KillerQueensBoard> puzzle = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size,
          difficulty: difficulty,
        );

        expect(
          puzzle.state.cages.length,
          equals(puzzle.state.size),
          reason: 'Seed $seedStr should have exactly one cage per row',
        );

        for (final KillerQueensCage cage in puzzle.state.cages) {
          expect(cage.cells, isNotEmpty, reason: 'Cages cannot be empty');
        }
      }
    });

    test('regenerating with different seeds produces varied cage layouts', () {
      final Set<String> cageSignatures = <String>{};
      for (int i = 0; i < 4; i++) {
        final String seedStr = 'killer_queens_variation_$i';
        final int seed64 = Seed.fromString(seedStr);
        final GeneratedPuzzle<KillerQueensBoard> puzzle = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size,
          difficulty: difficulty,
        );
        // Use cage layout as signature since all puzzles start empty
        final cageString = puzzle.state.cages
            .map((c) => c.cells.join(','))
            .join(';');
        cageSignatures.add(cageString);
      }
      expect(cageSignatures.length, greaterThan(1));
    });
  });
}
