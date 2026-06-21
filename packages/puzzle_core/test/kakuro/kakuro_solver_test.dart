import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/difficulty/difficulty_config.dart';
import 'package:puzzle_core/src/engine/pipeline_engine.dart';
import 'package:puzzle_core/src/generators/generator.dart';
import 'package:puzzle_core/src/kakuro/kakuro_board.dart';
import 'package:puzzle_core/src/kakuro/kakuro_difficulty.dart';
import 'package:puzzle_core/src/kakuro/kakuro_generator.dart';
import 'package:puzzle_core/src/kakuro/kakuro_move.dart';
import 'package:puzzle_core/src/kakuro/kakuro_solver.dart';
import 'package:puzzle_core/src/kakuro/kakuro_validator.dart';
import 'package:puzzle_core/src/solver/solver.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:test/test.dart';

void main() {
  test('solver telemetry captures propagation metrics', () {
    const KakuroSolver solver = KakuroSolver();

    final int seed64 = Seed.fromString('kakuro_solver_seed');
    final KakuroBoard puzzle = _uniqueFixtureBoard();
    final SolverResult<KakuroBoard> result = solver.solve(
      puzzle,
      SolverContext(
        rng: SeededRng(seed64 ^ 0x4b12f8d2637a11ce),
        maxSolutions: 2,
      ),
    );

    expect(result.hasSolution, isTrue);
    expect(result.isUnique, isTrue);
    expect(result.solutionStatus, SolverStatus.unique);

    final Map<String, Object?> telemetry = result.telemetry;
    expect(telemetry.containsKey('forcedAssignments'), isTrue);
    expect(telemetry.containsKey('candidateRemovals'), isTrue);
    expect(telemetry.containsKey('candidateShrinkPercent'), isTrue);
    expect(telemetry.containsKey('searchNodes'), isTrue);
    expect(telemetry.containsKey('backtracks'), isTrue);
    expect(telemetry.containsKey('maxDepth'), isTrue);
    expect(telemetry.containsKey('maxBranchingFactor'), isTrue);
    expect(telemetry.containsKey('avgRunCombinationCount'), isTrue);
    expect(telemetry.containsKey('singleComboRunRatio'), isTrue);
    expect(telemetry.containsKey('maxRunLength'), isTrue);
    expect(telemetry.containsKey('whiteCellCount'), isTrue);
    expect(telemetry.containsKey('runCount'), isTrue);
    expect(telemetry.containsKey('backtrackNodes'), isTrue);
    expect(telemetry.containsKey('disagreementSummary'), isFalse);

    final double shrink = (telemetry['candidateShrinkPercent'] as num)
        .toDouble();
    final double singleComboRunRatio = (telemetry['singleComboRunRatio'] as num)
        .toDouble();
    expect(shrink, inInclusiveRange(0.0, 1.0));
    expect(singleComboRunRatio, inInclusiveRange(0.0, 1.0));
    expect((telemetry['searchNodes'] as num).toInt(), greaterThanOrEqualTo(1));
    expect((telemetry['maxDepth'] as num).toInt(), greaterThanOrEqualTo(0));
    expect(
      (telemetry['maxBranchingFactor'] as num).toInt(),
      greaterThanOrEqualTo(0),
    );
    expect(
      (telemetry['forcedAssignments'] as num).toInt(),
      greaterThanOrEqualTo(0),
    );
    expect(
      (telemetry['backtrackNodes'] as num).toInt(),
      greaterThanOrEqualTo(0),
    );
  });

  test('multiple-solution puzzle emits bounded disagreement summary', () {
    final KakuroLayout layout = KakuroLayout.fromRows(const <String>[
      '####',
      '#..#',
      '#..#',
      '####',
    ]);
    final Map<int, int> entrySums = <int, int>{
      for (final KakuroLayoutEntry entry in layout.entries) entry.id: 5,
    };
    final KakuroBoard puzzle = layout.buildBoard(entrySums);
    const KakuroSolver solver = KakuroSolver();

    final SolverResult<KakuroBoard> result = solver.solve(
      puzzle,
      SolverContext(
        rng: SeededRng(Seed.fromString('kakuro_multi_disagreement_seed')),
        maxSolutions: 2,
      ),
    );

    expect(result.solutionStatus, SolverStatus.multiple);
    expect(result.solutions, hasLength(2));

    final Object? summaryRaw = result.telemetry['disagreementSummary'];
    expect(summaryRaw, isA<Map>());
    final Map<String, Object?> summary = Map<String, Object?>.from(
      summaryRaw as Map,
    );

    expect(summary['disagreementCellCount'], equals(4));
    expect(summary['disagreementAcrossRunCount'], equals(2));
    expect(summary['disagreementDownRunCount'], equals(2));
    expect(summary['disagreementRunCount'], equals(4));
    expect(summary['disagreementTouchesLongRun'], isFalse);
    expect(summary['disagreementMaxRunLength'], equals(2));

    final Map<String, Object?> runIds = Map<String, Object?>.from(
      summary['disagreementRunIds'] as Map,
    );
    expect(runIds['across'], equals(<int>[0, 1]));
    expect(runIds['down'], equals(<int>[2, 3]));

    final Map<String, Object?> boundingBox = Map<String, Object?>.from(
      summary['disagreementBoundingBox'] as Map,
    );
    expect(boundingBox['minRow'], equals(1));
    expect(boundingBox['maxRow'], equals(2));
    expect(boundingBox['minCol'], equals(1));
    expect(boundingBox['maxCol'], equals(2));
    expect(boundingBox['height'], equals(2));
    expect(boundingBox['width'], equals(2));

    final String summaryText = summary.toString().toLowerCase();
    expect(summaryText.contains('values'), isFalse);
    expect(summaryText.contains('solution'), isFalse);
  });

  test('tiny backtrack budget yields unknown status, not unique', () {
    const KakuroSolver strictSolver = KakuroSolver(maxBacktrackNodes: 0);

    final int seed64 = Seed.fromString('kakuro_solver_seed');
    final KakuroBoard puzzle = _uniqueFixtureBoard();
    final SolverResult<KakuroBoard> result = strictSolver.solve(
      puzzle,
      SolverContext(
        rng: SeededRng(seed64 ^ 0x5c3ab48192e7d4f1),
        maxSolutions: 2,
      ),
    );

    expect(result.solutionStatus, SolverStatus.unknown);
    expect(result.isUnique, isFalse);
  });

  test('capped one-solution result is unknown, not unique', () {
    final KakuroBoard puzzle = _ambiguousSumFiveFixtureBoard();
    const KakuroSolver solver = KakuroSolver(maxBacktrackNodes: 2);

    final SolverResult<KakuroBoard> result = solver.solve(
      puzzle,
      SolverContext(
        rng: SeededRng(Seed.fromString('kakuro_capped_one_solution_seed')),
        maxSolutions: 2,
      ),
    );

    expect(result.solutions, hasLength(1));
    expect(result.telemetry['searchBudgetExceeded'], isTrue);
    expect(result.telemetry['hitBacktrackNodeLimit'], isTrue);
    expect(result.solutionStatus, SolverStatus.unknown);
    expect(result.isUnique, isFalse);
  });

  test('pipeline rejects capped one-solution result as unknown', () {
    final KakuroBoard puzzle = _ambiguousSumFiveFixtureBoard();
    const KakuroSolver cappedSolver = KakuroSolver(maxBacktrackNodes: 2);
    final SolverResult<KakuroBoard> cappedResult = cappedSolver.solve(
      puzzle,
      SolverContext(
        rng: SeededRng(Seed.fromString('kakuro_pipeline_capped_seed')),
        maxSolutions: 2,
      ),
    );

    expect(cappedResult.solutions, hasLength(1));
    expect(cappedResult.solutionStatus, SolverStatus.unknown);

    final _StaticKakuroPipelineEngine engine = _StaticKakuroPipelineEngine(
      puzzle,
      solver: cappedSolver,
    );

    expect(
      () => engine.generate(
        seedStr: 'kakuro_pipeline_capped_seed',
        seed64: Seed.fromString('kakuro_pipeline_capped_seed'),
        size: const SizeOpt(
          id: 'fixture4x4',
          description: 'Fixture 4x4',
          width: 4,
          height: 4,
        ),
        difficulty: const DifficultyScore(value: 0.3, level: 'easy'),
      ),
      throwsA(
        isA<StateError>().having(
          (StateError e) => e.toString(),
          'error',
          contains('uniqueness is unknown'),
        ),
      ),
    );
  });
}

KakuroBoard _ambiguousSumFiveFixtureBoard() {
  final KakuroLayout layout = KakuroLayout.fromRows(const <String>[
    '####',
    '#..#',
    '#..#',
    '####',
  ]);
  final Map<int, int> entrySums = <int, int>{
    for (final KakuroLayoutEntry entry in layout.entries) entry.id: 5,
  };
  return layout.buildBoard(entrySums);
}

KakuroBoard _uniqueFixtureBoard() {
  return KakuroBoard(
    width: 2,
    height: 2,
    kinds: const <KakuroCellKind>[
      KakuroCellKind.value,
      KakuroCellKind.value,
      KakuroCellKind.value,
      KakuroCellKind.value,
    ],
    values: const <int>[0, 0, 0, 0],
    acrossClues: const <int?>[null, null, null, null],
    downClues: const <int?>[null, null, null, null],
    entries: const <KakuroEntry>[
      KakuroEntry(
        id: 0,
        direction: KakuroDirection.across,
        cells: <int>[0, 1],
        sum: 3,
      ),
      KakuroEntry(
        id: 1,
        direction: KakuroDirection.across,
        cells: <int>[2, 3],
        sum: 4,
      ),
      KakuroEntry(
        id: 2,
        direction: KakuroDirection.down,
        cells: <int>[0, 2],
        sum: 3,
      ),
      KakuroEntry(
        id: 3,
        direction: KakuroDirection.down,
        cells: <int>[1, 3],
        sum: 4,
      ),
    ],
    acrossEntryForCell: const <int>[0, 0, 1, 1],
    downEntryForCell: const <int>[2, 3, 2, 3],
  );
}

class _StaticKakuroGenerator extends PuzzleGenerator<KakuroBoard> {
  const _StaticKakuroGenerator(this.board);

  final KakuroBoard board;

  @override
  PuzzleGenerationResult<KakuroBoard> generate(GeneratorContext context) {
    return PuzzleGenerationResult<KakuroBoard>(board: board);
  }
}

class _StaticKakuroPipelineEngine
    extends PipelinePuzzleEngine<KakuroBoard, KakuroMove> {
  _StaticKakuroPipelineEngine(
    KakuroBoard board, {
    super.solver = const KakuroSolver(),
  }) : super(
         engineId: 'kakuro_static_fixture',
         engineName: 'Kakuro static fixture',
         engineVersion: 'test',
         generator: _StaticKakuroGenerator(board),
         validator: const KakuroValidator(),
         difficultyScorer: const KakuroDifficultyScorer(),
         difficultyConfig: const DifficultyBucketConfig(
           buckets: <DifficultyBucketThreshold>[
             DifficultyBucketThreshold(id: 'easy', maxInclusive: 1.0),
           ],
         ),
         enforceDifficulty: false,
       );

  @override
  MoveResult<KakuroBoard> validateMove({
    required KakuroBoard currentState,
    required KakuroMove move,
  }) {
    throw UnimplementedError();
  }
}
