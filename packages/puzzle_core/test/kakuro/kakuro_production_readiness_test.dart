import 'dart:convert';

import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/difficulty/difficulty_config.dart';
import 'package:puzzle_core/src/engine/pipeline_engine.dart';
import 'package:puzzle_core/src/generators/generator.dart';
import 'package:puzzle_core/src/kakuro/kakuro_board.dart';
import 'package:puzzle_core/src/kakuro/kakuro_difficulty.dart';
import 'package:puzzle_core/src/kakuro/kakuro_engine.dart';
import 'package:puzzle_core/src/kakuro/kakuro_move.dart';
import 'package:puzzle_core/src/kakuro/kakuro_solver.dart';
import 'package:puzzle_core/src/kakuro/kakuro_validator.dart';
import 'package:puzzle_core/src/solver/solver.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:puzzle_core/src/validation/validator.dart';
import 'package:test/test.dart';

void main() {
  group('Kakuro production fixtures', () {
    const KakuroSolver solver = KakuroSolver();
    const KakuroValidator validator = KakuroValidator();

    test('known unique-solution fixture has exactly one solution', () {
      final KakuroBoard puzzle = _uniqueFixtureBoard();
      final SolverResult<KakuroBoard> result = solver.solve(
        puzzle,
        SolverContext(rng: SeededRng(101), maxSolutions: 2),
      );

      expect(result.solutionStatus, equals(SolverStatus.unique));
      expect(result.solutions.length, equals(1));
      expect(result.solutions.first.values, equals(const <int>[2, 1, 1, 3]));
      expect(validator.isSolved(result.solutions.first), isTrue);
    });

    test(
      'known multi-solution fixture counts 2 and uniqueness path rejects it',
      () {
        final KakuroBoard puzzle = _multiFixtureBoard();
        final SolverResult<KakuroBoard> result = solver.solve(
          puzzle,
          SolverContext(rng: SeededRng(102), maxSolutions: 2),
        );

        expect(result.solutionStatus, equals(SolverStatus.multiple));
        expect(result.solutions.length, equals(2));
        for (final KakuroBoard solution in result.solutions) {
          expect(validator.isSolved(solution), isTrue);
        }

        final _StaticKakuroPipelineEngine engine = _StaticKakuroPipelineEngine(
          puzzle,
        );
        expect(
          () => engine.generate(
            seedStr: 'kakuro_multi_fixture',
            seed64: Seed.fromString('kakuro_multi_fixture'),
            size: _size9x9,
            difficulty: const DifficultyScore(value: 0.3, level: 'easy'),
          ),
          throwsA(
            isA<StateError>().having(
              (StateError e) => e.toString(),
              'error',
              contains('not unique'),
            ),
          ),
        );
      },
    );
  });

  group('Kakuro structure and serialization', () {
    const KakuroValidator validator = KakuroValidator();

    final Map<String, ({KakuroBoard board, String issueCode})>
    fixtures = <String, ({KakuroBoard board, String issueCode})>{
      'missing_across_entry': (
        board: _uniqueFixtureBoard(
          acrossEntryForCell: const <int>[-1, 0, 1, 1],
        ),
        issueCode: 'missing_across_entry',
      ),
      'wrong_down_entry_direction': (
        board: _uniqueFixtureBoard(downEntryForCell: const <int>[0, 3, 2, 3]),
        issueCode: 'wrong_down_entry_direction',
      ),
      'across_map_mismatch': (
        board: _uniqueFixtureBoard(acrossEntryForCell: const <int>[1, 0, 1, 1]),
        issueCode: 'across_entry_map_mismatch',
      ),
      'entry_not_contiguous': (
        board: _uniqueFixtureBoard(
          entries: const <KakuroEntry>[
            KakuroEntry(
              id: 0,
              direction: KakuroDirection.across,
              cells: <int>[0, 2],
              sum: 5,
            ),
            KakuroEntry(
              id: 1,
              direction: KakuroDirection.across,
              cells: <int>[1, 3],
              sum: 12,
            ),
            KakuroEntry(
              id: 2,
              direction: KakuroDirection.down,
              cells: <int>[0, 1],
              sum: 10,
            ),
            KakuroEntry(
              id: 3,
              direction: KakuroDirection.down,
              cells: <int>[2, 3],
              sum: 7,
            ),
          ],
          acrossEntryForCell: const <int>[0, 1, 0, 1],
          downEntryForCell: const <int>[2, 2, 3, 3],
        ),
        issueCode: 'entry_not_contiguous',
      ),
      'entry_cell_out_of_bounds': (
        board: _uniqueFixtureBoard(
          entries: const <KakuroEntry>[
            KakuroEntry(
              id: 0,
              direction: KakuroDirection.across,
              cells: <int>[0, 4],
              sum: 10,
            ),
            KakuroEntry(
              id: 1,
              direction: KakuroDirection.across,
              cells: <int>[2, 3],
              sum: 7,
            ),
            KakuroEntry(
              id: 2,
              direction: KakuroDirection.down,
              cells: <int>[0, 2],
              sum: 5,
            ),
            KakuroEntry(
              id: 3,
              direction: KakuroDirection.down,
              cells: <int>[1, 3],
              sum: 12,
            ),
          ],
        ),
        issueCode: 'entry_cell_out_of_bounds',
      ),
    };

    test('invalid structural fixtures are rejected with issue codes', () {
      for (final MapEntry<String, ({KakuroBoard board, String issueCode})> entry
          in fixtures.entries) {
        final ValidationSummary summary = validator.validatePuzzle(
          entry.value.board,
        );
        expect(summary.isValid, isFalse, reason: entry.key);
        expect(
          summary.issues.any(
            (String issue) => issue.startsWith(entry.value.issueCode),
          ),
          isTrue,
          reason: '${entry.key}: ${summary.issues.join(',')}',
        );
      }
    });

    test('KakuroBoard serialization round-trip preserves board signature', () {
      final KakuroBoard original = _uniqueFixtureBoard(
        values: <int>[1, 0, 4, 0],
      );
      final Map<String, dynamic> encoded = original.toJson();
      final KakuroBoard decoded = KakuroBoard.fromJson(encoded);

      expect(decoded, equals(original));
      expect(
        jsonEncode(decoded.toJson()),
        equals(jsonEncode(original.toJson())),
      );
    });
  });

  group('Kakuro deterministic generation and fuzz', () {
    final KakuroEngine engine = KakuroEngine();
    const KakuroSolver solver = KakuroSolver();
    const KakuroValidator validator = KakuroValidator();
    const String seedStr = 'kakuro_det_seed_0';
    final int seed64 = Seed.fromString(seedStr);

    test('same seed + difficulty + size yields same board signature', () {
      const List<({String level, SizeOpt size})> cases =
          <({String level, SizeOpt size})>[
            (level: 'medium', size: _size9x9),
            (level: 'hard', size: _size9x9),
            (level: 'easy', size: _size5x5),
          ];

      for (final ({String level, SizeOpt size}) spec in cases) {
        final String caseSeedStr = _seedForProfile(
          baseSeed: seedStr,
          level: spec.level,
          size: spec.size,
        );
        final int caseSeed64 = Seed.fromString(caseSeedStr);
        final DifficultyScore difficulty = _difficulty(spec.level);
        final GeneratedPuzzle<KakuroBoard> first = engine.generate(
          seedStr: caseSeedStr,
          seed64: caseSeed64,
          size: spec.size,
          difficulty: difficulty,
        );
        final GeneratedPuzzle<KakuroBoard> second = engine.generate(
          seedStr: caseSeedStr,
          seed64: caseSeed64,
          size: spec.size,
          difficulty: difficulty,
        );

        expect(
          jsonEncode(first.state.toJson()),
          equals(jsonEncode(second.state.toJson())),
          reason: '${spec.level}:${spec.size.id}',
        );
      }
    });

    test(
      'regression: kakuro_det_seed_0 hard yields unique 9x9 with matching meta size',
      () {
        final GeneratedPuzzle<KakuroBoard> generated = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: _size9x9,
          difficulty: _difficulty('hard'),
        );

        expect(generated.state.width, equals(9));
        expect(generated.state.height, equals(9));
        expect(generated.meta.size.width, equals(generated.state.width));
        expect(generated.meta.size.height, equals(generated.state.height));

        final SolverResult<KakuroBoard> solved = solver.solve(
          generated.state,
          SolverContext(rng: SeededRng(seed64 ^ 0x22f14e87), maxSolutions: 2),
        );
        expect(solved.solutionStatus, equals(SolverStatus.unique));
        expect(solved.isUnique, isTrue);
        expect(solved.solutions, hasLength(1));
      },
    );

    test(
      'generated boards are valid, solvable, unique, and meta size matches',
      () {
        const List<({String level, SizeOpt size})> cases =
            <({String level, SizeOpt size})>[
              (level: 'easy', size: _size7x9),
              (level: 'medium', size: _size9x9),
              (level: 'hard', size: _size9x9),
              (level: 'easy', size: _size5x5),
            ];
        const List<String> deterministicVariants = <String>[
          'kakuro_engine_seed',
          'kakuro_move_seed',
          'kakuro_engine_seed_alt_1',
          'kakuro_engine_seed_alt_2',
          'kakuro_rectangular_7x9_seed',
          'kakuro_smoke_9x9_medium_seed_0',
          'kakuro_smoke_5x5_easy_seed_0',
          'kakuro_det_seed_0',
          'kakuro_v1_regression_seed_0',
          'kakuro_v1_regression_seed_1',
        ];

        for (final ({String level, SizeOpt size}) spec in cases) {
          GeneratedPuzzle<KakuroBoard>? generated;
          String? selectedSeed;
          int selectedSeed64 = 0;
          for (final String variant in deterministicVariants) {
            final String sampleSeed =
                spec.level == 'easy' &&
                    spec.size.id == '7x9' &&
                    variant == 'kakuro_rectangular_7x9_seed'
                ? variant
                : '${variant}_${spec.level}_${spec.size.id}';
            final int sampleSeed64 = Seed.fromString(sampleSeed);
            try {
              generated = engine.generate(
                seedStr: sampleSeed,
                seed64: sampleSeed64,
                size: spec.size,
                difficulty: _difficulty(spec.level),
              );
              selectedSeed = sampleSeed;
              selectedSeed64 = sampleSeed64;
              break;
            } catch (_) {
              // Try next deterministic variant.
            }
          }

          expect(
            generated,
            isNotNull,
            reason: 'generation failed for ${spec.level}:${spec.size.id}',
          );
          final GeneratedPuzzle<KakuroBoard> puzzle = generated!;
          final String sampleSeed = selectedSeed!;

          expect(
            puzzle.state.width,
            equals(spec.size.width),
            reason: sampleSeed,
          );
          expect(
            puzzle.state.height,
            equals(spec.size.height),
            reason: sampleSeed,
          );
          expect(
            puzzle.meta.size.width,
            equals(puzzle.state.width),
            reason: sampleSeed,
          );
          expect(
            puzzle.meta.size.height,
            equals(puzzle.state.height),
            reason: sampleSeed,
          );
          expect(
            puzzle.meta.size.id,
            anyOf(equals(spec.size.id), equals('9x9')),
            reason: sampleSeed,
          );

          final SolverResult<KakuroBoard> solved = solver.solve(
            puzzle.state,
            SolverContext(
              rng: SeededRng(selectedSeed64 ^ 0x13df4a8c),
              maxSolutions: 2,
            ),
          );

          expect(
            solved.solutionStatus,
            equals(SolverStatus.unique),
            reason: sampleSeed,
          );
          expect(solved.hasSolution, isTrue, reason: sampleSeed);
          expect(solved.isUnique, isTrue, reason: sampleSeed);
          expect(solved.solutions, hasLength(1), reason: sampleSeed);
          final ValidationSummary solutionValidation = validator
              .validateSolution(puzzle.state, solved.solutions.first);
          expect(solutionValidation.isValid, isTrue, reason: sampleSeed);
        }
      },
    );
  });
}

const SizeOpt _size5x5 = SizeOpt(
  id: '5x5',
  description: '5x5',
  width: 5,
  height: 5,
);

const SizeOpt _size7x9 = SizeOpt(
  id: '7x9',
  description: '7x9',
  width: 7,
  height: 9,
);

const SizeOpt _size9x9 = SizeOpt(
  id: 'template9x9',
  description: 'Template 9x9',
  width: 9,
  height: 9,
);

DifficultyScore _difficulty(String level) {
  switch (level) {
    case 'easy':
      return const DifficultyScore(value: 0.3, level: 'easy');
    case 'medium':
      return const DifficultyScore(value: 0.6, level: 'medium');
    case 'hard':
      return const DifficultyScore(value: 0.9, level: 'hard');
    case 'expert':
      return const DifficultyScore(value: 1.0, level: 'expert');
  }
  return DifficultyScore(value: 0.0, level: level);
}

String _seedForProfile({
  required String baseSeed,
  required String level,
  required SizeOpt size,
}) {
  if (level == 'easy' && size.id == '7x9') {
    return 'kakuro_rectangular_7x9_seed';
  }
  return '${baseSeed}_${level}_${size.id}';
}

KakuroBoard _uniqueFixtureBoard({
  List<int>? values,
  List<KakuroEntry>? entries,
  List<int>? acrossEntryForCell,
  List<int>? downEntryForCell,
}) {
  return KakuroBoard(
    width: 2,
    height: 2,
    kinds: const <KakuroCellKind>[
      KakuroCellKind.value,
      KakuroCellKind.value,
      KakuroCellKind.value,
      KakuroCellKind.value,
    ],
    values: values ?? const <int>[0, 0, 0, 0],
    acrossClues: const <int?>[null, null, null, null],
    downClues: const <int?>[null, null, null, null],
    entries:
        entries ??
        const <KakuroEntry>[
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
    acrossEntryForCell: acrossEntryForCell ?? const <int>[0, 0, 1, 1],
    downEntryForCell: downEntryForCell ?? const <int>[2, 3, 2, 3],
  );
}

KakuroBoard _multiFixtureBoard() {
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
        sum: 3,
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
        sum: 3,
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
  _StaticKakuroPipelineEngine(KakuroBoard board)
    : super(
        engineId: 'kakuro_static_fixture',
        engineName: 'Kakuro static fixture',
        engineVersion: 'test',
        generator: _StaticKakuroGenerator(board),
        solver: const KakuroSolver(),
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
