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

    test('generated puzzles are unique for fixed seeds', () {
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

        final GenerationTelemetry telemetry = puzzle.telemetry!;
        final SolverResult<KillerQueensBoard> result = solver.solve(
          puzzle.state,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
        );
        final solverTelemetry =
            telemetry.extras['solver'] as Map<String, Object?>;
        final generatorTelemetry =
            telemetry.extras['generator'] as Map<String, Object?>;

        expect(
          telemetry.extras['solutionStatus'],
          equals(SolverStatus.unique.name),
          reason: 'Seed $seedStr should pass production uniqueness',
        );
        expect(telemetry.extras['solutionCount'], equals(1));
        expect(solverTelemetry['maxSolutions'], equals(2));
        expect(generatorTelemetry['uniquenessChecks'], greaterThan(0));
        expect(
          result.solutionStatus,
          equals(SolverStatus.unique),
          reason: 'Seed $seedStr should have exactly one solution',
        );

        final KillerQueensBoard solution = result.solutions.first;
        final ValidationSummary summary = engine.validator.validateSolution(
          puzzle.state,
          solution,
        );
        expect(summary.isValid, isTrue, reason: summary.issues.join(','));
      }
    });

    test('solver returns multiple for a crafted count-to-2 fixture', () {
      const KillerQueensSolver solver = KillerQueensSolver();
      final KillerQueensBoard puzzle = _multiSolutionBoard(size: 6);

      final SolverResult<KillerQueensBoard> result = solver.solve(
        puzzle,
        SolverContext(rng: SeededRng(404), maxSolutions: 2),
      );

      expect(result.solutionStatus, equals(SolverStatus.multiple));
      expect(result.solutions.length, equals(2));
      expect(result.solutions.length, lessThanOrEqualTo(2));
      expect(result.telemetry['maxSolutions'], equals(2));
      expect(result.telemetry['nodes'], isA<int>());
      expect(result.telemetry['branches'], isA<int>());
      expect(result.telemetry['backtracks'], isA<int>());
      expect(result.telemetry['maxDepth'], isA<int>());
      expect(result.telemetry['candidateCounts'], isA<List<int>>());
      expect(result.telemetry['averageBranchingFactor'], isA<double>());
      expect(
        result.telemetry['solutionStatus'],
        equals(SolverStatus.multiple.name),
      );
    });

    test('solver returns unique for a known fixed fixture', () {
      const KillerQueensSolver solver = KillerQueensSolver();
      final KillerQueensBoard puzzle = _fixedUniqueBoard();

      final SolverResult<KillerQueensBoard> result = solver.solve(
        puzzle,
        SolverContext(rng: SeededRng(202), maxSolutions: 2),
      );

      expect(result.solutionStatus, equals(SolverStatus.unique));
      expect(result.solutions.length, equals(1));
      expect(
        result.telemetry['solutionStatus'],
        equals(SolverStatus.unique.name),
      );
    });

    test('solver returns noSolution for inconsistent givens', () {
      const KillerQueensSolver solver = KillerQueensSolver();
      final KillerQueensBoard puzzle = _impossibleBoard();

      final SolverResult<KillerQueensBoard> result = solver.solve(
        puzzle,
        SolverContext(rng: SeededRng(303), maxSolutions: 2),
      );

      expect(result.solutionStatus, equals(SolverStatus.noSolution));
      expect(result.solutions, isEmpty);
      expect(result.telemetry['inconsistent'], isTrue);
      expect(
        result.telemetry['solutionStatus'],
        equals(SolverStatus.noSolution.name),
      );
    });

    test('solver returns unknown when branch budget expires before proof', () {
      const KillerQueensSolver solver = KillerQueensSolver();
      final KillerQueensBoard puzzle = _multiSolutionBoard(size: 6);
      SolverResult<KillerQueensBoard>? capped;

      for (int budget = 1; budget <= 64; budget++) {
        final SolverResult<KillerQueensBoard> result = solver.solve(
          puzzle,
          SolverContext(
            rng: SeededRng(404),
            maxSolutions: 2,
            speculativeStepBudget: budget,
          ),
        );
        if (result.solutions.length == 1 &&
            result.solutionStatus == SolverStatus.unknown) {
          capped = result;
          break;
        }
      }

      expect(capped, isNotNull);
      final SolverResult<KillerQueensBoard> result = capped!;
      expect(result.solutionStatus, equals(SolverStatus.unknown));
      expect(result.isUnique, isFalse);
      expect(result.solutions.length, equals(1));
      expect(result.solutions.length, lessThanOrEqualTo(2));
      expect(result.telemetry['speculativeStepBudgetHit'], isTrue);
      expect(result.telemetry['proofIncomplete'], isTrue);
      expect(
        result.telemetry['solutionStatus'],
        equals(SolverStatus.unknown.name),
      );
    });

    test(
      'pipeline rejects generated Killer Queens boards with multiple solutions',
      () {
        final _NonUniqueKillerQueensEngine nonUniqueEngine =
            _NonUniqueKillerQueensEngine();

        expect(
          () => nonUniqueEngine.generate(
            seedStr: 'killer_queens_non_unique_rejection',
            seed64: Seed.fromString('killer_queens_non_unique_rejection'),
            size: const SizeOpt(
              id: '6x6',
              description: '6x6',
              width: 6,
              height: 6,
            ),
            difficulty: const DifficultyScore(value: 0.3, level: 'easy'),
          ),
          throwsA(
            isA<StateError>().having(
              (StateError error) => error.message,
              'message',
              contains('not unique'),
            ),
          ),
        );
      },
    );

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

KillerQueensBoard _multiSolutionBoard({required int size}) {
  final int cellCount = size * size;
  return KillerQueensBoard(
    size: size,
    cells: List<int>.filled(cellCount, 0),
    fixed: List<bool>.filled(cellCount, false),
    cages: <KillerQueensCage>[
      for (int row = 0; row < size; row++)
        KillerQueensCage(
          cells: <int>[for (int col = 0; col < size; col++) row * size + col],
        ),
    ],
  );
}

KillerQueensBoard _fixedUniqueBoard() {
  return _boardWithFixedQueens(
    size: 6,
    queenCols: const <int>[1, 3, 5, 0, 2, 4],
    fixedRows: const <int>{0, 1, 2, 3, 4, 5},
  );
}

KillerQueensBoard _impossibleBoard() {
  return _boardWithFixedQueens(
    size: 6,
    queenCols: const <int>[1, 1, 5, 0, 2, 4],
    fixedRows: const <int>{0, 1},
  );
}

KillerQueensBoard _boardWithFixedQueens({
  required int size,
  required List<int> queenCols,
  required Set<int> fixedRows,
}) {
  final int cellCount = size * size;
  final List<int> cells = List<int>.filled(cellCount, 0);
  final List<bool> fixed = List<bool>.filled(cellCount, false);
  for (final int row in fixedRows) {
    final int index = row * size + queenCols[row];
    cells[index] = 1;
    fixed[index] = true;
  }
  return KillerQueensBoard(
    size: size,
    cells: cells,
    fixed: fixed,
    cages: <KillerQueensCage>[
      for (int row = 0; row < size; row++)
        KillerQueensCage(
          cells: <int>[for (int col = 0; col < size; col++) row * size + col],
        ),
    ],
  );
}

class _MultiSolutionGenerator extends PuzzleGenerator<KillerQueensBoard> {
  const _MultiSolutionGenerator();

  @override
  PuzzleGenerationResult<KillerQueensBoard> generate(GeneratorContext context) {
    return PuzzleGenerationResult<KillerQueensBoard>(
      board: _multiSolutionBoard(size: context.size.width),
      snapshot: const GenerationSnapshot(
        telemetry: <String, Object?>{'fixture': 'multi_solution'},
      ),
    );
  }
}

class _NonUniqueKillerQueensEngine
    extends PipelinePuzzleEngine<KillerQueensBoard, KillerQueensMove> {
  _NonUniqueKillerQueensEngine()
    : super(
        engineId: 'killer_queens_non_unique_fixture',
        engineName: 'Killer Queens Non-Unique Fixture',
        engineVersion: 'test',
        generator: const _MultiSolutionGenerator(),
        solver: const KillerQueensSolver(),
        validator: const KillerQueensValidator(),
        difficultyScorer: _baseEngine.difficultyScorer,
        difficultyConfig: _baseEngine.difficultyConfig,
        enforceDifficulty: false,
      );

  static final KillerQueensEngine _baseEngine = KillerQueensEngine();

  @override
  MoveResult<KillerQueensBoard> validateMove({
    required KillerQueensBoard currentState,
    required KillerQueensMove move,
  }) {
    return _baseEngine.validateMove(currentState: currentState, move: move);
  }
}
