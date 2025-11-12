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

    final Map<String, Object?> telemetry = <String, Object?>{
      'forcedAssignments': search.forcedAssignments,
      'candidateRemovals': search.candidateRemovals,
      'candidateShrinkPercent': search.candidateShrinkPercent,
      'backtrackNodes': search.backtrackNodes,
      'propagationRounds': search.propagationRounds,
      'initialCandidateSlots': search.initialCandidateSlots,
    };

    return SolverResult<KakuroBoard>(
      solutions: solutions,
      elapsed: stopwatch.elapsed,
      telemetry: telemetry,
    );
  }
}

class _EntryState {
  _EntryState({
    required this.entry,
    required List<int> combos,
  }) : combos = List<int>.from(combos);

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
            .map(( _EntryState state) => List<int>.from(state.combos))
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
  })  : cellCount = board.cellCount,
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
  int backtrackNodes = 0;
  int propagationRounds = 0;
  int initialCandidateSlots = 0;

  double get candidateShrinkPercent {
    final int maxSlots = max(valueCellCount * 9, 1);
    final double ratio = candidateRemovals / maxSlots;
    return ratio.clamp(0.0, 1.0);
  }

  void _initialise() {
    for (final KakuroEntry entry in board.entries) {
      final Set<int>? combos =
          KakuroDictionary.getCombinations(entry.cells.length, entry.sum);
      if (combos == null || combos.isEmpty) {
        _unsatisfiable = true;
        return;
      }
      final List<int> filtered = combos.where((int combo) {
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
      }).toList(growable: false);
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
    if (_unsatisfiable) {
      return;
    }
    if (solutions.length >= maxSolutions) {
      return;
    }
    if (maxBacktrackNodes != null && backtrackNodes >= maxBacktrackNodes!) {
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
      return;
    }

    final int cellIndex = _selectCellForGuess();
    if (cellIndex == -1) {
      return;
    }

    final List<int> digits = _digitsFromMask(candidates[cellIndex]);
    for (final int digit in digits) {
      if (solutions.length >= maxSolutions) {
        break;
      }
      final _Snapshot snapshot = _Snapshot.capture(this);
      backtrackNodes++;
      if (maxBacktrackNodes != null && backtrackNodes > maxBacktrackNodes!) {
        snapshot.restore(this);
        return;
      }
      values[cellIndex] = digit;
      candidates[cellIndex] = _bitFor(digit);
      _search(depth + 1);
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
      final bool result = _exploreAssignments(state, depth + 1, available, chosen, maskAccum);
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
