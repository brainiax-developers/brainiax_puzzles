import '../solver/solver.dart';
import '../util/seeded_rng.dart';
import 'killer_queens_board.dart';

class KillerQueensSolver extends PuzzleSolver<KillerQueensBoard> {
  const KillerQueensSolver();

  @override
  SolverResult<KillerQueensBoard> solve(
    KillerQueensBoard board,
    SolverContext context,
  ) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final _KillerQueensSearch search = _KillerQueensSearch(board, context);
    final List<KillerQueensBoard> solutions = search.run();
    stopwatch.stop();
    return SolverResult<KillerQueensBoard>(
      solutions: solutions,
      elapsed: stopwatch.elapsed,
      telemetry: search.telemetry,
    );
  }
}

class _KillerQueensSearch {
  _KillerQueensSearch(this.board, this.context)
    : size = board.size,
      cageByCell = board.cageByCell,
      rng = context.rng,
      maxSolutions = context.maxSolutions;

  final KillerQueensBoard board;
  final SolverContext context;
  final int size;
  final List<int> cageByCell;
  final SeededRng rng;
  final int maxSolutions;

  final List<KillerQueensBoard> _solutions = <KillerQueensBoard>[];
  final List<int> _queenPositions = <int>[];
  final List<bool> _columnUsed = <bool>[];
  late final List<int> _cageUsage;
  late final List<int> _rowAssignment;
  late final List<bool> _rowIsGiven;

  int _nodes = 0;
  int _branches = 0;
  int _backtracks = 0;
  bool _inconsistent = false;

  Map<String, Object?> get telemetry => <String, Object?>{
    'nodes': _nodes,
    'branches': _branches,
    'backtracks': _backtracks,
    'solutions': _solutions.length,
    'inconsistent': _inconsistent,
  };

  List<KillerQueensBoard> run() {
    _columnUsed.addAll(List<bool>.filled(size, false));
    _cageUsage = List<int>.filled(board.cages.length, 0);
    _rowAssignment = List<int>.filled(size, -1);
    _rowIsGiven = List<bool>.filled(size, false);

    for (int index = 0; index < board.cellCount; index++) {
      if (board.cells[index] != 1) {
        continue;
      }
      if (!_place(index, given: true)) {
        _inconsistent = true;
        return const <KillerQueensBoard>[];
      }
    }

    _search(0);
    return List<KillerQueensBoard>.unmodifiable(_solutions);
  }

  void _search(int row) {
    if (_solutions.length >= maxSolutions) {
      return;
    }

    int nextRow = row;
    while (nextRow < size && _rowIsGiven[nextRow]) {
      nextRow += 1;
    }
    if (nextRow >= size) {
      _recordSolution();
      return;
    }

    _nodes += 1;
    final List<int> candidates = <int>[];
    for (int col = 0; col < size; col++) {
      final int index = nextRow * size + col;
      if (_columnUsed[col]) {
        continue;
      }
      final int cageIndex = cageByCell[index];
      if (cageIndex != -1 && _cageUsage[cageIndex] >= 1) {
        continue;
      }
      if (_conflicts(index)) {
        continue;
      }
      candidates.add(col);
    }

    if (candidates.isEmpty) {
      _backtracks += 1;
      return;
    }

    rng.shuffle(candidates);

    for (final int col in candidates) {
      if (_solutions.length >= maxSolutions) {
        break;
      }
      final int index = nextRow * size + col;
      _branches += 1;
      if (!_place(index, given: false)) {
        continue;
      }
      _search(nextRow + 1);
      _remove(index);
    }
  }

  bool _place(int index, {required bool given}) {
    final int row = index ~/ size;
    final int col = index % size;
    if (_rowAssignment[row] != -1) {
      if (_rowAssignment[row] == col) {
        if (given) {
          return true;
        }
        return false;
      }
      return false;
    }
    if (_columnUsed[col]) {
      return false;
    }
    if (_conflicts(index)) {
      return false;
    }
    final int cageIndex = cageByCell[index];
    if (cageIndex != -1 && _cageUsage[cageIndex] >= 1) {
      return false;
    }

    _rowAssignment[row] = col;
    _columnUsed[col] = true;
    if (cageIndex != -1) {
      _cageUsage[cageIndex] += 1;
    }
    _queenPositions.add(index);
    if (given) {
      _rowIsGiven[row] = true;
    }
    return true;
  }

  void _remove(int index) {
    final int row = index ~/ size;
    final int col = index % size;
    if (_rowIsGiven[row]) {
      return; // Never remove givens
    }
    _queenPositions.remove(index);
    _rowAssignment[row] = -1;
    _columnUsed[col] = false;
    final int cageIndex = cageByCell[index];
    if (cageIndex != -1) {
      _cageUsage[cageIndex] -= 1;
    }
  }

  bool _conflicts(int index) {
    final int row = index ~/ size;
    final int col = index % size;
    for (final int queen in _queenPositions) {
      final int qr = queen ~/ size;
      final int qc = queen % size;
      if (qr == row || qc == col) {
        return true;
      }
      final int dr = (qr - row).abs();
      final int dc = (qc - col).abs();
      if (dr <= 1 && dc <= 1) {
        return true;
      }
    }
    return false;
  }

  void _recordSolution() {
    if (_queenPositions.length != size) {
      return;
    }
    final List<int> cells = List<int>.filled(board.cellCount, 0);
    for (final int index in _queenPositions) {
      cells[index] = 1;
    }
    final KillerQueensBoard solution = KillerQueensBoard(
      size: board.size,
      cells: cells,
      fixed: board.fixed,
      cages: board.cages,
    );
    _solutions.add(solution);
  }
}
