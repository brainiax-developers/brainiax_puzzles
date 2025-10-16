import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/kakuro/kakuro_board.dart';
import 'package:puzzle_core/src/kakuro/kakuro_engine.dart';
import 'package:puzzle_core/src/kakuro/kakuro_move.dart';
import 'package:puzzle_core/src/kakuro/kakuro_solver.dart';
import 'package:puzzle_core/src/solver/solver.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:puzzle_core/src/validation/validator.dart';
import 'package:test/test.dart';

void main() {
  final KakuroEngine engine = KakuroEngine();
  final SizeOpt size = const SizeOpt(
    id: 'template9x9',
    description: 'Template 9x9',
    width: 9,
    height: 9,
  );
  const DifficultyScore difficulty = DifficultyScore(value: 0.0, level: 'auto');

  test('engine generates puzzle with metadata and difficulty telemetry', () {
    final int seed64 = Seed.fromString('kakuro_engine_seed');
    final generated = engine.generate(
      seedStr: 'kakuro_engine_seed',
      seed64: seed64,
      size: size,
      difficulty: difficulty,
    );

    expect(generated.state.width, equals(9));
    expect(generated.meta.seed64, equals(seed64));
    expect(generated.telemetry, isNotNull);
    expect(generated.telemetry!.difficulty.metrics.containsKey('rawScore'), isTrue);

    final KakuroSolver solver = const KakuroSolver();
    final SolverResult<KakuroBoard> solved = solver.solve(
      generated.state,
      SolverContext(rng: SeededRng(seed64 ^ 0x1375a9b3f18c4461), maxSolutions: 1),
    );
    expect(solved.hasSolution, isTrue);
    final KakuroBoard solution = solved.solutions.first;

    final ValidationSummary summary = engine.validator.validateSolution(
      generated.state,
      solution,
    );
    expect(summary.isValid, isTrue, reason: summary.issues.join(','));
  });

  test('validateMove enforces bounds and rules', () {
    final int seed64 = Seed.fromString('kakuro_move_seed');
    final generated = engine.generate(
      seedStr: 'kakuro_move_seed',
      seed64: seed64,
      size: size,
      difficulty: difficulty,
    );
    final KakuroBoard puzzle = generated.state;
    final KakuroSolver solver = const KakuroSolver();
    final KakuroBoard solution = solver
        .solve(puzzle, SolverContext(rng: SeededRng(seed64), maxSolutions: 1))
        .solutions
        .first;

    int targetIndex = -1;
    for (int i = 0; i < puzzle.cellCount; i++) {
      if (puzzle.isPlayableIndex(i)) {
        targetIndex = i;
        break;
      }
    }
    expect(targetIndex, isNot(-1));
    final int row = targetIndex ~/ puzzle.width;
    final int col = targetIndex % puzzle.width;
    final int correctDigit = solution.values[targetIndex];

    final moveResult = engine.validateMove(
      currentState: puzzle,
      move: KakuroMove(row: row, col: col, digit: correctDigit),
    );
    expect(moveResult.isValid, isTrue);

    final invalidResult = engine.validateMove(
      currentState: puzzle,
      move: const KakuroMove(row: -1, col: 0, digit: 5),
    );
    expect(invalidResult.isValid, isFalse);
  });
}
