import 'package:puzzle_core/puzzle_core.dart' as core;
import 'package:puzzle_core/src/generators/kakuro/combos.dart';
import 'package:test/test.dart';

bool _containsForbiddenKey(Object? node) {
  const Set<String> forbiddenTokens = <String>{
    'solution',
    'signature',
    'answer',
  };
  const Set<String> forbiddenPairs = <String>{'full values', 'solved values'};

  List<String> tokenize(String key) {
    final String separated = key
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (Match m) => '${m.group(1)} ${m.group(2)}',
        )
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    if (separated.isEmpty) {
      return const <String>[];
    }
    return separated.split(RegExp(r'\s+'));
  }

  if (node is Map) {
    for (final MapEntry<dynamic, dynamic> entry in node.entries) {
      final Object? rawKey = entry.key;
      if (rawKey is String) {
        final List<String> tokens = tokenize(rawKey);
        for (final String token in tokens) {
          if (forbiddenTokens.contains(token)) {
            return true;
          }
        }
        for (int i = 0; i + 1 < tokens.length; i++) {
          final String pair = '${tokens[i]} ${tokens[i + 1]}';
          if (forbiddenPairs.contains(pair)) {
            return true;
          }
        }
      }
      if (_containsForbiddenKey(entry.value)) {
        return true;
      }
    }
  } else if (node is Iterable) {
    for (final Object? value in node) {
      if (_containsForbiddenKey(value)) {
        return true;
      }
    }
  }

  return false;
}

void main() {
  test('combo table exposes canonical masks', () {
    final table = KakuroComboTable.instance;
    final combos = table.combosFor(2, 3);
    expect(combos.length, equals(1));
    // 3 = 1 + 2 -> mask should contain bits for 1 and 2
    expect(combos.first, equals((1 << 1) | (1 << 2)));
  });

  test('on-demand generator produces solvable puzzles', () {
    final generator = core.KakuroPuzzleGenerator();
    core.KakuroPuzzle? puzzle;
    final seeds = <int>[
      12345,
      67890,
      2222,
      9999,
      424242,
      556677,
      314159,
      271828,
      10101,
      20202,
    ];
    for (final seed in seeds) {
      try {
        puzzle = generator.generateSync(
          core.GenerateKakuroRequest(
            width: 9,
            height: 9,
            difficulty: 'easy',
            seed: seed,
            timeBudget: const Duration(seconds: 3),
          ),
        );
        break;
      } catch (_) {
        // try next seed
      }
    }
    expect(puzzle, isNotNull);
    final solver = const core.KakuroSolver(maxSearchDepth: 18);
    final result = solver.solve(
      puzzle!.board,
      core.SolverContext(rng: core.SeededRng(1), maxSolutions: 2),
    );
    expect(result.isUnique, isTrue);
  });

  test('kakuro telemetry and metadata contain no solution-bearing keys', () {
    final generator = core.KakuroPuzzleGenerator();
    core.KakuroPuzzle? puzzle;
    final List<int> seeds = <int>[12345, 67890, 2222, 9999, 424242];
    for (final int seed in seeds) {
      try {
        puzzle = generator.generateSync(
          core.GenerateKakuroRequest(
            width: 9,
            height: 9,
            difficulty: 'easy',
            seed: seed,
            timeBudget: const Duration(seconds: 3),
          ),
        );
        break;
      } catch (_) {
        // try next seed
      }
    }
    expect(puzzle, isNotNull);

    expect(_containsForbiddenKey(puzzle!.telemetry), isFalse);

    final core.GeneratedPuzzle<core.KakuroBoard> generated = core
        .kakuroPuzzleAsGeneratedPuzzle(puzzle);
    expect(_containsForbiddenKey(generated.toJson()), isFalse);
  });

  test('forced failure exits in bounded time with GenerationFailure', () {
    final generator = core.KakuroPuzzleGenerator();
    final Stopwatch watch = Stopwatch()..start();

    expect(
      () => generator.generateSync(
        core.GenerateKakuroRequest(
          width: 9,
          height: 9,
          difficulty: 'easy',
          seed: 12345,
          maxRestarts: 0,
          timeBudget: const Duration(milliseconds: 1),
        ),
      ),
      throwsA(isA<core.GenerationFailure>()),
    );

    watch.stop();
    expect(watch.elapsedMilliseconds, lessThan(500));
  });
}
