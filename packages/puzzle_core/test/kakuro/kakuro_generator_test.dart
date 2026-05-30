import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/generators/generator.dart';
import 'package:puzzle_core/src/generators/kakuro/models.dart';
import 'package:puzzle_core/src/kakuro/kakuro_board.dart';
import 'package:puzzle_core/src/kakuro/kakuro_generator.dart';
import 'package:puzzle_core/src/kakuro/kakuro_solver.dart';
import 'package:puzzle_core/src/solver/solver.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:test/test.dart';

void main() {
  test('generator produces solvable puzzle with unique solution', () {
    const KakuroGenerator generator = KakuroGenerator();
    final int seed64 = Seed.fromString('kakuro_gen_seed');
    final GeneratorContext context = GeneratorContext(
      rng: SeededRng(seed64),
      seedStr: 'kakuro_gen_seed',
      seed64: seed64,
      size: const SizeOpt(
        id: 'template9x9',
        description: 'Template 9x9',
        width: 9,
        height: 9,
      ),
      difficulty: const DifficultyRequest(level: 'auto'),
    );

    final puzzleResult = generator.generate(context);
    final KakuroBoard puzzle = puzzleResult.board;
    final Map<String, Object?> telemetry = Map<String, Object?>.from(
      puzzleResult.snapshot.telemetry,
    );

    expect(puzzle.width, equals(9));
    expect(puzzle.height, equals(9));
    expect(telemetry['layoutScoreMilli'], isA<int>());
    expect(telemetry['layoutGateReason'], isA<String>());
    final Map<String, Object?> rejectCounters = Map<String, Object?>.from(
      telemetry['rejectCounters'] as Map? ?? const <String, Object?>{},
    );
    expect(rejectCounters.containsKey('layoutGate'), isTrue);
    expect(telemetry['layoutHash'], equals('57539225835b19aa'));
    expect(
      telemetry['runLengthHistogram'],
      equals(<String, int>{'2': 14, '3': 2, '4': 2, '6': 2, '7': 2}),
    );

    int clueCount = 0;
    for (final int? clue in puzzle.acrossClues) {
      if (clue != null) {
        clueCount++;
      }
    }
    for (final int? clue in puzzle.downClues) {
      if (clue != null) {
        clueCount++;
      }
    }
    expect(clueCount, greaterThan(0));

    final KakuroSolver solver = const KakuroSolver();
    final SolverResult<KakuroBoard> result = solver.solve(
      puzzle,
      SolverContext(
        rng: SeededRng(seed64 ^ 0x9f61d35a2234e881),
        maxSolutions: 2,
      ),
    );

    expect(result.solutionStatus, SolverStatus.unique);
    expect(
      result.isUnique,
      isTrue,
      reason: 'Puzzle should have unique solution',
    );
    expect(result.solutions, hasLength(1));

    final KakuroBoard solution = result.solutions.first;
    for (final KakuroEntry entry in puzzle.entries) {
      final Set<int> seen = <int>{};
      int sum = 0;
      for (final int index in entry.cells) {
        final int digit = solution.values[index];
        expect(digit, inInclusiveRange(1, 9));
        expect(
          seen.add(digit),
          isTrue,
          reason: 'Digits must be unique within entry',
        );
        sum += digit;
      }
      expect(sum, equals(entry.sum));
    }
  });

  test('generator rejects unknown uniqueness when search budget is tiny', () {
    const KakuroGenerator generator = KakuroGenerator(
      maxTemplateAttempts: 2,
      maxBacktrackNodes: 0,
    );
    final int seed64 = Seed.fromString('kakuro_gen_tiny_budget_seed');
    final GeneratorContext context = GeneratorContext(
      rng: SeededRng(seed64),
      seedStr: 'kakuro_gen_tiny_budget_seed',
      seed64: seed64,
      size: const SizeOpt(
        id: 'template9x9',
        description: 'Template 9x9',
        width: 9,
        height: 9,
      ),
      difficulty: const DifficultyRequest(level: 'auto'),
    );

    expect(
      () => generator.generate(context),
      throwsA(isA<GenerationFailure>()),
    );
  });

  test('generator rejects unsupported 13x13 size', () {
    const KakuroGenerator generator = KakuroGenerator();
    final int seed64 = Seed.fromString('kakuro_gen_13x13_seed');
    final GeneratorContext context = GeneratorContext(
      rng: SeededRng(seed64),
      seedStr: 'kakuro_gen_13x13_seed',
      seed64: seed64,
      size: const SizeOpt(
        id: '13x13',
        description: '13x13',
        width: 13,
        height: 13,
      ),
      difficulty: const DifficultyRequest(level: 'expert'),
    );

    expect(
      () => generator.generate(context),
      throwsA(
        isA<ArgumentError>().having(
          (ArgumentError error) => error.toString(),
          'error',
          contains('Supported sizes: 5x5, 7x7, 9x9, 11x11'),
        ),
      ),
    );
  });
}
