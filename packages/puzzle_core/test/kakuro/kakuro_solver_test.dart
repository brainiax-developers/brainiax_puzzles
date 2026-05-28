import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/generators/generator.dart';
import 'package:puzzle_core/src/kakuro/kakuro_board.dart';
import 'package:puzzle_core/src/kakuro/kakuro_generator.dart';
import 'package:puzzle_core/src/kakuro/kakuro_solver.dart';
import 'package:puzzle_core/src/solver/solver.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:test/test.dart';

void main() {
  test('solver telemetry captures propagation metrics', () {
    const KakuroGenerator generator = KakuroGenerator();
    const KakuroSolver solver = KakuroSolver();

    final int seed64 = Seed.fromString('kakuro_solver_seed');
    final GeneratorContext context = GeneratorContext(
      rng: SeededRng(seed64),
      seedStr: 'kakuro_solver_seed',
      seed64: seed64,
      size: const SizeOpt(
        id: 'template9x9',
        description: 'Template 9x9',
        width: 9,
        height: 9,
      ),
      difficulty: const DifficultyRequest(level: 'auto'),
    );

    final KakuroBoard puzzle = generator.generate(context).board;
    final SolverResult<KakuroBoard> result = solver.solve(
      puzzle,
      SolverContext(rng: SeededRng(seed64 ^ 0x4b12f8d2637a11ce), maxSolutions: 2),
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

    final double shrink = (telemetry['candidateShrinkPercent'] as num).toDouble();
    final double singleComboRunRatio =
        (telemetry['singleComboRunRatio'] as num).toDouble();
    expect(shrink, inInclusiveRange(0.0, 1.0));
    expect(singleComboRunRatio, inInclusiveRange(0.0, 1.0));
    expect((telemetry['searchNodes'] as num).toInt(), greaterThanOrEqualTo(1));
    expect((telemetry['maxDepth'] as num).toInt(), greaterThanOrEqualTo(0));
    expect(
      (telemetry['maxBranchingFactor'] as num).toInt(),
      greaterThanOrEqualTo(0),
    );
    expect((telemetry['forcedAssignments'] as num).toInt(), greaterThanOrEqualTo(0));
    expect((telemetry['backtrackNodes'] as num).toInt(), greaterThanOrEqualTo(0));
  });

  test('tiny backtrack budget yields unknown status, not unique', () {
    const KakuroGenerator generator = KakuroGenerator();
    const KakuroSolver strictSolver = KakuroSolver(maxBacktrackNodes: 0);

    final int seed64 = Seed.fromString('kakuro_solver_seed');
    final GeneratorContext context = GeneratorContext(
      rng: SeededRng(seed64),
      seedStr: 'kakuro_solver_seed',
      seed64: seed64,
      size: const SizeOpt(
        id: 'template9x9',
        description: 'Template 9x9',
        width: 9,
        height: 9,
      ),
      difficulty: const DifficultyRequest(level: 'auto'),
    );

    final KakuroBoard puzzle = generator.generate(context).board;
    final SolverResult<KakuroBoard> result = strictSolver.solve(
      puzzle,
      SolverContext(rng: SeededRng(seed64 ^ 0x5c3ab48192e7d4f1), maxSolutions: 2),
    );

    expect(result.solutionStatus, SolverStatus.unknown);
    expect(result.isUnique, isFalse);
  });
}
