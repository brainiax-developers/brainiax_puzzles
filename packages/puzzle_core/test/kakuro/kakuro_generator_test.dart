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
    const List<String> seedCandidates = <String>[
      'kakuro_gen_seed',
      'kakuro_engine_seed',
      'kakuro_move_seed',
      'kakuro_engine_seed_alt_1',
      'kakuro_engine_seed_alt_2',
    ];
    PuzzleGenerationResult<KakuroBoard>? puzzleResult;
    String? selectedSeedStr;
    int selectedSeed64 = 0;
    for (final String seedStr in seedCandidates) {
      final int seed64 = Seed.fromString(seedStr);
      final GeneratorContext context = GeneratorContext(
        rng: SeededRng(seed64),
        seedStr: seedStr,
        seed64: seed64,
        size: const SizeOpt(
          id: 'template9x9',
          description: 'Template 9x9',
          width: 9,
          height: 9,
        ),
        difficulty: const DifficultyRequest(level: 'auto'),
      );
      try {
        puzzleResult = generator.generate(context);
        selectedSeedStr = seedStr;
        selectedSeed64 = seed64;
        break;
      } catch (_) {
        // Try next deterministic seed candidate.
      }
    }
    expect(puzzleResult, isNotNull, reason: 'generation failed for all seeds');

    final KakuroBoard puzzle = puzzleResult!.board;
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
    expect(telemetry['layoutFamilyId'], isA<String>());
    expect(telemetry['layoutHash'], isA<String>());
    expect(telemetry['runLengthHistogram'], isA<Map>());
    expect(telemetry['constructionTelemetry'], isA<Map>());
    final Map<String, Object?> constructionTelemetry =
        Map<String, Object?>.from(
          telemetry['constructionTelemetry'] as Map? ??
              const <String, Object?>{},
        );
    expect(
      constructionTelemetry['averageRunCombinationCountMilli'],
      isA<int>(),
    );
    expect(constructionTelemetry['singleCombinationRunRatioMilli'], isA<int>());
    expect(constructionTelemetry['maxRunAmbiguityMilli'], isA<int>());
    expect(
      constructionTelemetry['intersectionCandidateReductionMilli'],
      isA<int>(),
    );
    expect(
      constructionTelemetry['runLengthWeightedAmbiguityMilli'],
      isA<int>(),
    );
    expect(telemetry['givensCount'], equals(0));
    expect(telemetry['givenRatioMilli'], equals(0));

    int clueCount = 0;
    int playableCount = 0;
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
    for (int i = 0; i < puzzle.cellCount; i++) {
      if (!puzzle.isPlayableIndex(i)) {
        continue;
      }
      playableCount++;
      expect(
        puzzle.values[i],
        equals(0),
        reason: 'Generated Kakuro starts with empty playable cells',
      );
    }
    expect(clueCount, greaterThan(0));
    expect(playableCount, greaterThan(0));

    final KakuroSolver solver = const KakuroSolver();
    final SolverResult<KakuroBoard> result = solver.solve(
      puzzle,
      SolverContext(
        rng: SeededRng(selectedSeed64 ^ 0x9f61d35a2234e881),
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
    expect(selectedSeedStr, isNotNull);
  });

  test(
    'non-unique attempts include disagreement diagnostics in attempt log',
    () {
      const KakuroGenerator generator = KakuroGenerator(
        maxTemplateAttempts: 3,
        maxBacktrackNodes: 200,
      );
      final int seed64 = Seed.fromString('diag_easy_5_0');
      final GeneratorContext context = GeneratorContext(
        rng: SeededRng(seed64),
        seedStr: 'diag_easy_5_0',
        seed64: seed64,
        size: const SizeOpt(
          id: 'template5x5',
          description: 'Template 5x5',
          width: 5,
          height: 5,
        ),
        difficulty: const DifficultyRequest(level: 'easy'),
      );

      List<Map<String, Object?>> attemptsLog = <Map<String, Object?>>[];
      try {
        final PuzzleGenerationResult<KakuroBoard> result = generator.generate(
          context,
        );
        attemptsLog =
            (result.snapshot.telemetry['attemptsLog'] as List? ??
                    const <Object?>[])
                .whereType<Map>()
                .map((Map raw) => Map<String, Object?>.from(raw))
                .toList(growable: false);
      } on GenerationFailure catch (failure) {
        attemptsLog =
            (failure.context['attemptsLog'] as List? ?? const <Object?>[])
                .whereType<Map>()
                .map((Map raw) => Map<String, Object?>.from(raw))
                .toList(growable: false);
      }

      final List<Map<String, Object?>> nonUniqueMultipleAttempts = attemptsLog
          .where(
            (Map<String, Object?> attempt) =>
                attempt['rejectReason'] == 'non_unique' &&
                attempt['solverStatus'] == SolverStatus.multiple.name,
          )
          .toList(growable: false);

      expect(nonUniqueMultipleAttempts, isNotEmpty);
      for (final Map<String, Object?> attempt in nonUniqueMultipleAttempts) {
        final int disagreementCellCount =
            (attempt['disagreementCellCount'] as num?)?.toInt() ?? -1;
        final int disagreementRunCount =
            (attempt['disagreementRunCount'] as num?)?.toInt() ?? -1;
        final int disagreementMaxRunLength =
            (attempt['disagreementMaxRunLength'] as num?)?.toInt() ?? -1;

        expect(disagreementCellCount, greaterThanOrEqualTo(1));
        expect(disagreementRunCount, greaterThanOrEqualTo(1));
        expect(disagreementMaxRunLength, greaterThanOrEqualTo(2));

        final String attemptText = attempt.toString().toLowerCase();
        expect(attemptText.contains('values'), isFalse);
        expect(attemptText.contains('solution'), isFalse);
      }
    },
  );

  test(
    '9x9 family selection is deterministic and attempt index changes topology',
    () {
      final int seed64 = Seed.fromString('kakuro_layout_family_selection_seed');

      final KakuroLayout baseline = KakuroGenerator.buildLayoutCandidateForTest(
        seed64: seed64,
        width: 9,
        height: 9,
        difficulty: 'hard',
        attemptIndex: 0,
      );
      final KakuroLayout repeated = KakuroGenerator.buildLayoutCandidateForTest(
        seed64: seed64,
        width: 9,
        height: 9,
        difficulty: 'hard',
        attemptIndex: 0,
      );

      final KakuroLayoutMetrics baselineMetrics = baseline.computeMetrics();
      final KakuroLayoutMetrics repeatedMetrics = repeated.computeMetrics();
      expect(
        baselineMetrics.layoutFamilyId,
        equals(repeatedMetrics.layoutFamilyId),
      );
      expect(baselineMetrics.layoutHash, equals(repeatedMetrics.layoutHash));

      final Set<String> signatures = <String>{};
      for (int attemptIndex = 0; attemptIndex < 8; attemptIndex++) {
        final KakuroLayout layout = KakuroGenerator.buildLayoutCandidateForTest(
          seed64: seed64,
          width: 9,
          height: 9,
          difficulty: 'hard',
          attemptIndex: attemptIndex,
        );
        final KakuroLayoutMetrics metrics = layout.computeMetrics();
        signatures.add('${metrics.layoutFamilyId}:${metrics.layoutHash}');

        expect(
          const <String>{
            'medium-balanced',
            'hard-crossing-heavy',
            'expert-long-run-controlled',
            'easy-9x9-calibration',
            'newspaper_random_v1',
          }.contains(metrics.layoutFamilyId),
          isTrue,
        );
        expect(metrics.unpairedValueCellCount, equals(0));
        expect(metrics.maxRunLength <= 9, isTrue);
        for (final KakuroLayoutEntry entry in layout.entries) {
          expect(entry.length, inInclusiveRange(2, 9));
        }
        for (final int cell in layout.valueCells) {
          expect(layout.acrossEntryForCell[cell] >= 0, isTrue);
          expect(layout.downEntryForCell[cell] >= 0, isTrue);
        }
      }

      expect(signatures.length, greaterThan(1));
    },
  );

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

  test('construction scoring matches known length/sum combinations', () {
    final KakuroLayout template = KakuroLayout.fromRows(const <String>[
      '####',
      '#..#',
      '#..#',
      '####',
    ]);
    final List<int> values = List<int>.filled(16, 0);
    values[5] = 1;
    values[6] = 2;
    values[9] = 3;
    values[10] = 4;

    final Map<String, Object?> metrics =
        KakuroGenerator.scoreConstructionForTest(
          template: template,
          values: values,
          difficulty: 'medium',
        );

    expect(metrics['averageRunCombinationCountMilli'], equals(1750));
    expect(metrics['singleCombinationRunRatioMilli'], equals(500));
    expect(metrics['maxRunAmbiguityMilli'], equals(3000));
    expect(metrics['runLengthWeightedAmbiguityMilli'], equals(1750));
    expect(metrics['intersectionCandidateReductionMilli'], equals(749));
  });

  test('construction scoring supports partial fills', () {
    final KakuroLayout template = KakuroLayout.fromRows(const <String>[
      '####',
      '#..#',
      '#..#',
      '####',
    ]);
    final List<int> partialValues = List<int>.filled(16, 0);
    partialValues[5] = 1;

    final Map<String, Object?> partial =
        KakuroGenerator.scoreConstructionForTest(
          template: template,
          values: partialValues,
          difficulty: 'medium',
        );
    final Map<String, Object?> complete =
        KakuroGenerator.scoreConstructionForTest(
          template: template,
          values: <int>[0, 0, 0, 0, 0, 1, 2, 0, 0, 3, 4, 0, 0, 0, 0, 0],
          difficulty: 'medium',
        );

    final int partialAvg = (partial['averageRunCombinationCountMilli'] as num)
        .toInt();
    final int completeAvg = (complete['averageRunCombinationCountMilli'] as num)
        .toInt();
    final int partialSingle = (partial['singleCombinationRunRatioMilli'] as num)
        .toInt();
    final int completeSingle =
        (complete['singleCombinationRunRatioMilli'] as num).toInt();

    expect(partialAvg, greaterThan(completeAvg));
    expect(partialSingle, lessThan(completeSingle));
  });
}
