import 'dart:math';

import '../../solver/solver.dart';
import '../../util/kakuro_dictionary.dart';
import '../../kakuro/kakuro_board.dart';

const int _allDigitsMask = 0x3fe; // bits 1..9

int _bitFor(int digit) => 1 << digit;

int _countBits(int mask) {
  int value = mask;
  int count = 0;
  while (value != 0) {
    value &= value - 1;
    count++;
  }
  return count;
}

int _singleDigit(int mask) {
  for (int digit = 1; digit <= 9; digit++) {
    if ((mask & _bitFor(digit)) != 0) {
      return digit;
    }
  }
  return 0;
}

List<int> _digitsFromMask(int mask) {
  final List<int> digits = <int>[];
  for (int digit = 1; digit <= 9; digit++) {
    if ((mask & _bitFor(digit)) != 0) {
      digits.add(digit);
    }
  }
  return digits;
}

List<int> _sortedIntList(Iterable<int> values) {
  final List<int> sorted = values.toList(growable: false)..sort();
  return sorted;
}

Map<String, Object?>? _buildDisagreementSummary({
  required KakuroBoard board,
  required int maxSolutions,
  required List<List<int>> solutions,
}) {
  if (maxSolutions < 2 || solutions.length < 2) {
    return null;
  }
  final List<int> first = solutions[0];
  final List<int> second = solutions[1];
  if (first.length != board.cellCount || second.length != board.cellCount) {
    return null;
  }

  final Set<int> acrossRunIds = <int>{};
  final Set<int> downRunIds = <int>{};

  int disagreementCellCount = 0;
  int minRow = board.height;
  int maxRow = -1;
  int minCol = board.width;
  int maxCol = -1;

  for (int i = 0; i < board.cellCount; i++) {
    if (!board.isPlayableIndex(i)) {
      continue;
    }
    if (first[i] == second[i]) {
      continue;
    }

    disagreementCellCount++;
    final int row = i ~/ board.width;
    final int col = i % board.width;
    if (row < minRow) {
      minRow = row;
    }
    if (row > maxRow) {
      maxRow = row;
    }
    if (col < minCol) {
      minCol = col;
    }
    if (col > maxCol) {
      maxCol = col;
    }

    final int acrossId = board.acrossEntryForCell[i];
    if (acrossId >= 0) {
      acrossRunIds.add(acrossId);
    }
    final int downId = board.downEntryForCell[i];
    if (downId >= 0) {
      downRunIds.add(downId);
    }
  }

  final List<int> acrossIds = _sortedIntList(acrossRunIds);
  final List<int> downIds = _sortedIntList(downRunIds);
  final Map<int, int> runLengthById = <int, int>{};
  for (final KakuroEntry entry in board.entries) {
    runLengthById[entry.id] = entry.cells.length;
  }

  int disagreementMaxRunLength = 0;
  bool disagreementTouchesLongRun = false;
  for (final int runId in <int>{...acrossRunIds, ...downRunIds}) {
    final int length = runLengthById[runId] ?? 0;
    if (length > disagreementMaxRunLength) {
      disagreementMaxRunLength = length;
    }
    if (length >= 5) {
      disagreementTouchesLongRun = true;
    }
  }

  final Map<String, int> boundingBox;
  if (disagreementCellCount == 0) {
    boundingBox = const <String, int>{
      'minRow': -1,
      'maxRow': -1,
      'minCol': -1,
      'maxCol': -1,
      'height': 0,
      'width': 0,
    };
  } else {
    boundingBox = <String, int>{
      'minRow': minRow,
      'maxRow': maxRow,
      'minCol': minCol,
      'maxCol': maxCol,
      'height': maxRow - minRow + 1,
      'width': maxCol - minCol + 1,
    };
  }

  return <String, Object?>{
    'disagreementCellCount': disagreementCellCount,
    'disagreementRunIds': <String, List<int>>{
      'across': acrossIds,
      'down': downIds,
    },
    'disagreementBoundingBox': boundingBox,
    'disagreementAcrossRunCount': acrossIds.length,
    'disagreementDownRunCount': downIds.length,
    'disagreementRunCount': acrossIds.length + downIds.length,
    'disagreementTouchesLongRun': disagreementTouchesLongRun,
    'disagreementMaxRunLength': disagreementMaxRunLength,
  };
}

class KakuroSolver extends PuzzleSolver<KakuroBoard> {
  const KakuroSolver({this.maxSearchDepth = 16, this.maxBacktrackNodes});

  final int maxSearchDepth;
  final int? maxBacktrackNodes;

  @override
  SolverResult<KakuroBoard> solve(KakuroBoard board, SolverContext context) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final _KakuroSearch search = _KakuroSearch(
      board: board,
      maxSolutions: context.maxSolutions,
      maxSearchDepth: maxSearchDepth,
      maxBacktrackNodes: maxBacktrackNodes,
    );
    search.solve();
    stopwatch.stop();

    final List<KakuroBoard> solutions = search.solutions
        .map((List<int> values) => board.copyWith(values: values))
        .toList(growable: false);

    final SolverStatus status = search.solutionStatus;
    final Map<String, Object?> telemetry = <String, Object?>{
      'searchNodes': search.searchNodes,
      'backtracks': search.backtracks,
      'maxDepth': search.maxDepth,
      'maxBranchingFactor': search.maxBranchingFactor,
      'forcedAssignments': search.forcedAssignments,
      'candidateRemovals': search.candidateRemovals,
      'avgRunCombinationCount': search.avgRunCombinationCount,
      'singleComboRunRatio': search.singleComboRunRatio,
      'maxRunLength': search.maxRunLength,
      'whiteCellCount': search.whiteCellCount,
      'runCount': search.runCount,
      'candidateShrinkPercent': search.candidateShrinkPercent,
      'backtrackNodes': search.backtrackNodes,
      'propagationRounds': search.propagationRounds,
      'initialCandidateSlots': search.initialCandidateSlots,
      'searchBudgetExceeded': search.searchBudgetExceeded,
      'hitSearchDepthLimit': search.hitSearchDepthLimit,
      'hitBacktrackNodeLimit': search.hitBacktrackNodeLimit,
      'solverStatus': status.name,
    };
    final Map<String, Object?>? disagreementSummary = _buildDisagreementSummary(
      board: board,
      maxSolutions: context.maxSolutions,
      solutions: search.solutions,
    );
    if (disagreementSummary != null) {
      telemetry['disagreementSummary'] = disagreementSummary;
    }

    return SolverResult<KakuroBoard>(
      solutions: solutions,
      elapsed: stopwatch.elapsed,
      telemetry: telemetry,
      status: status,
    );
  }
}

class _EntryState {
  _EntryState({required this.entry, required List<int> combos})
    : combos = List<int>.from(combos);

  final KakuroEntry entry;
  List<int> combos;
}

class _Snapshot {
  _Snapshot({
    required this.values,
    required this.candidates,
    required this.entryCombos,
    required this.unsatisfiable,
    required this.propagationRounds,
  });

  final List<int> values;
  final List<int> candidates;
  final List<List<int>> entryCombos;
  final bool unsatisfiable;
  final int propagationRounds;

  static _Snapshot capture(_KakuroSearch search) => _Snapshot(
    values: List<int>.from(search.values),
    candidates: List<int>.from(search.candidates),
    entryCombos: search.entryStates
        .map((_EntryState state) => List<int>.from(state.combos))
        .toList(growable: false),
    unsatisfiable: search._unsatisfiable,
    propagationRounds: search.propagationRounds,
  );

  void restore(_KakuroSearch search) {
    for (int i = 0; i < search.values.length; i++) {
      search.values[i] = values[i];
      search.candidates[i] = candidates[i];
    }
    for (int i = 0; i < search.entryStates.length; i++) {
      search.entryStates[i].combos = List<int>.from(entryCombos[i]);
    }
    search._unsatisfiable = unsatisfiable;
    search.propagationRounds = propagationRounds;
  }
}

class _KakuroSearch {
  _KakuroSearch({
    required this.board,
    required this.maxSolutions,
    required this.maxSearchDepth,
    this.maxBacktrackNodes,
  }) : cellCount = board.cellCount,
       values = List<int>.from(board.values),
       candidates = List<int>.filled(board.cellCount, _allDigitsMask),
       entryStates = <_EntryState>[],
       valueCellCount = board.kinds
           .where((KakuroCellKind kind) => kind == KakuroCellKind.value)
           .length {
    _initialise();
  }

  final KakuroBoard board;
  final int maxSolutions;
  final int maxSearchDepth;
  final int? maxBacktrackNodes;
  final int cellCount;

  final List<int> values;
  final List<int> candidates;
  final List<_EntryState> entryStates;

  final int valueCellCount;
  final List<List<int>> solutions = <List<int>>[];

  bool _unsatisfiable = false;

  int forcedAssignments = 0;
  int candidateRemovals = 0;
  int searchNodes = 0;
  int backtracks = 0;
  int maxDepth = 0;
  int maxBranchingFactor = 0;
  int backtrackNodes = 0;
  int propagationRounds = 0;
  int initialCandidateSlots = 0;
  int runCount = 0;
  int whiteCellCount = 0;
  int maxRunLength = 0;
  int singleComboRunCount = 0;
  int totalRunCombinationCount = 0;
  bool hitSearchDepthLimit = false;
  bool hitBacktrackNodeLimit = false;

  double get candidateShrinkPercent {
    final int maxSlots = max(valueCellCount * 9, 1);
    final double ratio = candidateRemovals / maxSlots;
    return ratio.clamp(0.0, 1.0);
  }

  bool get searchBudgetExceeded => hitSearchDepthLimit || hitBacktrackNodeLimit;

  double get avgRunCombinationCount {
    if (runCount <= 0) {
      return 0.0;
    }
    return totalRunCombinationCount / runCount;
  }

  double get singleComboRunRatio {
    if (runCount <= 0) {
      return 0.0;
    }
    return singleComboRunCount / runCount;
  }

  SolverStatus get solutionStatus {
    if (solutions.length >= 2) {
      return SolverStatus.multiple;
    }
    if (searchBudgetExceeded) {
      return SolverStatus.unknown;
    }
    if (solutions.isEmpty) {
      return SolverStatus.noSolution;
    }
    if (maxSolutions <= 1) {
      // A one-solution cap cannot prove uniqueness if a solution exists.
      return SolverStatus.unknown;
    }
    return SolverStatus.unique;
  }

  void _initialise() {
    for (final KakuroEntry entry in board.entries) {
      final Set<int>? combos = KakuroDictionary.getCombinations(
        entry.cells.length,
        entry.sum,
      );
      if (combos == null || combos.isEmpty) {
        _unsatisfiable = true;
        return;
      }
      final List<int> filtered = combos
          .where((int combo) {
            for (final int cellIndex in entry.cells) {
              final int value = values[cellIndex];
              if (value == 0) {
                continue;
              }
              if ((combo & _bitFor(value)) == 0) {
                return false;
              }
            }
            return true;
          })
          .toList(growable: false);
      if (filtered.isEmpty) {
        _unsatisfiable = true;
        return;
      }
      entryStates.add(_EntryState(entry: entry, combos: filtered));
    }

    for (int i = 0; i < cellCount; i++) {
      if (!board.isPlayableIndex(i)) {
        candidates[i] = 0;
        continue;
      }
      final int value = values[i];
      if (value > 0) {
        candidates[i] = _bitFor(value);
      } else {
        candidates[i] = _allDigitsMask;
      }
    }

    if (!_propagate()) {
      _unsatisfiable = true;
      return;
    }

    runCount = entryStates.length;
    whiteCellCount = valueCellCount;
    maxRunLength = 0;
    totalRunCombinationCount = 0;
    singleComboRunCount = 0;
    for (final _EntryState state in entryStates) {
      final int runLength = state.entry.cells.length;
      if (runLength > maxRunLength) {
        maxRunLength = runLength;
      }
      final int combos = state.combos.length;
      totalRunCombinationCount += combos;
      if (combos == 1) {
        singleComboRunCount++;
      }
    }

    initialCandidateSlots = _totalCandidateSlots();
  }

  int _totalCandidateSlots() {
    int total = 0;
    for (int i = 0; i < cellCount; i++) {
      if (!board.isPlayableIndex(i)) {
        continue;
      }
      total += _countBits(candidates[i]);
    }
    return total;
  }

  void solve() {
    if (_unsatisfiable) {
      return;
    }
    _search(0);
  }

  void _search(int depth) {
    searchNodes++;
    if (depth > maxDepth) {
      maxDepth = depth;
    }
    if (_unsatisfiable) {
      return;
    }
    if (solutions.length >= maxSolutions) {
      return;
    }
    if (maxBacktrackNodes != null && backtrackNodes >= maxBacktrackNodes!) {
      hitBacktrackNodeLimit = true;
      return;
    }

    if (!_propagate()) {
      return;
    }

    if (_isSolved()) {
      solutions.add(List<int>.from(values));
      return;
    }

    if (depth >= maxSearchDepth) {
      hitSearchDepthLimit = true;
      return;
    }

    final int cellIndex = _selectCellForGuess();
    if (cellIndex == -1) {
      return;
    }

    final List<int> digits = _digitsFromMask(candidates[cellIndex]);
    if (digits.length > maxBranchingFactor) {
      maxBranchingFactor = digits.length;
    }
    for (final int digit in digits) {
      if (solutions.length >= maxSolutions) {
        break;
      }
      final _Snapshot snapshot = _Snapshot.capture(this);
      final int solutionsBefore = solutions.length;
      final bool budgetBeforeBranch = searchBudgetExceeded;
      backtrackNodes++;
      if (maxBacktrackNodes != null && backtrackNodes > maxBacktrackNodes!) {
        hitBacktrackNodeLimit = true;
        snapshot.restore(this);
        return;
      }
      values[cellIndex] = digit;
      candidates[cellIndex] = _bitFor(digit);
      _search(depth + 1);
      final bool foundNewSolution = solutions.length > solutionsBefore;
      if (!foundNewSolution && !(searchBudgetExceeded && !budgetBeforeBranch)) {
        backtracks++;
      }
      snapshot.restore(this);
    }
  }

  bool _propagate() {
    bool changed = true;
    while (!_unsatisfiable && changed) {
      changed = false;
      propagationRounds++;
      for (final _EntryState state in entryStates) {
        final bool updated = _updateEntry(state);
        if (_unsatisfiable) {
          return false;
        }
        if (updated) {
          changed = true;
        }
      }
    }
    return !_unsatisfiable;
  }

  bool _updateEntry(_EntryState state) {
    final List<int> cells = state.entry.cells;
    final List<int> validCombos = <int>[];
    final List<List<int>> perComboMasks = <List<int>>[];

    for (final int combo in state.combos) {
      final List<int>? masks = _evaluateCombo(state, combo);
      if (masks == null) {
        continue;
      }
      validCombos.add(combo);
      perComboMasks.add(masks);
    }

    if (validCombos.isEmpty) {
      _unsatisfiable = true;
      return false;
    }

    bool changed = validCombos.length != state.combos.length;
    state.combos = validCombos;

    final int length = cells.length;
    final List<int> aggregated = List<int>.filled(length, 0);
    for (final List<int> masks in perComboMasks) {
      for (int i = 0; i < length; i++) {
        aggregated[i] |= masks[i];
      }
    }

    final List<int> refined = List<int>.from(aggregated);
    if (_applySubsetLogic(refined)) {
      changed = true;
    }

    for (int i = 0; i < length; i++) {
      final int cellIndex = cells[i];
      final int assigned = values[cellIndex];
      final int allowed = refined[i];
      if (assigned > 0) {
        if ((allowed & _bitFor(assigned)) == 0) {
          _unsatisfiable = true;
          return false;
        }
        candidates[cellIndex] = _bitFor(assigned);
        continue;
      }
      if (allowed == 0) {
        _unsatisfiable = true;
        return false;
      }
      final int current = candidates[cellIndex];
      final int newMask = current & allowed;
      if (newMask != current) {
        final int removed = _countBits(current) - _countBits(newMask);
        if (removed > 0) {
          candidateRemovals += removed;
        }
        candidates[cellIndex] = newMask;
        changed = true;
        if (newMask == 0) {
          _unsatisfiable = true;
          return false;
        }
      }
      if (values[cellIndex] == 0 && _countBits(candidates[cellIndex]) == 1) {
        final int digit = _singleDigit(candidates[cellIndex]);
        values[cellIndex] = digit;
        forcedAssignments++;
        changed = true;
      }
    }

    return changed;
  }

  List<int>? _evaluateCombo(_EntryState state, int combo) {
    final List<int> digits = _digitsFromMask(combo);
    final List<int> available = List<int>.from(digits);
    final List<int?> chosen = List<int?>.filled(state.entry.cells.length, null);
    final List<int> maskAccum = List<int>.filled(state.entry.cells.length, 0);

    bool any = _exploreAssignments(state, 0, available, chosen, maskAccum);
    if (!any) {
      return null;
    }
    return maskAccum;
  }

  bool _exploreAssignments(
    _EntryState state,
    int depth,
    List<int> available,
    List<int?> chosen,
    List<int> maskAccum,
  ) {
    if (depth >= state.entry.cells.length) {
      for (int i = 0; i < state.entry.cells.length; i++) {
        final int cellIndex = state.entry.cells[i];
        int digit = values[cellIndex];
        if (digit == 0) {
          digit = chosen[i]!;
        }
        maskAccum[i] |= _bitFor(digit);
      }
      return true;
    }

    final int cellIndex = state.entry.cells[depth];
    final int assigned = values[cellIndex];
    final int mask = candidates[cellIndex];

    if (assigned > 0) {
      if (!available.remove(assigned)) {
        return false;
      }
      if (mask != 0 && (mask & _bitFor(assigned)) == 0) {
        available.add(assigned);
        return false;
      }
      chosen[depth] = assigned;
      final bool result = _exploreAssignments(
        state,
        depth + 1,
        available,
        chosen,
        maskAccum,
      );
      chosen[depth] = null;
      available.add(assigned);
      return result;
    }

    bool any = false;
    final List<int> options = <int>[];
    for (final int digit in List<int>.from(available)) {
      final int bit = _bitFor(digit);
      if (mask != 0 && (mask & bit) == 0) {
        continue;
      }
      options.add(digit);
    }
    for (final int digit in options) {
      available.remove(digit);
      chosen[depth] = digit;
      if (_exploreAssignments(state, depth + 1, available, chosen, maskAccum)) {
        any = true;
      }
      chosen[depth] = null;
      available.add(digit);
    }
    return any;
  }

  bool _applySubsetLogic(List<int> masks) {
    bool changed = false;
    final int length = masks.length;
    final int maxMask = 1 << length;
    for (int subset = 1; subset < maxMask; subset++) {
      final int subsetSize = _countBits(subset);
      if (subsetSize <= 1) {
        continue;
      }
      int unionMask = 0;
      for (int i = 0; i < length; i++) {
        if ((subset & (1 << i)) != 0) {
          unionMask |= masks[i];
        }
      }
      final int digitCount = _countBits(unionMask);
      if (digitCount == 0 || digitCount != subsetSize) {
        continue;
      }
      for (int i = 0; i < length; i++) {
        if ((subset & (1 << i)) != 0) {
          final int newMask = masks[i] & unionMask;
          if (newMask != masks[i]) {
            masks[i] = newMask;
            changed = true;
          }
        } else {
          final int newMask = masks[i] & (~unionMask & _allDigitsMask);
          if (newMask != masks[i]) {
            masks[i] = newMask;
            changed = true;
          }
        }
      }
    }
    return changed;
  }

  bool _isSolved() {
    for (int i = 0; i < cellCount; i++) {
      if (!board.isPlayableIndex(i)) {
        continue;
      }
      if (values[i] == 0) {
        return false;
      }
    }
    for (final _EntryState state in entryStates) {
      int sum = 0;
      final Set<int> seen = <int>{};
      for (final int index in state.entry.cells) {
        final int value = values[index];
        if (value == 0 || !seen.add(value)) {
          return false;
        }
        sum += value;
      }
      if (sum != state.entry.sum) {
        return false;
      }
    }
    return true;
  }

  int _selectCellForGuess() {
    int bestIndex = -1;
    int bestCount = 10;
    for (int i = 0; i < cellCount; i++) {
      if (!board.isPlayableIndex(i)) {
        continue;
      }
      if (values[i] != 0) {
        continue;
      }
      final int mask = candidates[i];
      final int count = _countBits(mask);
      if (count <= 1) {
        continue;
      }
      if (count < bestCount) {
        bestCount = count;
        bestIndex = i;
        if (count == 2) {
          break;
        }
      }
    }
    return bestIndex;
  }
}

class KakuroBottomUpSnapshot {
  KakuroBottomUpSnapshot({
    required this.values,
    required this.candidates,
    required this.activeEntryStates,
    required this.unsatisfiable,
    required this.propagationRounds,
    required this.candidateRemovals,
    required this.forcedAssignments,
  });

  final List<int> values;
  final List<int> candidates;
  final List<List<int>> activeEntryStates;
  final bool unsatisfiable;
  final int propagationRounds;
  final int candidateRemovals;
  final int forcedAssignments;

  static KakuroBottomUpSnapshot capture(KakuroBottomUpEvaluator eval) =>
      KakuroBottomUpSnapshot(
        values: List<int>.from(eval.values),
        candidates: List<int>.from(eval.candidates),
        activeEntryStates: eval.activeEntries
            .map((_EntryState e) => List<int>.from(e.combos))
            .toList(growable: false),
        unsatisfiable: eval.unsatisfiable,
        propagationRounds: eval.propagationRounds,
        candidateRemovals: eval.candidateRemovals,
        forcedAssignments: eval.forcedAssignments,
      );

  void restore(KakuroBottomUpEvaluator eval) {
    for (int i = 0; i < eval.values.length; i++) {
      eval.values[i] = values[i];
      eval.candidates[i] = candidates[i];
    }
    for (int i = 0; i < activeEntryStates.length; i++) {
      eval.activeEntries[i].combos = List<int>.from(activeEntryStates[i]);
    }
    if (eval.activeEntries.length > activeEntryStates.length) {
      eval.activeEntries.length = activeEntryStates.length;
    }
    eval.unsatisfiable = unsatisfiable;
    eval.propagationRounds = propagationRounds;
    eval.candidateRemovals = candidateRemovals;
    eval.forcedAssignments = forcedAssignments;
  }
}

class KakuroBottomUpEvaluator {
  KakuroBottomUpEvaluator(this.board)
      : cellCount = board.cellCount,
        values = List<int>.filled(board.cellCount, 0),
        candidates = List<int>.filled(board.cellCount, _allDigitsMask),
        activeEntries = <_EntryState>[] {
    for (int i = 0; i < cellCount; i++) {
      if (!board.isPlayableIndex(i)) {
        candidates[i] = 0;
      }
    }
  }

  final KakuroBoard board;
  final int cellCount;

  final List<int> values;
  final List<int> candidates;
  final List<_EntryState> activeEntries;

  Map<int, int> get activeEntrySums {
    final Map<int, int> sums = <int, int>{};
    for (final _EntryState state in activeEntries) {
      sums[state.entry.id] = state.entry.sum;
    }
    return sums;
  }

  bool unsatisfiable = false;
  int candidateRemovals = 0;
  int forcedAssignments = 0;
  int propagationRounds = 0;
  int searchNodes = 0;
  int backtracks = 0;

  KakuroBottomUpSnapshot capture() => KakuroBottomUpSnapshot.capture(this);
  void restore(KakuroBottomUpSnapshot snapshot) => snapshot.restore(this);

  bool injectSum(KakuroEntry entry, int sum) {
    if (unsatisfiable) return false;

    final Set<int>? combos = KakuroDictionary.getCombinations(entry.cells.length, sum);
    if (combos == null || combos.isEmpty) {
      unsatisfiable = true;
      return false;
    }

    final List<int> filtered = combos.where((int combo) {
      for (final int cellIndex in entry.cells) {
        final int value = values[cellIndex];
        if (value == 0) continue;
        if ((combo & _bitFor(value)) == 0) return false;
      }
      return true;
    }).toList(growable: false);

    if (filtered.isEmpty) {
      unsatisfiable = true;
      return false;
    }

    activeEntries.add(_EntryState(entry: entry.copyWith(sum: sum), combos: filtered));
    return _propagate();
  }

  bool _propagate() {
    bool changed = true;
    while (!unsatisfiable && changed) {
      changed = false;
      propagationRounds++;
      for (final _EntryState state in activeEntries) {
        final bool updated = _updateEntry(state);
        if (unsatisfiable) {
          return false;
        }
        if (updated) {
          changed = true;
        }
      }
    }
    return !unsatisfiable;
  }

  bool _updateEntry(_EntryState state) {
    final List<int> cells = state.entry.cells;
    final List<int> validCombos = <int>[];
    final List<List<int>> perComboMasks = <List<int>>[];

    for (final int combo in state.combos) {
      final List<int>? masks = _evaluateCombo(state, combo);
      if (masks == null) {
        continue;
      }
      validCombos.add(combo);
      perComboMasks.add(masks);
    }

    if (validCombos.isEmpty) {
      unsatisfiable = true;
      return false;
    }

    bool changed = validCombos.length != state.combos.length;
    state.combos = validCombos;

    final int length = cells.length;
    final List<int> aggregated = List<int>.filled(length, 0);
    for (final List<int> masks in perComboMasks) {
      for (int i = 0; i < length; i++) {
        aggregated[i] |= masks[i];
      }
    }

    final List<int> refined = List<int>.from(aggregated);
    if (_applySubsetLogic(refined)) {
      changed = true;
    }

    for (int i = 0; i < length; i++) {
      final int cellIndex = cells[i];
      final int assigned = values[cellIndex];
      final int allowed = refined[i];
      if (assigned > 0) {
        if ((allowed & _bitFor(assigned)) == 0) {
          unsatisfiable = true;
          return false;
        }
        candidates[cellIndex] = _bitFor(assigned);
        continue;
      }
      if (allowed == 0) {
        unsatisfiable = true;
        return false;
      }
      final int current = candidates[cellIndex];
      final int newMask = current & allowed;
      if (newMask != current) {
        final int removed = _countBits(current) - _countBits(newMask);
        if (removed > 0) {
          candidateRemovals += removed;
        }
        candidates[cellIndex] = newMask;
        changed = true;
        if (newMask == 0) {
          unsatisfiable = true;
          return false;
        }
      }
      if (values[cellIndex] == 0 && _countBits(candidates[cellIndex]) == 1) {
        final int digit = _singleDigit(candidates[cellIndex]);
        values[cellIndex] = digit;
        forcedAssignments++;
        changed = true;
      }
    }

    return changed;
  }

  List<int>? _evaluateCombo(_EntryState state, int combo) {
    final List<int> digits = _digitsFromMask(combo);
    final List<int> available = List<int>.from(digits);
    final List<int?> chosen = List<int?>.filled(state.entry.cells.length, null);
    final List<int> maskAccum = List<int>.filled(state.entry.cells.length, 0);

    bool any = _exploreAssignments(state, 0, available, chosen, maskAccum);
    if (!any) {
      return null;
    }
    return maskAccum;
  }

  bool _exploreAssignments(
    _EntryState state,
    int depth,
    List<int> available,
    List<int?> chosen,
    List<int> maskAccum,
  ) {
    if (depth >= state.entry.cells.length) {
      for (int i = 0; i < state.entry.cells.length; i++) {
        final int cellIndex = state.entry.cells[i];
        int digit = values[cellIndex];
        if (digit == 0) {
          digit = chosen[i]!;
        }
        maskAccum[i] |= _bitFor(digit);
      }
      return true;
    }

    final int cellIndex = state.entry.cells[depth];
    final int assigned = values[cellIndex];
    final int mask = candidates[cellIndex];

    if (assigned > 0) {
      if (!available.remove(assigned)) {
        return false;
      }
      if (mask != 0 && (mask & _bitFor(assigned)) == 0) {
        available.add(assigned);
        return false;
      }
      chosen[depth] = assigned;
      final bool result = _exploreAssignments(
        state,
        depth + 1,
        available,
        chosen,
        maskAccum,
      );
      chosen[depth] = null;
      available.add(assigned);
      return result;
    }

    bool any = false;
    final List<int> options = <int>[];
    for (final int digit in List<int>.from(available)) {
      final int bit = _bitFor(digit);
      if (mask != 0 && (mask & bit) == 0) {
        continue;
      }
      options.add(digit);
    }
    for (final int digit in options) {
      available.remove(digit);
      chosen[depth] = digit;
      if (_exploreAssignments(state, depth + 1, available, chosen, maskAccum)) {
        any = true;
      }
      chosen[depth] = null;
      available.add(digit);
    }
    return any;
  }

  bool _applySubsetLogic(List<int> masks) {
    bool changed = false;
    final int length = masks.length;
    final int maxMask = 1 << length;
    for (int subset = 1; subset < maxMask; subset++) {
      final int subsetSize = _countBits(subset);
      if (subsetSize <= 1) {
        continue;
      }
      int unionMask = 0;
      for (int i = 0; i < length; i++) {
        if ((subset & (1 << i)) != 0) {
          unionMask |= masks[i];
        }
      }
      final int digitCount = _countBits(unionMask);
      if (digitCount == 0 || digitCount != subsetSize) {
        continue;
      }
      for (int i = 0; i < length; i++) {
        if ((subset & (1 << i)) != 0) {
          final int newMask = masks[i] & unionMask;
          if (newMask != masks[i]) {
            masks[i] = newMask;
            changed = true;
          }
        } else {
          final int newMask = masks[i] & (~unionMask & _allDigitsMask);
          if (newMask != masks[i]) {
            masks[i] = newMask;
            changed = true;
          }
        }
      }
    }
    return changed;
  }
}
