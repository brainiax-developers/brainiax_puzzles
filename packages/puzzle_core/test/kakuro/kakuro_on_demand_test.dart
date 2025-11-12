import 'package:puzzle_core/puzzle_core.dart' as core;
import 'package:puzzle_core/src/generators/kakuro/combos.dart';
import 'package:test/test.dart';

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
      core.SolverContext(
        rng: core.SeededRng(1),
        maxSolutions: 2,
      ),
    );
    expect(result.isUnique, isTrue);
  });
}
