import 'dart:convert';
import 'dart:math';

import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:test/test.dart';

class EngineAcceptanceConfig<TBoard> {
  const EngineAcceptanceConfig({
    required this.name,
    required this.engineFactory,
    required this.solverFactory,
    required this.size,
    required this.difficulty,
    required this.canonicalSignature,
    required this.difficultyFixtures,
    this.validationP95Millis = 50,
    this.generationP95Millis = 100,
    this.propertySeedCount = 12,
    this.determinismSampleCount = 3,
    this.performanceSampleCount = 100,
  });

  final String name;
  final PipelinePuzzleEngine<TBoard, dynamic> Function() engineFactory;
  final PuzzleSolver<TBoard> Function() solverFactory;
  final SizeOpt size;
  final DifficultyScore difficulty;
  final String Function(TBoard board) canonicalSignature;
  final List<DifficultyFixture<TBoard>> difficultyFixtures;
  final double validationP95Millis;
  final double generationP95Millis;
  final int propertySeedCount;
  final int determinismSampleCount;
  final int performanceSampleCount;
}

class DifficultyFixture<TBoard> {
  const DifficultyFixture({
    required this.name,
    required this.puzzle,
    required this.solution,
    this.generatorTelemetry = const <String, Object?>{},
    this.solverTelemetry = const <String, Object?>{},
    required this.expectedBucket,
  });

  final String name;
  final TBoard puzzle;
  final TBoard solution;
  final Map<String, Object?> generatorTelemetry;
  final Map<String, Object?> solverTelemetry;
  final String expectedBucket;
}

void main() {
  final List<EngineAcceptanceConfig<dynamic>> configs = <EngineAcceptanceConfig<dynamic>>[
    EngineAcceptanceConfig<SudokuBoard>(
      name: 'Sudoku',
      engineFactory: () => SudokuEngine(),
      solverFactory: () => const SudokuSolver(),
      size: const SizeOpt(
        id: 'classic9x9',
        description: 'Classic 9x9',
        width: 9,
        height: 9,
      ),
      difficulty: const DifficultyScore(value: 0.0, level: 'auto'),
      canonicalSignature: (SudokuBoard board) => jsonEncode(board.toJson()),
      difficultyFixtures: _sudokuDifficultyFixtures(),
      validationP95Millis: 35,
    ),
    EngineAcceptanceConfig<KillerQueensBoard>(
      name: 'Killer Queens',
      engineFactory: () => KillerQueensEngine(),
      solverFactory: () => const KillerQueensSolver(),
      size: const SizeOpt(
        id: 'killer6x6',
        description: 'Killer Queens 6x6',
        width: 6,
        height: 6,
      ),
      difficulty: const DifficultyScore(value: 0.0, level: 'auto'),
      canonicalSignature: (KillerQueensBoard board) => jsonEncode(board.toJson()),
      difficultyFixtures: _killerQueensDifficultyFixtures(),
      validationP95Millis: 45,
    ),
    EngineAcceptanceConfig<MathdokuBoard>(
      name: 'Mathdoku',
      engineFactory: () => MathdokuEngine(),
      solverFactory: () => const MathdokuSolver(),
      size: const SizeOpt(
        id: 'latin4x4',
        description: 'Mathdoku 4x4',
        width: 4,
        height: 4,
      ),
      difficulty: const DifficultyScore(value: 0.0, level: 'auto'),
      canonicalSignature: (MathdokuBoard board) => jsonEncode(board.toJson()),
      difficultyFixtures: _mathdokuDifficultyFixtures(),
      validationP95Millis: 45,
    ),
    EngineAcceptanceConfig<NonogramBoard>(
      name: 'Nonogram',
      engineFactory: () => NonogramEngine(),
      solverFactory: () => const NonogramSolver(),
      size: const SizeOpt(
        id: 'mono10x10',
        description: 'Monochrome 10x10',
        width: 10,
        height: 10,
      ),
      difficulty: const DifficultyScore(value: 0.0, level: 'auto'),
      canonicalSignature: (NonogramBoard board) => jsonEncode(board.toJson()),
      difficultyFixtures: _nonogramDifficultyFixtures(),
      validationP95Millis: 45,
    ),
    EngineAcceptanceConfig<KakuroBoard>(
      name: 'Kakuro',
      engineFactory: () => KakuroEngine(),
      solverFactory: () => const KakuroSolver(),
      size: const SizeOpt(
        id: 'template9x9',
        description: 'Template 9x9',
        width: 9,
        height: 9,
      ),
      difficulty: const DifficultyScore(value: 0.0, level: 'auto'),
      canonicalSignature: (KakuroBoard board) => jsonEncode(board.toJson()),
      difficultyFixtures: _kakuroDifficultyFixtures(),
      validationP95Millis: 55,
    ),
    EngineAcceptanceConfig<SlitherlinkBoard>(
      name: 'Slitherlink',
      engineFactory: () => SlitherlinkEngine(),
      solverFactory: () => const SlitherlinkSolver(),
      size: const SizeOpt(
        id: 'rectangular6x6',
        description: 'Slitherlink 6x6',
        width: 6,
        height: 6,
      ),
      difficulty: const DifficultyScore(value: 0.0, level: 'auto'),
      canonicalSignature: (SlitherlinkBoard board) => jsonEncode(board.toJson()),
      difficultyFixtures: _slitherlinkDifficultyFixtures(),
      validationP95Millis: 55,
    ),
    EngineAcceptanceConfig<TakuzuBoard>(
      name: 'Takuzu',
      engineFactory: () => TakuzuEngine(),
      solverFactory: () => const TakuzuSolver(),
      size: const SizeOpt(
        id: 'binary8x8',
        description: 'Takuzu 8x8',
        width: 8,
        height: 8,
      ),
      difficulty: const DifficultyScore(value: 0.0, level: 'auto'),
      canonicalSignature: (TakuzuBoard board) => jsonEncode(board.toJson()),
      difficultyFixtures: _takuzuDifficultyFixtures(),
      validationP95Millis: 40,
    ),
  ];

  for (final EngineAcceptanceConfig<dynamic> config in configs) {
    group('${config.name} engine acceptance', () {
      test('same seed yields identical initial hash', () {
        final PipelinePuzzleEngine<dynamic, dynamic> engine = config.engineFactory();
        final String engineId = engine.id;

        for (int i = 0; i < config.determinismSampleCount; i++) {
          final String seedStr = '$engineId:determinism:$i';
          final int seed64 = Seed.fromString(seedStr);

          final GeneratedPuzzle<dynamic> first = engine.generate(
            seedStr: seedStr,
            seed64: seed64,
            size: config.size,
            difficulty: config.difficulty,
          );
          final GeneratedPuzzle<dynamic> second = engine.generate(
            seedStr: seedStr,
            seed64: seed64,
            size: config.size,
            difficulty: config.difficulty,
          );

          final String firstSignature = config.canonicalSignature(first.state);
          final String secondSignature = config.canonicalSignature(second.state);

          expect(firstSignature, equals(secondSignature), reason: 'Seed $seedStr');
          expect(first.meta.seed64, equals(second.meta.seed64));
          expect(first.meta.seedStr, equals(second.meta.seedStr));
        }
      });

      test('uniqueness enforced via second-solution early exit', () {
        final PipelinePuzzleEngine<dynamic, dynamic> engine = config.engineFactory();
        final PuzzleSolver<dynamic> solver = config.solverFactory();
        final String seedStr = '${engine.id}:uniqueness';
        final int seed64 = Seed.fromString(seedStr);

        final GeneratedPuzzle<dynamic> puzzle = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: config.size,
          difficulty: config.difficulty,
        );

        final SolverResult<dynamic> result = solver.solve(
          puzzle.state,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
        );

        expect(result.hasSolution, isTrue, reason: 'Puzzle must be solvable');
        expect(result.isUnique, isTrue, reason: 'Puzzle must remain unique');
      });

      test('solver reaches a solved state that validates', () {
        final PipelinePuzzleEngine<dynamic, dynamic> engine = config.engineFactory();
        final PuzzleSolver<dynamic> solver = config.solverFactory();
        final String seedStr = '${engine.id}:solve-check';
        final int seed64 = Seed.fromString(seedStr);

        final GeneratedPuzzle<dynamic> puzzle = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: config.size,
          difficulty: config.difficulty,
        );

        final SolverResult<dynamic> result = solver.solve(
          puzzle.state,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 1),
        );

        expect(result.hasSolution, isTrue, reason: 'Solver must succeed');
        final dynamic solution = result.solutions.single;

        final ValidationSummary summary = engine.validator.validateSolution(
          puzzle.state,
          solution,
        );
        expect(summary.isValid, isTrue, reason: summary.issues.join(','));
        expect(engine.isSolved(solution), isTrue);
      });

      test('validator p95 on solved boards stays under ${config.validationP95Millis}ms', () {
        final PipelinePuzzleEngine<dynamic, dynamic> engine = config.engineFactory();
        final PuzzleSolver<dynamic> solver = config.solverFactory();
        final List<int> durations = <int>[];

        const int samples = 20;
        for (int i = 0; i < samples; i++) {
          final String seedStr = '${engine.id}:validation:$i';
          final int seed64 = Seed.fromString(seedStr);

          final GeneratedPuzzle<dynamic> puzzle = engine.generate(
            seedStr: seedStr,
            seed64: seed64,
            size: config.size,
            difficulty: config.difficulty,
          );
          final SolverResult<dynamic> solved = solver.solve(
            puzzle.state,
            SolverContext(rng: SeededRng(seed64), maxSolutions: 1),
          );
          final dynamic solution = solved.solutions.single;

          final ValidationSummary summary = engine.validator.validateSolution(
            puzzle.state,
            solution,
          );
          expect(summary.isValid, isTrue, reason: summary.issues.join(','));
          durations.add(summary.elapsed.inMicroseconds);
        }

        durations.sort();
        final int p95Micros = _percentileMicros(durations, 0.95);
        final double p95Millis = p95Micros / 1000.0;
        expect(p95Millis, lessThan(config.validationP95Millis));
      });

      test('difficulty bucket fixtures remain stable', () {
        final PipelinePuzzleEngine<dynamic, dynamic> engine = config.engineFactory();
        for (final DifficultyFixture<dynamic> fixture in config.difficultyFixtures) {
          final DifficultyTelemetry telemetry = engine.difficultyScorer.score(
            puzzle: fixture.puzzle,
            solution: fixture.solution,
            context: DifficultyContext(
              generatorTelemetry: fixture.generatorTelemetry,
              solverTelemetry: fixture.solverTelemetry,
            ),
          );

          final String bucket = engine.difficultyConfig.bucketFor(telemetry.rawScore);
          expect(bucket, fixture.expectedBucket, reason: fixture.name);
        }
      });

      test('property sample of random seeds stay solvable and unique', () {
        final PipelinePuzzleEngine<dynamic, dynamic> engine = config.engineFactory();
        final PuzzleSolver<dynamic> solver = config.solverFactory();

        for (int i = 0; i < config.propertySeedCount; i++) {
          final String seedStr = '${engine.id}:property:$i:${i * 17}';
          final int seed64 = Seed.fromString(seedStr);

          final GeneratedPuzzle<dynamic> puzzle = engine.generate(
            seedStr: seedStr,
            seed64: seed64,
            size: config.size,
            difficulty: config.difficulty,
          );

          final SolverResult<dynamic> result = solver.solve(
            puzzle.state,
            SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
          );

          expect(result.hasSolution, isTrue, reason: 'Seed $seedStr should be solvable');
          expect(result.isUnique, isTrue, reason: 'Seed $seedStr should have unique solution');
        }
      });

      test(
        'generation p95 under ${config.generationP95Millis}ms for 100 boards',
        () {
          final PipelinePuzzleEngine<dynamic, dynamic> engine = config.engineFactory();
          final List<int> durations = <int>[];

          for (int i = 0; i < config.performanceSampleCount; i++) {
            final String seedStr = '${engine.id}:perf:$i';
            final int seed64 = Seed.fromString(seedStr);
            final Stopwatch stopwatch = Stopwatch()..start();
            engine.generate(
              seedStr: seedStr,
              seed64: seed64,
              size: config.size,
              difficulty: config.difficulty,
            );
            stopwatch.stop();
            durations.add(stopwatch.elapsedMicroseconds);
          }

          durations.sort();
          final int p95Micros = _percentileMicros(durations, 0.95);
          final double p95Millis = p95Micros / 1000.0;
          expect(p95Millis, lessThan(config.generationP95Millis));
        },
        tags: <String>['device-only'],
      );
    });
  }
}

int _percentileMicros(List<int> sortedMicros, double percentile) {
  if (sortedMicros.isEmpty) {
    return 0;
  }
  final int index = max(0, (percentile * (sortedMicros.length - 1)).round());
  return sortedMicros[index];
}

List<DifficultyFixture<SudokuBoard>> _sudokuDifficultyFixtures() {
  final SudokuBoard solution = _sudokuBoardFromMatrix(const <List<int>>[
    <int>[5, 3, 4, 6, 7, 8, 9, 1, 2],
    <int>[6, 7, 2, 1, 9, 5, 3, 4, 8],
    <int>[1, 9, 8, 3, 4, 2, 5, 6, 7],
    <int>[8, 5, 9, 7, 6, 1, 4, 2, 3],
    <int>[4, 2, 6, 8, 5, 3, 7, 9, 1],
    <int>[7, 1, 3, 9, 2, 4, 8, 5, 6],
    <int>[9, 6, 1, 5, 3, 7, 2, 8, 4],
    <int>[2, 8, 7, 4, 1, 9, 6, 3, 5],
    <int>[3, 4, 5, 2, 8, 6, 1, 7, 9],
  ]);

  return <DifficultyFixture<SudokuBoard>>[
    DifficultyFixture<SudokuBoard>(
      name: 'sudoku-easy',
      puzzle: _sudokuBoardFromMatrix(const <List<int>>[
        <int>[5, 3, 0, 6, 0, 8, 9, 1, 2],
        <int>[6, 0, 2, 1, 9, 5, 0, 4, 8],
        <int>[1, 9, 0, 3, 4, 2, 5, 6, 7],
        <int>[8, 5, 9, 7, 0, 1, 4, 2, 3],
        <int>[4, 2, 6, 8, 5, 3, 7, 0, 1],
        <int>[7, 1, 0, 9, 2, 4, 8, 5, 6],
        <int>[9, 6, 1, 5, 3, 7, 2, 8, 0],
        <int>[2, 8, 7, 4, 1, 9, 0, 3, 5],
        <int>[3, 4, 5, 2, 8, 6, 1, 7, 9],
      ]),
      solution: solution,
      solverTelemetry: const <String, Object?>{
        'humanAssignments': 10,
        'techniqueCounts': <String, int>{'nakedSingle': 10},
        'searchDepth': 0,
        'searchNodes': 0,
      },
      expectedBucket: 'easy',
    ),
    DifficultyFixture<SudokuBoard>(
      name: 'sudoku-medium',
      puzzle: _sudokuBoardFromMatrix(const <List<int>>[
        <int>[5, 0, 4, 6, 7, 8, 9, 1, 2],
        <int>[6, 7, 0, 1, 9, 5, 3, 4, 8],
        <int>[1, 9, 8, 3, 0, 2, 5, 6, 7],
        <int>[8, 5, 9, 7, 6, 1, 4, 2, 3],
        <int>[4, 2, 6, 8, 5, 3, 7, 9, 1],
        <int>[7, 1, 3, 9, 2, 4, 8, 5, 6],
        <int>[9, 6, 1, 5, 3, 7, 2, 8, 4],
        <int>[2, 8, 7, 4, 1, 9, 6, 3, 5],
        <int>[3, 4, 5, 2, 8, 6, 1, 7, 9],
      ]),
      solution: solution,
      solverTelemetry: const <String, Object?>{
        'humanAssignments': 35,
        'techniqueCounts': <String, int>{
          'nakedSingle': 20,
          'hiddenSingle': 10,
          'nakedSubset': 5,
        },
        'searchDepth': 0,
        'searchNodes': 0,
      },
      expectedBucket: 'medium',
    ),
    DifficultyFixture<SudokuBoard>(
      name: 'sudoku-hard',
      puzzle: _sudokuBoardFromMatrix(const <List<int>>[
        <int>[5, 0, 4, 0, 7, 8, 9, 1, 2],
        <int>[6, 7, 0, 1, 9, 5, 3, 4, 0],
        <int>[1, 9, 8, 3, 0, 2, 5, 6, 7],
        <int>[8, 5, 9, 7, 6, 1, 4, 0, 3],
        <int>[4, 2, 6, 8, 5, 3, 7, 9, 1],
        <int>[7, 1, 3, 9, 2, 4, 0, 5, 6],
        <int>[9, 6, 1, 5, 3, 7, 2, 8, 4],
        <int>[2, 8, 7, 4, 1, 9, 6, 3, 5],
        <int>[3, 4, 5, 2, 8, 6, 1, 7, 9],
      ]),
      solution: solution,
      solverTelemetry: const <String, Object?>{
        'humanAssignments': 45,
        'techniqueCounts': <String, int>{
          'nakedSingle': 15,
          'hiddenSingle': 12,
          'nakedSubset': 8,
          'pointing': 5,
          'claiming': 5,
        },
        'searchDepth': 2,
        'searchNodes': 180,
      },
      expectedBucket: 'hard',
    ),
    DifficultyFixture<SudokuBoard>(
      name: 'sudoku-expert',
      puzzle: _sudokuBoardFromMatrix(const <List<int>>[
        <int>[5, 0, 4, 0, 7, 0, 9, 1, 0],
        <int>[6, 0, 0, 1, 9, 5, 3, 4, 0],
        <int>[1, 9, 8, 0, 0, 2, 5, 6, 0],
        <int>[8, 5, 9, 7, 0, 1, 4, 0, 3],
        <int>[4, 2, 6, 8, 5, 3, 7, 9, 1],
        <int>[7, 1, 3, 9, 2, 4, 0, 5, 6],
        <int>[9, 6, 1, 5, 3, 7, 2, 8, 4],
        <int>[2, 8, 7, 4, 1, 9, 6, 3, 5],
        <int>[3, 4, 5, 2, 8, 6, 1, 7, 9],
      ]),
      solution: solution,
      solverTelemetry: const <String, Object?>{
        'humanAssignments': 55,
        'techniqueCounts': <String, int>{
          'nakedSingle': 12,
          'hiddenSingle': 10,
          'nakedSubset': 8,
          'pointing': 6,
          'claiming': 6,
          'xWing': 3,
          'swordfish': 2,
        },
        'searchDepth': 4,
        'searchNodes': 560,
      },
      expectedBucket: 'expert',
    ),
  ];
}

SudokuBoard _sudokuBoardFromMatrix(List<List<int>> values) {
  final List<int> cells = <int>[];
  final List<bool> fixed = <bool>[];
  for (final List<int> row in values) {
    for (final int value in row) {
      cells.add(value);
      fixed.add(value != 0);
    }
  }
  return SudokuBoard(cells: cells, fixed: fixed);
}

List<DifficultyFixture<KillerQueensBoard>> _killerQueensDifficultyFixtures() {
  KillerQueensBoard _puzzle({
    required int size,
    required List<int> queenCols,
    Set<int> givens = const <int>{},
    Set<int> blocked = const <int>{},
    List<int> cagePattern = const <int>[2],
  }) {
    final int cellCount = size * size;
    final List<bool> blockedFlags = List<bool>.filled(cellCount, false);
    for (final int index in blocked) {
      blockedFlags[index] = true;
    }
    final List<KillerQueensCage> cages = _buildRowCages(
      size: size,
      blocked: blockedFlags,
      cagePattern: cagePattern,
    );
    final List<int> cells = List<int>.filled(cellCount, 0);
    final List<bool> fixed = List<bool>.filled(cellCount, false);
    for (int row = 0; row < size; row++) {
      final int col = queenCols[row];
      final int index = row * size + col;
      if (givens.contains(index)) {
        cells[index] = 1;
        fixed[index] = true;
      }
    }
    return KillerQueensBoard(
      size: size,
      cells: cells,
      fixed: fixed,
      cages: cages,
    );
  }

  KillerQueensBoard _solution({
    required int size,
    required List<int> queenCols,
    Set<int> blocked = const <int>{},
    List<int> cagePattern = const <int>[2],
  }) {
    final int cellCount = size * size;
    final List<bool> blockedFlags = List<bool>.filled(cellCount, false);
    for (final int index in blocked) {
      blockedFlags[index] = true;
    }
    final List<KillerQueensCage> cages = _buildRowCages(
      size: size,
      blocked: blockedFlags,
      cagePattern: cagePattern,
    );
    final List<int> cells = List<int>.filled(cellCount, 0);
    final List<bool> fixed = List<bool>.filled(cellCount, true);
    for (int row = 0; row < size; row++) {
      final int col = queenCols[row];
      final int index = row * size + col;
      cells[index] = 1;
    }
    return KillerQueensBoard(
      size: size,
      cells: cells,
      fixed: fixed,
      cages: cages,
    );
  }

  final KillerQueensBoard easyPuzzle = _puzzle(
    size: 6,
    queenCols: const <int>[1, 3, 5, 0, 2, 4],
    givens: {1, 26, 34},
    cagePattern: const <int>[2],
  );
  final KillerQueensBoard easySolution = _solution(
    size: 6,
    queenCols: const <int>[1, 3, 5, 0, 2, 4],
    cagePattern: const <int>[2],
  );

  final KillerQueensBoard mediumPuzzle = _puzzle(
    size: 8,
    queenCols: const <int>[1, 4, 6, 0, 3, 7, 2, 5],
    givens: {1, 35},
    blocked: {10, 44},
    cagePattern: const <int>[3, 2],
  );
  final KillerQueensBoard mediumSolution = _solution(
    size: 8,
    queenCols: const <int>[1, 4, 6, 0, 3, 7, 2, 5],
    blocked: {10, 44},
    cagePattern: const <int>[3, 2],
  );

  final KillerQueensBoard hardPuzzle = _puzzle(
    size: 9,
    queenCols: const <int>[1, 3, 5, 0, 7, 2, 8, 4, 6],
    blocked: {9, 40, 63},
    cagePattern: const <int>[4, 3, 2],
  );
  final KillerQueensBoard hardSolution = _solution(
    size: 9,
    queenCols: const <int>[1, 3, 5, 0, 7, 2, 8, 4, 6],
    blocked: {9, 40, 63},
    cagePattern: const <int>[4, 3, 2],
  );

  final KillerQueensBoard expertPuzzle = _puzzle(
    size: 10,
    queenCols: const <int>[1, 3, 5, 7, 9, 0, 2, 4, 6, 8],
    blocked: {11, 22, 45, 66, 77},
    cagePattern: const <int>[3, 4, 3, 2],
  );
  final KillerQueensBoard expertSolution = _solution(
    size: 10,
    queenCols: const <int>[1, 3, 5, 7, 9, 0, 2, 4, 6, 8],
    blocked: {11, 22, 45, 66, 77},
    cagePattern: const <int>[3, 4, 3, 2],
  );

  return <DifficultyFixture<KillerQueensBoard>>[
    DifficultyFixture<KillerQueensBoard>(
      name: 'killer-queens-easy',
      puzzle: easyPuzzle,
      solution: easySolution,
      generatorTelemetry: const <String, Object?>{'attempts': 1},
      solverTelemetry: const <String, Object?>{'branches': 0},
      expectedBucket: 'easy',
    ),
    DifficultyFixture<KillerQueensBoard>(
      name: 'killer-queens-medium',
      puzzle: mediumPuzzle,
      solution: mediumSolution,
      generatorTelemetry: const <String, Object?>{'attempts': 2},
      solverTelemetry: const <String, Object?>{'branches': 18},
      expectedBucket: 'medium',
    ),
    DifficultyFixture<KillerQueensBoard>(
      name: 'killer-queens-hard',
      puzzle: hardPuzzle,
      solution: hardSolution,
      generatorTelemetry: const <String, Object?>{'attempts': 3},
      solverTelemetry: const <String, Object?>{'branches': 36},
      expectedBucket: 'hard',
    ),
    DifficultyFixture<KillerQueensBoard>(
      name: 'killer-queens-expert',
      puzzle: expertPuzzle,
      solution: expertSolution,
      generatorTelemetry: const <String, Object?>{'attempts': 4},
      solverTelemetry: const <String, Object?>{'branches': 72},
      expectedBucket: 'expert',
    ),
  ];
}

List<KillerQueensCage> _buildRowCages({
  required int size,
  required List<bool> blocked,
  required List<int> cagePattern,
}) {
  final List<KillerQueensCage> cages = <KillerQueensCage>[];
  int patternIndex = 0;
  int currentTarget = cagePattern[patternIndex % cagePattern.length];

  for (int row = 0; row < size; row++) {
    List<int> buffer = <int>[];
    for (int col = 0; col < size; col++) {
      final int index = row * size + col;
      if (blocked[index]) {
        if (buffer.isNotEmpty) {
          cages.add(KillerQueensCage(cells: List<int>.from(buffer)));
          buffer = <int>[];
          patternIndex += 1;
          currentTarget = cagePattern[patternIndex % cagePattern.length];
        }
        continue;
      }
      buffer.add(index);
      if (buffer.length >= currentTarget) {
        cages.add(KillerQueensCage(cells: List<int>.from(buffer)));
        buffer = <int>[];
        patternIndex += 1;
        currentTarget = cagePattern[patternIndex % cagePattern.length];
      }
    }
    if (buffer.isNotEmpty) {
      cages.add(KillerQueensCage(cells: List<int>.from(buffer)));
      patternIndex += 1;
      currentTarget = cagePattern[patternIndex % cagePattern.length];
    }
  }

  return cages;
}

List<DifficultyFixture<MathdokuBoard>> _mathdokuDifficultyFixtures() {
  MathdokuBoard _basePuzzle() {
    const int size = 4;
    final List<MathdokuCage> cages = <MathdokuCage>[
      for (int index = 0; index < size * size; index++)
        MathdokuCage(
          id: index,
          cells: <int>[index],
          operation: MathdokuOperation.equality,
          target: (index % size) + 1,
        ),
    ];
    return MathdokuBoard(
      size: size,
      cells: List<int>.filled(size * size, 0),
      cages: cages,
    );
  }

  MathdokuBoard _solutionBoard() {
    const int size = 4;
    final List<int> cells = <int>[
      1, 2, 3, 4,
      2, 3, 4, 1,
      3, 4, 1, 2,
      4, 1, 2, 3,
    ];
    final MathdokuBoard puzzle = _basePuzzle();
    return MathdokuBoard(size: size, cells: cells, cages: puzzle.cages);
  }

  final MathdokuBoard puzzle = _basePuzzle();
  final MathdokuBoard solution = _solutionBoard();

  Map<String, Object?> _generatorTelemetry({
    required int cageCount,
    required double avgCageSize,
    required int maxCageSize,
    required double graphDensity,
    required double subtractRatio,
    required double multiplyRatio,
  }) {
    return <String, Object?>{
      'cageCount': cageCount,
      'avgCageSize': avgCageSize,
      'maxCageSize': maxCageSize,
      'graphDensity': graphDensity,
      'opCounts': <String, num>{
        'subtract': subtractRatio * cageCount,
        'divide': 0,
        'multiply': multiplyRatio * cageCount,
      },
    };
  }

  Map<String, Object?> _solverTelemetry({
    required double propagationDepth,
    required double searchDepth,
    required double searchNodes,
  }) {
    return <String, Object?>{
      'propagationDepth': propagationDepth,
      'searchDepth': searchDepth,
      'searchNodes': searchNodes,
    };
  }

  return <DifficultyFixture<MathdokuBoard>>[
    DifficultyFixture<MathdokuBoard>(
      name: 'mathdoku-easy',
      puzzle: puzzle,
      solution: solution,
      generatorTelemetry: _generatorTelemetry(
        cageCount: 8,
        avgCageSize: 1.2,
        maxCageSize: 2,
        graphDensity: 0.05,
        subtractRatio: 0.0,
        multiplyRatio: 0.0,
      ),
      solverTelemetry: _solverTelemetry(
        propagationDepth: 0,
        searchDepth: 0,
        searchNodes: 0,
      ),
      expectedBucket: 'easy',
    ),
    DifficultyFixture<MathdokuBoard>(
      name: 'mathdoku-medium',
      puzzle: puzzle,
      solution: solution,
      generatorTelemetry: _generatorTelemetry(
        cageCount: 10,
        avgCageSize: 2.5,
        maxCageSize: 4,
        graphDensity: 0.2,
        subtractRatio: 0.2,
        multiplyRatio: 0.3,
      ),
      solverTelemetry: _solverTelemetry(
        propagationDepth: 4,
        searchDepth: 1,
        searchNodes: 30,
      ),
      expectedBucket: 'medium',
    ),
    DifficultyFixture<MathdokuBoard>(
      name: 'mathdoku-hard',
      puzzle: puzzle,
      solution: solution,
      generatorTelemetry: _generatorTelemetry(
        cageCount: 12,
        avgCageSize: 3.2,
        maxCageSize: 5,
        graphDensity: 0.35,
        subtractRatio: 0.35,
        multiplyRatio: 0.4,
      ),
      solverTelemetry: _solverTelemetry(
        propagationDepth: 6,
        searchDepth: 3,
        searchNodes: 120,
      ),
      expectedBucket: 'hard',
    ),
    DifficultyFixture<MathdokuBoard>(
      name: 'mathdoku-expert',
      puzzle: puzzle,
      solution: solution,
      generatorTelemetry: _generatorTelemetry(
        cageCount: 14,
        avgCageSize: 3.5,
        maxCageSize: 6,
        graphDensity: 0.5,
        subtractRatio: 0.5,
        multiplyRatio: 0.5,
      ),
      solverTelemetry: _solverTelemetry(
        propagationDepth: 8,
        searchDepth: 4,
        searchNodes: 220,
      ),
      expectedBucket: 'expert',
    ),
  ];
}

List<DifficultyFixture<NonogramBoard>> _nonogramDifficultyFixtures() {
  final NonogramBoard board = NonogramBoard(
    width: 5,
    height: 5,
    rowClues: const <List<int>>[
      <int>[5],
      <int>[1, 1],
      <int>[5],
      <int>[1, 1],
      <int>[5],
    ],
    columnClues: const <List<int>>[
      <int>[5],
      <int>[3],
      <int>[5],
      <int>[3],
      <int>[5],
    ],
    cells: List<int?>.filled(25, null),
  );

  final NonogramBoard solution = NonogramBoard(
    width: 5,
    height: 5,
    rowClues: board.rowClues,
    columnClues: board.columnClues,
    cells: List<int?>.filled(25, 1),
  );

  Map<String, Object?> telemetry(double completion, int speculative) => <String, Object?>{
        'logicCompletion': completion,
        'speculativeSteps': speculative,
      };

  return <DifficultyFixture<NonogramBoard>>[
    DifficultyFixture<NonogramBoard>(
      name: 'nonogram-easy',
      puzzle: board,
      solution: solution,
      solverTelemetry: telemetry(0.95, 0),
      expectedBucket: 'easy',
    ),
    DifficultyFixture<NonogramBoard>(
      name: 'nonogram-medium',
      puzzle: board,
      solution: solution,
      solverTelemetry: telemetry(0.7, 1),
      expectedBucket: 'medium',
    ),
    DifficultyFixture<NonogramBoard>(
      name: 'nonogram-hard',
      puzzle: board,
      solution: solution,
      solverTelemetry: telemetry(0.45, 2),
      expectedBucket: 'hard',
    ),
    DifficultyFixture<NonogramBoard>(
      name: 'nonogram-expert',
      puzzle: board,
      solution: solution,
      solverTelemetry: telemetry(0.2, 3),
      expectedBucket: 'expert',
    ),
  ];
}

List<DifficultyFixture<KakuroBoard>> _kakuroDifficultyFixtures() {
  KakuroBoard _board() {
    final List<KakuroCellKind> kinds = <KakuroCellKind>[
      KakuroCellKind.value,
      KakuroCellKind.value,
      KakuroCellKind.value,
      KakuroCellKind.value,
    ];
    final List<int> values = List<int>.filled(4, 0);
    final List<int?> clues = List<int?>.filled(4, null);
    final List<KakuroEntry> entries = <KakuroEntry>[
      const KakuroEntry(id: 0, direction: KakuroDirection.across, cells: <int>[0, 1], sum: 10),
      const KakuroEntry(id: 1, direction: KakuroDirection.across, cells: <int>[2, 3], sum: 7),
      const KakuroEntry(id: 2, direction: KakuroDirection.down, cells: <int>[0, 2], sum: 9),
      const KakuroEntry(id: 3, direction: KakuroDirection.down, cells: <int>[1, 3], sum: 8),
    ];
    return KakuroBoard(
      width: 2,
      height: 2,
      kinds: kinds,
      values: values,
      acrossClues: clues,
      downClues: clues,
      entries: entries,
      acrossEntryForCell: const <int>[0, 0, 1, 1],
      downEntryForCell: const <int>[2, 3, 2, 3],
    );
  }

  final KakuroBoard puzzle = _board();
  final KakuroBoard solution = KakuroBoard(
    width: puzzle.width,
    height: puzzle.height,
    kinds: puzzle.kinds,
    values: const <int>[1, 9, 4, 3],
    acrossClues: puzzle.acrossClues,
    downClues: puzzle.downClues,
    entries: puzzle.entries,
    acrossEntryForCell: puzzle.acrossEntryForCell,
    downEntryForCell: puzzle.downEntryForCell,
  );

  Map<String, Object?> telemetry({
    required double shrinkPercent,
    required int forcedAssignments,
    required int backtrackNodes,
    required int propagationRounds,
  }) => <String, Object?>{
        'candidateShrinkPercent': shrinkPercent,
        'forcedAssignments': forcedAssignments,
        'backtrackNodes': backtrackNodes,
        'propagationRounds': propagationRounds,
      };

  return <DifficultyFixture<KakuroBoard>>[
    DifficultyFixture<KakuroBoard>(
      name: 'kakuro-easy',
      puzzle: puzzle,
      solution: solution,
      solverTelemetry: telemetry(
        shrinkPercent: 0.9,
        forcedAssignments: 4,
        backtrackNodes: 0,
        propagationRounds: 5,
      ),
      expectedBucket: 'easy',
    ),
    DifficultyFixture<KakuroBoard>(
      name: 'kakuro-medium',
      puzzle: puzzle,
      solution: solution,
      solverTelemetry: telemetry(
        shrinkPercent: 0.6,
        forcedAssignments: 2,
        backtrackNodes: 5,
        propagationRounds: 10,
      ),
      expectedBucket: 'medium',
    ),
    DifficultyFixture<KakuroBoard>(
      name: 'kakuro-hard',
      puzzle: puzzle,
      solution: solution,
      solverTelemetry: telemetry(
        shrinkPercent: 0.45,
        forcedAssignments: 1,
        backtrackNodes: 8,
        propagationRounds: 12,
      ),
      expectedBucket: 'hard',
    ),
    DifficultyFixture<KakuroBoard>(
      name: 'kakuro-expert',
      puzzle: puzzle,
      solution: solution,
      solverTelemetry: telemetry(
        shrinkPercent: 0.2,
        forcedAssignments: 0,
        backtrackNodes: 15,
        propagationRounds: 15,
      ),
      expectedBucket: 'expert',
    ),
  ];
}

List<DifficultyFixture<SlitherlinkBoard>> _slitherlinkDifficultyFixtures() {
  final SlitherlinkBoard board = SlitherlinkBoard.empty(
    width: 4,
    height: 4,
    clues: List<int?>.filled(16, null),
  );
  final SlitherlinkBoard solution = SlitherlinkBoard(
    width: board.width,
    height: board.height,
    clues: board.clues,
    edges: List<int>.filled(board.topology.edgeCount, SlitherlinkBoard.edgeOn),
  );

  Map<String, Object?> telemetry({
    required double total,
    required double local,
    required double global,
    required double speculative,
    required double depth,
  }) => <String, Object?>{
        'totalAssignments': total,
        'localAssignments': local,
        'globalAssignments': global,
        'speculativeSteps': speculative,
        'maxDepth': depth,
      };

  return <DifficultyFixture<SlitherlinkBoard>>[
    DifficultyFixture<SlitherlinkBoard>(
      name: 'slitherlink-easy',
      puzzle: board,
      solution: solution,
      solverTelemetry: telemetry(
        total: 100,
        local: 90,
        global: 5,
        speculative: 0,
        depth: 0,
      ),
      expectedBucket: 'easy',
    ),
    DifficultyFixture<SlitherlinkBoard>(
      name: 'slitherlink-medium',
      puzzle: board,
      solution: solution,
      solverTelemetry: telemetry(
        total: 130,
        local: 80,
        global: 35,
        speculative: 1,
        depth: 1,
      ),
      expectedBucket: 'medium',
    ),
    DifficultyFixture<SlitherlinkBoard>(
      name: 'slitherlink-hard',
      puzzle: board,
      solution: solution,
      solverTelemetry: telemetry(
        total: 150,
        local: 75,
        global: 55,
        speculative: 2,
        depth: 2,
      ),
      expectedBucket: 'hard',
    ),
    DifficultyFixture<SlitherlinkBoard>(
      name: 'slitherlink-expert',
      puzzle: board,
      solution: solution,
      solverTelemetry: telemetry(
        total: 180,
        local: 70,
        global: 80,
        speculative: 3,
        depth: 3,
      ),
      expectedBucket: 'expert',
    ),
  ];
}

List<DifficultyFixture<TakuzuBoard>> _takuzuDifficultyFixtures() {
  TakuzuBoard _solutionBoard() {
    const int size = 4;
    final List<int> cells = <int>[
      0, 0, 1, 1,
      1, 1, 0, 0,
      0, 1, 1, 0,
      1, 0, 0, 1,
    ];
    return TakuzuBoard(
      size: size,
      cells: cells,
      fixed: List<bool>.filled(size * size, true),
    );
  }

  TakuzuBoard puzzleWithGivens(int keepCount) {
    final TakuzuBoard solution = _solutionBoard();
    final int total = solution.cellCount;
    final List<int> cells = List<int>.filled(total, TakuzuBoard.emptyValue);
    final List<bool> fixed = List<bool>.filled(total, false);

    for (int i = 0; i < keepCount && i < total; i++) {
      cells[i] = solution.cells[i];
      fixed[i] = true;
    }

    return TakuzuBoard(size: solution.size, cells: cells, fixed: fixed);
  }

  Map<String, Object?> telemetry({
    required double forcedAssignments,
    required double totalAssignments,
    required double longestChain,
  }) => <String, Object?>{
        'forcedAssignments': forcedAssignments,
        'totalAssignments': totalAssignments,
        'longestChain': longestChain,
      };

  final TakuzuBoard solution = _solutionBoard();

  return <DifficultyFixture<TakuzuBoard>>[
    DifficultyFixture<TakuzuBoard>(
      name: 'takuzu-easy',
      puzzle: puzzleWithGivens(14),
      solution: solution,
      solverTelemetry: telemetry(
        forcedAssignments: 18,
        totalAssignments: 20,
        longestChain: 0,
      ),
      expectedBucket: 'easy',
    ),
    DifficultyFixture<TakuzuBoard>(
      name: 'takuzu-medium',
      puzzle: puzzleWithGivens(12),
      solution: solution,
      solverTelemetry: telemetry(
        forcedAssignments: 24,
        totalAssignments: 32,
        longestChain: 1,
      ),
      expectedBucket: 'medium',
    ),
    DifficultyFixture<TakuzuBoard>(
      name: 'takuzu-hard',
      puzzle: puzzleWithGivens(10),
      solution: solution,
      solverTelemetry: telemetry(
        forcedAssignments: 26,
        totalAssignments: 40,
        longestChain: 2,
      ),
      expectedBucket: 'hard',
    ),
    DifficultyFixture<TakuzuBoard>(
      name: 'takuzu-expert',
      puzzle: puzzleWithGivens(8),
      solution: solution,
      solverTelemetry: telemetry(
        forcedAssignments: 24,
        totalAssignments: 60,
        longestChain: 3,
      ),
      expectedBucket: 'expert',
    ),
  ];
}
