import 'package:puzzle_core/src/util/grids.dart';
import 'package:puzzle_core/src/util/dsu.dart';
import 'package:puzzle_core/src/util/backtracking.dart';
import 'package:puzzle_core/src/util/nonogram.dart';

import 'package:test/test.dart';

void main() {
  group('Grid utilities', () {
    test('IntGrid stores and retrieves values', () {
      final IntGrid grid = IntGrid(3, 2);
      grid.set(1, 0, 7);
      expect(grid.get(1, 0), equals(7));
      grid[<int>[2, 1]] = 5;
      expect(grid[<int>[2, 1]], equals(5));
    });

    test('BoolGrid toggles values', () {
      final BoolGrid grid = BoolGrid(2, 2, true);
      grid.set(1, 1, false);
      expect(grid.get(1, 1), isFalse);
    });
  });

  test('FixedBitSet tracks candidates', () {
    final FixedBitSet bitset = FixedBitSet(9);
    bitset.add(2);
    bitset.add(5);
    expect(bitset.contains(2), isTrue);
    expect(bitset.contains(5), isTrue);
    expect(bitset.count(), equals(2));
    expect(bitset.isSingle, isFalse);
    bitset.remove(2);
    expect(bitset.isSingle, isTrue);
    expect(bitset.singleIndex(), equals(5));
  });

  test('DisjointSetUnion merges components', () {
    final DisjointSetUnion dsu = DisjointSetUnion(4);
    expect(dsu.union(0, 1), isTrue);
    expect(dsu.union(1, 2), isTrue);
    expect(dsu.connected(0, 2), isTrue);
    expect(dsu.componentSize(0), equals(3));
  });

  test('BacktrackingSolver finds solutions and detects duplicates', () {
    final BacktrackingSolver<int, int> solver = BacktrackingSolver<int, int>(
      variables: <int>[0, 1, 2],
      domainGenerator: (int variable, Map<int, int> assignment) {
        return <int>[1, 2, 3];
      },
      isConsistent: (int variable, int value, Map<int, int> assignment) {
        for (final MapEntry<int, int> entry in assignment.entries) {
          if (entry.key != variable && entry.value == value) {
            return false;
          }
        }
        return true;
      },
      leastConstrainingValue: (int variable, int value, Map<int, int> assignment) {
        return value;
      },
    );

    final BacktrackingResult<int, int> result =
        solver.solve(stopOnSecondSolution: true);
    expect(result.solutions, isNotEmpty);
    expect(result.abortedOnSecondSolution, isTrue);
  });

  test('Nonogram line solver generates placements', () {
    final List<List<int>> placements = NonogramLineSolver.generatePlacements(
      5,
      <int>[2],
    );
    expect(placements.length, equals(4));
    final List<int?> intersection =
        NonogramLineSolver.intersectPlacements(placements);
    expect(intersection.length, equals(5));
  });

  test('Nonogram line solver detects impossible clue lengths', () {
    final List<List<int>> placements = NonogramLineSolver.generatePlacements(
      5,
      <int>[3, 3],
    );
    expect(placements, isEmpty);
  });

  test('Nonogram line solver detects excessive filled cells', () {
    final List<List<int>> placements = NonogramLineSolver.generatePlacements(
      5,
      <int>[2],
      current: <int?>[1, 1, 1, null, null],
    );
    expect(placements, isEmpty);
  });


}
