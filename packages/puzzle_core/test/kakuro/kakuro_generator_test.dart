import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/generators/generator.dart';
import 'package:puzzle_core/src/generators/kakuro/models.dart';
import 'package:puzzle_core/src/kakuro/kakuro_board.dart';
import 'package:puzzle_core/src/kakuro/kakuro_generator.dart';
import 'package:puzzle_core/src/kakuro/kakuro_solver.dart';
import 'package:puzzle_core/src/kakuro/kakuro_supported_profiles.dart';
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
    expect(telemetry['repairAttemptCount'], isA<int>());
    expect(telemetry['repairOutcome'], isA<String>());
    expect(telemetry['repairReason'], isA<String>());
    expect(telemetry['repairedFromNonUnique'], isA<bool>());
    expect(telemetry['finalLayoutHash'], isA<String>());
    expect(telemetry['runLengthHistogram'], isA<Map>());
    expect(telemetry['averageRunCombinationEstimateMilli'], isA<int>());
    expect(telemetry['runLengthWeightedCombinationEstimateMilli'], isA<int>());
    expect(telemetry['singleCombinationSumRatioEstimateMilli'], isA<int>());
    expect(telemetry['layoutCandidateCount'], isA<int>());
    expect(telemetry['acceptedLayoutCandidateCount'], isA<int>());
    expect(telemetry['rejectedLayoutCandidateCount'], isA<int>());
    expect(telemetry['acceptedLayoutCandidates'], isA<List>());
    expect(telemetry['rejectedLayoutCandidates'], isA<List>());
    expect(
      (telemetry['acceptedLayoutCandidateCount'] as num).toInt(),
      greaterThan(0),
    );
    final List<Object?> acceptedLayoutCandidates =
        telemetry['acceptedLayoutCandidates'] as List<Object?>;
    expect(acceptedLayoutCandidates.first, isA<Map>());
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
    'deterministic local repair is bounded and keeps playable cells empty',
    () {
      const KakuroGenerator generator = KakuroGenerator(
        maxTemplateAttempts: 4,
        maxBacktrackNodes: 220,
      );
      final int seed64 = Seed.fromString('repair_probe_5');
      final GeneratorContext context = GeneratorContext(
        rng: SeededRng(seed64),
        seedStr: 'repair_probe_5',
        seed64: seed64,
        size: const SizeOpt(
          id: 'template5x5',
          description: 'Template 5x5',
          width: 5,
          height: 5,
        ),
        difficulty: const DifficultyRequest(level: 'easy'),
      );

      final PuzzleGenerationResult<KakuroBoard> first = generator.generate(
        context,
      );
      final PuzzleGenerationResult<KakuroBoard> second = generator.generate(
        context,
      );

      final Map<String, Object?> firstTelemetry = Map<String, Object?>.from(
        first.snapshot.telemetry,
      );
      final Map<String, Object?> secondTelemetry = Map<String, Object?>.from(
        second.snapshot.telemetry,
      );

      expect(firstTelemetry['repairedFromNonUnique'], isTrue);
      expect(firstTelemetry['acceptPath'], equals('repaired'));
      expect(firstTelemetry['repairOutcome'], equals('accepted'));
      expect(
        (firstTelemetry['repairAttemptCount'] as num).toInt(),
        greaterThan(0),
      );
      expect(firstTelemetry['finalLayoutHash'], isA<String>());

      expect(
        firstTelemetry['repairAttemptCount'],
        equals(secondTelemetry['repairAttemptCount']),
      );
      expect(
        firstTelemetry['repairOutcome'],
        equals(secondTelemetry['repairOutcome']),
      );
      expect(
        firstTelemetry['repairReason'],
        equals(secondTelemetry['repairReason']),
      );
      expect(
        firstTelemetry['finalLayoutHash'],
        equals(secondTelemetry['finalLayoutHash']),
      );

      final List<Map<String, Object?>> attemptsLog =
          (firstTelemetry['attemptsLog'] as List? ?? const <Object?>[])
              .whereType<Map>()
              .map((Map raw) => Map<String, Object?>.from(raw))
              .toList(growable: false);

      final Map<String, int> repairCounts = <String, int>{};
      for (final Map<String, Object?> attempt in attemptsLog) {
        final String mode = attempt['mode'] as String? ?? '';
        if (!mode.endsWith('_repair')) {
          continue;
        }
        final int pass = (attempt['repairPass'] as num?)?.toInt() ?? -1;
        expect(pass, inInclusiveRange(1, 3));
        final int attemptNumber = (attempt['attempt'] as num?)?.toInt() ?? -1;
        final String key = '$attemptNumber:$mode';
        repairCounts[key] = (repairCounts[key] ?? 0) + 1;
      }
      expect(repairCounts, isNotEmpty);
      for (final int count in repairCounts.values) {
        expect(count, lessThanOrEqualTo(3));
      }

      for (int i = 0; i < first.board.cellCount; i++) {
        if (!first.board.isPlayableIndex(i)) {
          continue;
        }
        expect(first.board.values[i], equals(0));
      }
    },
  );

  test('near-miss repair rejects are surfaced in telemetry', () {
    const KakuroGenerator generator = KakuroGenerator(
      maxTemplateAttempts: 4,
      maxBacktrackNodes: 220,
    );
    final int seed64 = Seed.fromString('repair_probe_2');
    final GeneratorContext context = GeneratorContext(
      rng: SeededRng(seed64),
      seedStr: 'repair_probe_2',
      seed64: seed64,
      size: const SizeOpt(
        id: 'template5x5',
        description: 'Template 5x5',
        width: 5,
        height: 5,
      ),
      difficulty: const DifficultyRequest(level: 'easy'),
    );

    final PuzzleGenerationResult<KakuroBoard> result = generator.generate(
      context,
    );
    final Map<String, Object?> telemetry = Map<String, Object?>.from(
      result.snapshot.telemetry,
    );

    expect(telemetry['repairedFromNonUnique'], isFalse);
    expect((telemetry['repairAttemptCount'] as num).toInt(), greaterThan(0));
    expect((telemetry['repairedRejectCount'] as num).toInt(), greaterThan(0));
    expect(telemetry['acceptPath'], equals('primary'));
    expect(telemetry['repairOutcome'], equals('rejected_before_accept'));

    final List<Map<String, Object?>> attemptsLog =
        (telemetry['attemptsLog'] as List? ?? const <Object?>[])
            .whereType<Map>()
            .map((Map raw) => Map<String, Object?>.from(raw))
            .toList(growable: false);
    final List<Map<String, Object?>> repairRejects = attemptsLog
        .where(
          (Map<String, Object?> attempt) =>
              (attempt['mode'] as String? ?? '').endsWith('_repair') &&
              attempt['repairOutcome'] == 'rejected',
        )
        .toList(growable: false);
    expect(repairRejects, isNotEmpty);
  });

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

  test('layout pre-score rejection stops before solution fill attempts', () {
    const KakuroGenerator generator = KakuroGenerator(
      maxTemplateAttempts: 2,
      layoutPreScorer: _RejectAllLayoutPreScorer(),
    );
    final int seed64 = Seed.fromString('kakuro_layout_gate_only_seed');
    final GeneratorContext context = GeneratorContext(
      rng: SeededRng(seed64),
      seedStr: 'kakuro_layout_gate_only_seed',
      seed64: seed64,
      size: const SizeOpt(
        id: 'template9x9',
        description: 'Template 9x9',
        width: 9,
        height: 9,
      ),
      difficulty: const DifficultyRequest(level: 'medium'),
    );

    try {
      generator.generate(context);
      fail('Expected layout gate to reject every candidate.');
    } on GenerationFailure catch (failure) {
      expect(failure.context['failureReason'], equals('layout_gate_exhausted'));
      expect(failure.context['acceptedLayoutCandidateCount'], equals(0));
      expect(
        (failure.context['rejectedLayoutCandidateCount'] as num).toInt(),
        greaterThan(0),
      );
      expect(failure.context['attemptsLog'], isEmpty);
      final Map<String, Object?> rejectCounters = Map<String, Object?>.from(
        failure.context['rejectCounters'] as Map,
      );
      expect((rejectCounters['layoutGate'] as num).toInt(), greaterThan(0));
      expect(rejectCounters['nullCandidate'], equals(0));
      expect(rejectCounters['nonUnique'], equals(0));
    }
  });

  test('generator rejects unsupported 8x8 size', () {
    const KakuroGenerator generator = KakuroGenerator();
    final int seed64 = Seed.fromString('kakuro_gen_8x8_seed');
    final GeneratorContext context = GeneratorContext(
      rng: SeededRng(seed64),
      seedStr: 'kakuro_gen_8x8_seed',
      seed64: seed64,
      size: const SizeOpt(id: '8x8', description: '8x8', width: 8, height: 8),
      difficulty: const DifficultyRequest(level: 'expert'),
    );

    expect(
      () => generator.generate(context),
      throwsA(
        isA<ArgumentError>().having(
          (ArgumentError error) => error.toString(),
          'error',
          contains(
            'Supported sizes: 11x11, 11x9, 13x11, 5x5, 7x10, 7x9, 8x11, 9x12, 9x9',
          ),
        ),
      ),
    );
  });

  test('layout candidate preserves fixed 7x9 portrait request exactly', () {
    final int seed64 = Seed.fromString('kakuro_rectangular_7x9_seed');
    final KakuroLayout layout = KakuroGenerator.buildLayoutCandidateForTest(
      seed64: seed64,
      width: 7,
      height: 9,
      difficulty: 'easy',
      attemptIndex: 0,
    );

    expect(layout.width, equals(7));
    expect(layout.height, equals(9));
    for (final KakuroLayoutEntry entry in layout.entries) {
      expect(entry.length, inInclusiveRange(2, 9));
    }
  });

  test('difficulty defaults map deterministically to fixed portrait sizes', () {
    expect(KakuroSupportedProfiles.generatorSizeForDifficulty('easy'), '7x9');
    expect(
      KakuroSupportedProfiles.generatorSizeForDifficulty('medium'),
      '7x10',
    );
    expect(KakuroSupportedProfiles.generatorSizeForDifficulty('hard'), '8x11');
    expect(
      KakuroSupportedProfiles.generatorSizeForDifficulty('expert'),
      '9x12',
    );
  });

  test('generator accepts 7x9 and never throws unsupported-size errors', () {
    const KakuroGenerator generator = KakuroGenerator();
    final int seed64 = Seed.fromString('kakuro_rectangular_7x9_seed');
    final GeneratorContext context = GeneratorContext(
      rng: SeededRng(seed64),
      seedStr: 'kakuro_rectangular_7x9_seed',
      seed64: seed64,
      size: const SizeOpt(id: '7x9', description: '7x9', width: 7, height: 9),
      difficulty: const DifficultyRequest(level: 'easy'),
    );

    PuzzleGenerationResult<KakuroBoard>? result;
    Object? failure;
    try {
      result = generator.generate(context);
    } catch (error) {
      failure = error;
    }

    if (result != null) {
      expect(result.board.width, equals(7));
      expect(result.board.height, equals(9));
      return;
    }
    expect(failure, isA<GenerationFailure>());
  });

  test('generator accepts 11x9 and remains deterministic by seed+size', () {
    const KakuroGenerator generator = KakuroGenerator();
    final int seed64 = Seed.fromString('kakuro_rectangular_11x9_seed');

    GeneratorContext buildContext() {
      return GeneratorContext(
        rng: SeededRng(seed64),
        seedStr: 'kakuro_rectangular_11x9_seed',
        seed64: seed64,
        size: const SizeOpt(
          id: '11x9',
          description: '11x9',
          width: 11,
          height: 9,
        ),
        difficulty: const DifficultyRequest(level: 'hard'),
      );
    }

    PuzzleGenerationResult<KakuroBoard>? first;
    PuzzleGenerationResult<KakuroBoard>? second;
    Object? firstFailure;
    Object? secondFailure;

    try {
      first = generator.generate(buildContext());
    } catch (error) {
      firstFailure = error;
    }

    try {
      second = generator.generate(buildContext());
    } catch (error) {
      secondFailure = error;
    }

    if (first != null && second != null) {
      expect(first.board.width, equals(11));
      expect(first.board.height, equals(9));
      expect(second.board.width, equals(11));
      expect(second.board.height, equals(9));
      expect(first.board.toJson(), equals(second.board.toJson()));
      return;
    }

    expect(firstFailure, isA<GenerationFailure>());
    expect(secondFailure, isA<GenerationFailure>());
    final GenerationFailure failA = firstFailure! as GenerationFailure;
    final GenerationFailure failB = secondFailure! as GenerationFailure;
    expect(
      failA.context['failureReason'],
      equals(failB.context['failureReason']),
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

class _RejectAllLayoutPreScorer extends KakuroLayoutPreScorer {
  const _RejectAllLayoutPreScorer();

  @override
  KakuroLayoutPreScoreResult score({
    required KakuroLayout layout,
    required String difficulty,
  }) {
    final KakuroLayoutPreScoreResult base = super.score(
      layout: layout,
      difficulty: difficulty,
    );
    return KakuroLayoutPreScoreResult(
      accepted: false,
      reason: 'test_reject_all',
      scoreMilli: base.scoreMilli,
      metrics: base.metrics,
    );
  }
}
