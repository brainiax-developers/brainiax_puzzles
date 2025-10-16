import '../solver/solver.dart';
import '../util/seeded_rng.dart';
import 'futoshiki_board.dart';

class FutoshikiSolver extends PuzzleSolver<FutoshikiBoard> {
  const FutoshikiSolver();

  @override
  SolverResult<FutoshikiBoard> solve(FutoshikiBoard board, SolverContext context) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final _FutoshikiSearch search =
        _FutoshikiSearch(board, context.rng, context.maxSolutions);
    search.run();
    stopwatch.stop();
    return SolverResult<FutoshikiBoard>(
      solutions: search.solutions,
      elapsed: stopwatch.elapsed,
      telemetry: search.telemetry,
    );
  }
}

class _FutoshikiSearch {
  _FutoshikiSearch(this.board, this.rng, this.maxSolutions)
      : size = board.size,
        cellCount = board.cellCount,
        fullMask = (1 << board.size) - 1,
        values = List<int>.from(board.cells),
        domains = List<int>.filled(board.cellCount, 0),
        greaterThan = List<List<int>>.generate(
          board.cellCount,
          (_) => <int>[],
          growable: false,
        ),
        lessThan = List<List<int>>.generate(
          board.cellCount,
          (_) => <int>[],
          growable: false,
        ),
        rowCells = List<List<int>>.generate(
          board.size,
          (int row) =>
              List<int>.generate(board.size, (int col) => row * board.size + col),
          growable: false,
        ),
        columnCells = List<List<int>>.generate(
          board.size,
          (int col) =>
              List<int>.generate(board.size, (int row) => row * board.size + col),
          growable: false,
        ) {
    for (int i = 0; i < cellCount; i++) {
      final int value = values[i];
      if (value > 0) {
        domains[i] = 1 << (value - 1);
      } else {
        domains[i] = fullMask;
      }
    }
    for (final FutoshikiInequality inequality in board.inequalities) {
      greaterThan[inequality.lesser].add(inequality.greater);
      lessThan[inequality.greater].add(inequality.lesser);
    }
    _topologicalOrder = _buildTopologicalOrder();
  }

  final FutoshikiBoard board;
  final SeededRng rng;
  final int maxSolutions;
  final int size;
  final int cellCount;
  final int fullMask;

  final List<int> values;
  final List<int> domains;

  final List<List<int>> greaterThan;
  final List<List<int>> lessThan;
  final List<List<int>> rowCells;
  final List<List<int>> columnCells;

  late final List<int> _topologicalOrder;

  final List<FutoshikiBoard> solutions = <FutoshikiBoard>[];

  int tightenings = 0;
  int? firstGuessDepth;
  int branchesExplored = 0;

  Map<String, Object?> get telemetry => <String, Object?>{
        'tightenings': tightenings,
        'firstGuessDepth': firstGuessDepth ?? 0,
        'branches': branchesExplored,
      };

  void run() {
    _search(0);
  }

  void _search(int depth) {
    if (solutions.length >= maxSolutions) {
      return;
    }

    if (!_propagate()) {
      return;
    }

    if (_isSolved()) {
      final FutoshikiBoard solved = FutoshikiBoard(
        size: size,
        cells: List<int>.from(values),
        fixed: board.fixed,
        inequalities: board.inequalities,
      );
      solutions.add(solved);
      return;
    }

    final int index = _selectMrvIndex();
    if (index < 0) {
      return;
    }

    final int domainMask = domains[index];
    final List<int> options = _valuesFromMask(domainMask);
    if (options.isEmpty) {
      return;
    }

    firstGuessDepth ??= depth;
    branchesExplored++;

    final List<int> baseValues = List<int>.from(values);
    final List<int> baseDomains = List<int>.from(domains);

    // Use deterministic ordering but break ties with RNG for reproducibility.
    if (options.length > 1) {
      // Shuffle copy using rng without modifying original list order beyond determinism.
      final List<int> shuffled = List<int>.from(options);
      rng.shuffle(shuffled);
      options
        ..clear()
        ..addAll(shuffled);
    }

    for (final int value in options) {
      _restore(baseValues, baseDomains);
      final int result = _assignValue(index, value);
      if (result == _contradiction) {
        continue;
      }
      _search(depth + 1);
      if (solutions.length >= maxSolutions) {
        return;
      }
    }

    _restore(baseValues, baseDomains);
  }

  bool _isSolved() => values.every((int value) => value != 0);

  bool _propagate() {
    bool progress = true;
    while (progress) {
      progress = false;

      // Apply assigned values to peers.
      for (int index = 0; index < cellCount; index++) {
        final int value = values[index];
        if (value == 0) {
          continue;
        }
        final int mask = 1 << (value - 1);
        int state = _restrictDomain(index, mask);
        if (state == _contradiction) {
          return false;
        }
        if (state == _changed) {
          progress = true;
        }
        for (final int peer in rowCells[index ~/ size]) {
          if (peer == index) {
            continue;
          }
          state = _removeValue(peer, mask);
          if (state == _contradiction) {
            return false;
          }
          if (state == _changed) {
            progress = true;
          }
        }
        for (final int peer in columnCells[index % size]) {
          if (peer == index) {
            continue;
          }
          state = _removeValue(peer, mask);
          if (state == _contradiction) {
            return false;
          }
          if (state == _changed) {
            progress = true;
          }
        }
      }

      // Latin row/column singles.
      for (final List<int> row in rowCells) {
        final int state = _applyLatinUnit(row);
        if (state == _contradiction) {
          return false;
        }
        if (state == _changed) {
          progress = true;
        }
      }
      for (final List<int> column in columnCells) {
        final int state = _applyLatinUnit(column);
        if (state == _contradiction) {
          return false;
        }
        if (state == _changed) {
          progress = true;
        }
      }

      // Inequality propagation.
      for (final FutoshikiInequality inequality in board.inequalities) {
        final int state = _applyInequality(inequality);
        if (state == _contradiction) {
          return false;
        }
        if (state == _changed) {
          progress = true;
        }
      }

      // Monotone chain tightening via topological bounds.
      final int state = _applyMonotoneBounds();
      if (state == _contradiction) {
        return false;
      }
      if (state == _changed) {
        progress = true;
      }
    }

    for (final int mask in domains) {
      if (mask == 0) {
        return false;
      }
    }
    return true;
  }

  int _selectMrvIndex() {
    int bestIndex = -1;
    int bestDomainSize = 0x7fffffff;
    final List<int> ties = <int>[];
    for (int index = 0; index < cellCount; index++) {
      if (values[index] != 0) {
        continue;
      }
      final int domainMask = domains[index];
      final int size = _countBits(domainMask);
      if (size == 0) {
        return index;
      }
      if (size < bestDomainSize) {
        bestDomainSize = size;
        bestIndex = index;
        ties
          ..clear()
          ..add(index);
      } else if (size == bestDomainSize) {
        ties.add(index);
      }
    }
    if (ties.length > 1) {
      return ties[rng.nextIntInRange(ties.length)];
    }
    return bestIndex;
  }

  int _applyLatinUnit(List<int> indices) {
    int status = _noChange;
    final List<int> counts = List<int>.filled(size, 0);
    final List<int> lastIndex = List<int>.filled(size, -1);
    for (final int index in indices) {
      final int mask = domains[index];
      if (mask == 0) {
        return _contradiction;
      }
      for (int value = 1; value <= size; value++) {
        final int bit = 1 << (value - 1);
        if ((mask & bit) != 0) {
          counts[value - 1]++;
          lastIndex[value - 1] = index;
        }
      }
    }
    for (int value = 1; value <= size; value++) {
      final int occurrences = counts[value - 1];
      if (occurrences == 0) {
        return _contradiction;
      }
      if (occurrences == 1) {
        final int targetIndex = lastIndex[value - 1];
        final int result = _assignValue(targetIndex, value);
        if (result == _contradiction) {
          return _contradiction;
        }
        if (result == _changed) {
          status = _changed;
        }
      }
    }
    return status;
  }

  int _applyInequality(FutoshikiInequality inequality) {
    final int lesser = inequality.lesser;
    final int greater = inequality.greater;
    final int domainA = domains[lesser];
    final int domainB = domains[greater];
    if (domainA == 0 || domainB == 0) {
      return _contradiction;
    }

    final int allowedA = _supportedLessValues(domainA, domainB);
    final int allowedB = _supportedGreaterValues(domainA, domainB);
    if (allowedA == 0 || allowedB == 0) {
      return _contradiction;
    }

    int status = _noChange;
    int state = _restrictDomain(lesser, allowedA);
    if (state == _contradiction) {
      return _contradiction;
    }
    if (state == _changed) {
      status = _changed;
    }
    state = _restrictDomain(greater, allowedB);
    if (state == _contradiction) {
      return _contradiction;
    }
    if (state == _changed) {
      status = _changed;
    }
    return status;
  }

  int _applyMonotoneBounds() {
    if (_topologicalOrder.isEmpty) {
      return _noChange;
    }

    int status = _noChange;
    final List<int> lowerRank = List<int>.filled(cellCount, 1);
    for (final int node in _topologicalOrder) {
      int best = 0;
      for (final int parent in lessThan[node]) {
        best = best < lowerRank[parent] ? lowerRank[parent] : best;
      }
      lowerRank[node] = best + 1;
    }

    final List<int> upperRank = List<int>.filled(cellCount, 1);
    for (int i = _topologicalOrder.length - 1; i >= 0; i--) {
      final int node = _topologicalOrder[i];
      int best = 0;
      for (final int child in greaterThan[node]) {
        best = best < upperRank[child] ? upperRank[child] : best;
      }
      upperRank[node] = best + 1;
    }

    for (int index = 0; index < cellCount; index++) {
      final int minValue = lowerRank[index];
      final int maxValue = size - (upperRank[index] - 1);
      if (maxValue < minValue) {
        return _contradiction;
      }
      final int mask = _rangeMask(minValue, maxValue);
      final int result = _restrictDomain(index, mask);
      if (result == _contradiction) {
        return _contradiction;
      }
      if (result == _changed) {
        status = _changed;
      }
    }

    return status;
  }

  int _restrictDomain(int index, int mask) {
    final int current = domains[index];
    final int next = current & mask;
    if (next == 0) {
      return _contradiction;
    }
    bool changed = false;
    if (next != current) {
      domains[index] = next;
      tightenings++;
      changed = true;
    }
    if (_isSingleton(next)) {
      final int value = _valueFromMask(next);
      final int existing = values[index];
      if (existing != 0 && existing != value) {
        return _contradiction;
      }
      if (existing != value) {
        values[index] = value;
        changed = true;
      }
    }
    return changed ? _changed : _noChange;
  }

  int _assignValue(int index, int value) {
    final int existing = values[index];
    if (existing != 0 && existing != value) {
      return _contradiction;
    }
    values[index] = value;
    final int result = _restrictDomain(index, 1 << (value - 1));
    if (result == _contradiction) {
      return _contradiction;
    }
    if (existing != value) {
      return _changed;
    }
    return result;
  }

  int _removeValue(int index, int mask) {
    final int current = domains[index];
    if ((current & mask) == 0) {
      return _noChange;
    }
    final int next = current & ~mask;
    if (next == 0) {
      return _contradiction;
    }
    domains[index] = next;
    tightenings++;
    if (_isSingleton(next)) {
      final int value = _valueFromMask(next);
      final int existing = values[index];
      if (existing != 0 && existing != value) {
        return _contradiction;
      }
      values[index] = value;
    }
    return _changed;
  }

  List<int> _valuesFromMask(int mask) {
    final List<int> values = <int>[];
    for (int value = 1; value <= size; value++) {
      final int bit = 1 << (value - 1);
      if ((mask & bit) != 0) {
        values.add(value);
      }
    }
    return values;
  }

  int _supportedLessValues(int domainA, int domainB) {
    int allowed = 0;
    int seenGreater = 0;
    for (int value = size; value >= 1; value--) {
      final int bit = 1 << (value - 1);
      if ((domainA & bit) != 0 && seenGreater != 0) {
        allowed |= bit;
      }
      if ((domainB & bit) != 0) {
        seenGreater |= bit;
      }
    }
    return allowed;
  }

  int _supportedGreaterValues(int domainA, int domainB) {
    int allowed = 0;
    int seenLesser = 0;
    for (int value = 1; value <= size; value++) {
      final int bit = 1 << (value - 1);
      if ((domainB & bit) != 0 && seenLesser != 0) {
        allowed |= bit;
      }
      if ((domainA & bit) != 0) {
        seenLesser |= bit;
      }
    }
    return allowed;
  }

  int _rangeMask(int minValue, int maxValue) {
    if (maxValue >= size) {
      maxValue = size;
    }
    if (minValue <= 1) {
      minValue = 1;
    }
    if (maxValue < minValue) {
      return 0;
    }
    final int upper = (1 << maxValue) - 1;
    final int lower = minValue <= 1 ? 0 : (1 << (minValue - 1)) - 1;
    return upper & ~lower;
  }

  bool _isSingleton(int mask) => mask != 0 && (mask & (mask - 1)) == 0;

  int _valueFromMask(int mask) {
    for (int value = 1; value <= size; value++) {
      if (mask == (1 << (value - 1))) {
        return value;
      }
    }
    throw StateError('Invalid singleton mask: $mask');
  }

  int _countBits(int mask) {
    int count = 0;
    int value = mask;
    while (value != 0) {
      value &= value - 1;
      count++;
    }
    return count;
  }

  void _restore(List<int> baseValues, List<int> baseDomains) {
    for (int i = 0; i < cellCount; i++) {
      values[i] = baseValues[i];
      domains[i] = baseDomains[i];
    }
  }

  List<int> _buildTopologicalOrder() {
    final List<int> order = <int>[];
    final List<int> state = List<int>.filled(cellCount, 0);
    bool hasCycle = false;

    void dfs(int node) {
      if (hasCycle) {
        return;
      }
      if (state[node] == 1) {
        hasCycle = true;
        return;
      }
      if (state[node] == 2) {
        return;
      }
      state[node] = 1;
      for (final int next in greaterThan[node]) {
        dfs(next);
        if (hasCycle) {
          return;
        }
      }
      state[node] = 2;
      order.add(node);
    }

    for (int node = 0; node < cellCount; node++) {
      if (state[node] == 0) {
        dfs(node);
      }
    }

    if (hasCycle) {
      throw StateError('Futoshiki inequalities contain a cycle');
    }

    return order.reversed.toList(growable: false);
  }
}

const int _contradiction = 0;
const int _noChange = 1;
const int _changed = 2;
