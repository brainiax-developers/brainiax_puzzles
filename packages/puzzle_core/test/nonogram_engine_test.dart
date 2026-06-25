import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/nonogram/nonogram_solver.dart';
import 'package:test/test.dart';

void main() {
  group('Nonogram engine pipeline', () {
    final NonogramEngine engine = NonogramEngine();
    final SizeOpt size10 = SizeOpt(
      id: 'mono10x10',
      description: 'Monochrome 10x10',
      width: 10,
      height: 10,
    );
    final SizeOpt size15 = SizeOpt(
      id: 'mono15x15',
      description: 'Monochrome 15x15',
      width: 15,
      height: 15,
    );
    const DifficultyScore difficulty = DifficultyScore(
      value: 0.0,
      level: 'auto',
    );

    test('deterministic generation and uniqueness for sample 10x10 seeds', () {
      const List<String> seeds = <String>[
        'nonogram_seed_0',
        'nonogram_seed_1',
        'nonogram_seed_2',
        'nonogram_seed_3',
        'nonogram_seed_4',
      ];

      for (final String seedStr in seeds) {
        final int seed64 = Seed.fromString(seedStr);
        final GeneratedPuzzle<NonogramBoard> first = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size10,
          difficulty: difficulty,
        );
        final GeneratedPuzzle<NonogramBoard> second = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size10,
          difficulty: difficulty,
        );

        expect(first.state.rowClues, equals(second.state.rowClues));
        expect(first.state.columnClues, equals(second.state.columnClues));

        final NonogramSolver solver = const NonogramSolver();
        final SolverResult<NonogramBoard> solveResult = solver.solve(
          first.state,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
        );

        expect(
          solveResult.hasSolution,
          isTrue,
          reason: 'Puzzle should be solvable',
        );
        expect(solveResult.isUnique, isTrue, reason: 'Puzzle must be unique');

        final NonogramBoard solution = solveResult.solutions.first;
        final ValidationSummary validation = engine.validator.validateSolution(
          first.state,
          solution,
        );
        expect(validation.isValid, isTrue, reason: validation.issues.join(','));
        expect(engine.isSolved(solution), isTrue);
      }
    });

    test('property sample of seeds remain deterministic for 15x15 puzzles', () {
      for (int i = 0; i < 12; i++) {
        final String seedStr = 'nonogram_property_$i';
        final int seed64 = Seed.fromString(seedStr);
        final GeneratedPuzzle<NonogramBoard> generated = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size15,
          difficulty: difficulty,
        );

        final NonogramSolver solver = const NonogramSolver();
        final SolverResult<NonogramBoard> solveResult = solver.solve(
          generated.state,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
        );

        expect(solveResult.solutions.length, equals(1));

        final GeneratedPuzzle<NonogramBoard> regenerated = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size15,
          difficulty: difficulty,
        );
        expect(regenerated.state.rowClues, equals(generated.state.rowClues));
        expect(
          regenerated.state.columnClues,
          equals(generated.state.columnClues),
        );
      }
    });

    test('difficulty scoring is deterministic for repeated generation', () {
      const List<String> seeds = <String>[
        'nonogram_score_easy',
        'nonogram_score_medium',
        'nonogram_score_hard',
      ];

      for (final String seedStr in seeds) {
        final int seed64 = Seed.fromString(seedStr);
        final GeneratedPuzzle<NonogramBoard> first = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size10,
          difficulty: difficulty,
        );
        final GeneratedPuzzle<NonogramBoard> second = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size10,
          difficulty: difficulty,
        );

        final DifficultyTelemetry firstDifficulty = first.telemetry!.difficulty;
        final DifficultyTelemetry secondDifficulty =
            second.telemetry!.difficulty;

        expect(firstDifficulty.rawScore, equals(secondDifficulty.rawScore));
        expect(firstDifficulty.bucket, equals(secondDifficulty.bucket));
        expect(firstDifficulty.metrics, equals(secondDifficulty.metrics));
        expect(
          firstDifficulty.metrics,
          containsPair('logicCompletion', isA<num>()),
        );
        expect(
          firstDifficulty.metrics,
          containsPair('propagationRounds', isA<num>()),
        );
        expect(
          firstDifficulty.metrics,
          containsPair('visitedNodes', isA<num>()),
        );
        expect(firstDifficulty.metrics, containsPair('maxDepth', isA<num>()));
        expect(
          firstDifficulty.metrics,
          containsPair('branchCount', isA<num>()),
        );
        expect(
          firstDifficulty.metrics,
          containsPair('contradictionCount', isA<num>()),
        );
        expect(
          firstDifficulty.metrics,
          containsPair('averageCluesPerLine', isA<num>()),
        );
        expect(
          firstDifficulty.metrics,
          containsPair('checkerboardAlternation', isA<num>()),
        );
      }
    });

    test('fixed seeds separate easy medium and hard difficulty buckets', () {
      final GeneratedPuzzle<NonogramBoard> easyPuzzle = engine.generate(
        seedStr: 'calibrate_easy_0',
        seed64: Seed.fromString('calibrate_easy_0'),
        size: size10,
        difficulty: const DifficultyScore(value: 0.0, level: 'easy'),
      );
      final GeneratedPuzzle<NonogramBoard> mediumPuzzle = engine.generate(
        seedStr: 'calibrate_medium_2',
        seed64: Seed.fromString('calibrate_medium_2'),
        size: size10,
        difficulty: const DifficultyScore(value: 0.0, level: 'medium'),
      );
      final GeneratedPuzzle<NonogramBoard> hardPuzzle = engine.generate(
        seedStr: 'calibrate_hard_2',
        seed64: Seed.fromString('calibrate_hard_2'),
        size: size10,
        difficulty: const DifficultyScore(value: 0.0, level: 'hard'),
      );

      final DifficultyTelemetry easy = easyPuzzle.telemetry!.difficulty;
      final DifficultyTelemetry medium = mediumPuzzle.telemetry!.difficulty;
      final DifficultyTelemetry hard = hardPuzzle.telemetry!.difficulty;

      expect(easy.bucket, equals('easy'));
      expect(medium.bucket, equals('medium'));
      expect(hard.bucket, equals('hard'));
      expect(medium.rawScore - easy.rawScore, greaterThan(10.0));
      expect(hard.rawScore - medium.rawScore, greaterThan(25.0));
      expect(
        easy.metrics['averageCluesPerLine'],
        isNot(equals(hard.metrics['averageCluesPerLine'])),
      );
      expect(easy.metrics['rawScore'], equals(easy.rawScore));
    });

    test('fixed seeds emit bounded bitmap profile telemetry', () {
      final GeneratedPuzzle<NonogramBoard> easyPuzzle = engine.generate(
        seedStr: 'calibrate_easy_0',
        seed64: Seed.fromString('calibrate_easy_0'),
        size: size10,
        difficulty: const DifficultyScore(value: 0.0, level: 'easy'),
      );
      final GeneratedPuzzle<NonogramBoard> mediumPuzzle = engine.generate(
        seedStr: 'calibrate_medium_2',
        seed64: Seed.fromString('calibrate_medium_2'),
        size: size10,
        difficulty: const DifficultyScore(value: 0.0, level: 'medium'),
      );
      final GeneratedPuzzle<NonogramBoard> hardPuzzle = engine.generate(
        seedStr: 'calibrate_hard_2',
        seed64: Seed.fromString('calibrate_hard_2'),
        size: size10,
        difficulty: const DifficultyScore(value: 0.0, level: 'hard'),
      );

      final Map<String, Object?> easyGenerator =
          easyPuzzle.telemetry!.extras['generator']! as Map<String, Object?>;
      final Map<String, Object?> mediumGenerator =
          mediumPuzzle.telemetry!.extras['generator']! as Map<String, Object?>;
      final Map<String, Object?> hardGenerator =
          hardPuzzle.telemetry!.extras['generator']! as Map<String, Object?>;

      for (final Map<String, Object?> telemetry in <Map<String, Object?>>[
        easyGenerator,
        mediumGenerator,
        hardGenerator,
      ]) {
        expect(telemetry['candidateDensity'], isA<num>());
        expect(telemetry['fragmentation'], isA<num>());
        expect(telemetry['visualScore'], isA<num>());
        expect(telemetry['rejectionReason'], equals('accepted'));
        expect(telemetry['attempts'], lessThanOrEqualTo(64));
      }

      expect(easyGenerator['profile'], equals('easy'));
      expect(mediumGenerator['profile'], equals('medium'));
      expect(hardGenerator['profile'], equals('hard'));
      expect(
        easyGenerator['fragmentation']! as num,
        lessThan(mediumGenerator['fragmentation']! as num),
      );
      expect(
        mediumGenerator['fragmentation']! as num,
        lessThan(hardGenerator['fragmentation']! as num),
      );
    });

    test(
      'NonogramBoard serialization round-trips clues and nullable cells',
      () {
        final NonogramBoard board = NonogramBoard(
          width: 3,
          height: 2,
          rowClues: const <List<int>>[
            <int>[1, 1],
            <int>[2],
          ],
          columnClues: const <List<int>>[
            <int>[1],
            <int>[1],
            <int>[2],
          ],
          cells: const <int?>[1, 0, null, null, 1, 1],
        );

        final Map<String, dynamic> json = board.toJson();
        final NonogramBoard decoded = NonogramBoard.fromJson(json);

        expect(decoded, equals(board));
        expect(decoded.toJson(), equals(json));
      },
    );

    test('GeneratedPuzzle serialization round-trips NonogramBoard state', () {
      final NonogramBoard board = NonogramBoard(
        width: 2,
        height: 2,
        rowClues: const <List<int>>[
          <int>[1],
          <int>[],
        ],
        columnClues: const <List<int>>[
          <int>[1],
          <int>[],
        ],
        cells: const <int?>[1, null, 0, 0],
      );
      final GeneratedPuzzle<NonogramBoard> puzzle =
          GeneratedPuzzle<NonogramBoard>(
            state: board,
            meta: const PuzzleMetadata(
              engineVersion: 'nonogram-test',
              rngId: 'seeded_rng',
              size: SizeOpt(
                id: 'mono2x2',
                description: 'Monochrome 2x2',
                width: 2,
                height: 2,
              ),
              difficulty: DifficultyScore(value: 0.25, level: 'easy'),
              seedStr: 'round_trip_nonogram',
              seed64: 42,
            ),
            telemetry: const GenerationTelemetry(
              difficulty: DifficultyTelemetry(
                rawScore: 12.5,
                bucket: 'easy',
                metrics: <String, double>{'logicCompletion': 1.0},
              ),
              extras: <String, Object?>{
                'generator': <String, Object?>{'profile': 'test'},
              },
            ),
          );

      final Map<String, dynamic> json = puzzle.toJson();
      final GeneratedPuzzle<NonogramBoard> decoded =
          GeneratedPuzzle<NonogramBoard>.fromJson(json, NonogramBoard.fromJson);

      expect(decoded.state, equals(board));
      expect(decoded.meta, equals(puzzle.meta));
      expect(decoded.telemetry, equals(puzzle.telemetry));
      expect(decoded.toJson(), equals(json));
    });
  });
}
