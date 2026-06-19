import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

import '../../shared/models/models.dart';
import '../../shared/providers/puzzle_local_store_providers.dart';

const Duration _tickInterval = Duration(milliseconds: 200);
const Duration _hintHighlightDuration = Duration(seconds: 3);

/// Provider for the puzzle play view model.
final puzzlePlayViewModelProvider = NotifierProvider.autoDispose
    .family<PuzzlePlayViewModel, PuzzlePlayState, PuzzlePlaySession>(
      (PuzzlePlaySession session) => PuzzlePlayViewModel()..init(session),
    );

/// View model responsible for managing puzzle play state including timer,
/// move history, undo, restart, and solve detection.
class PuzzlePlayViewModel extends Notifier<PuzzlePlayState> {
  PuzzlePlayViewModel();

  final Stopwatch _stopwatch = Stopwatch();
  final List<_HistoryEntry> _history = <_HistoryEntry>[];

  late PuzzlePlaySession _session;
  core.PuzzleValidator<dynamic>? _validator;
  Timer? _ticker;
  bool _solvedEmitted = false;
  Timer? _hintClearTimer;
  int _hintRequestCount = 0;
  Timer? _conflictCheckTimer;

  void init(PuzzlePlaySession session) {
    _session = session;
  }

  @override
  PuzzlePlayState build() {
    _validator = _session.validator ?? _deriveValidator(_session.engine);
    _history.clear();
    _ticker?.cancel();
    _ticker = null;
    _stopwatch
      ..stop()
      ..reset();
    _cancelHintTimer();
    _hintRequestCount = 0;

    final Object? initialBoard = _session.puzzle.state;
    final bool initiallySolved = _isSolved(initialBoard);
    _solvedEmitted = initiallySolved;

    state = PuzzlePlayState(
      puzzle: _session.puzzle,
      board: initialBoard,
      elapsed: Duration.zero,
      isSolved: initiallySolved,
      isTimerRunning: false,
      moveHistory: const <PuzzleMoveRecord>[],
      moveCount: 0,
      supportsHints: _session.engine.capabilities.supportsHints,
      hintHighlight: null,
      conflictingCells: null,
      isShowingConflicts: false,
    );
    if (!initiallySolved) {
      _startTimer();
    }

    ref.onDispose(_disposeTimer);
    ref.onDispose(_disposeHintHighlight);

    return state;
  }

  /// Apply a move to the puzzle. For Killer Queens, allows invalid moves and shows
  /// conflict feedback after 2 seconds. For other puzzles, throws [StateError] if invalid.
  void applyMove(dynamic move) {
    if (state.isSolved) {
      throw StateError('Cannot apply moves when the puzzle is solved.');
    }

    final Object? currentBoard = state.board;
    final bool isKillerQueens = _session.engine.id == 'killer_queens';

    // For Killer Queens, we allow the move regardless of validity
    // and check for conflicts after a delay
    if (isKillerQueens) {
      _applyKillerQueensMove(move, currentBoard);
      return;
    }

    // For other puzzle types, validate normally
    final core.MoveResult<dynamic> result = _session.engine.validateMove(
      currentState: currentBoard,
      move: move,
    );

    if (!result.isValid || result.newState == null) {
      final String message =
          result.errorMessage ?? 'Engine rejected the submitted move';
      throw StateError('Invalid move: $message');
    }

    final Object newBoard = result.newState!;
    final _HistoryEntry entry = _HistoryEntry(
      move: move,
      previousState: currentBoard,
      resultingState: newBoard,
      timestamp: DateTime.now(),
    );
    _history.add(entry);

    final bool solved = _isSolved(newBoard);
    final bool hadHintHighlight = state.hintHighlight != null;
    if (hadHintHighlight) {
      _cancelHintTimer();
    }
    if (solved) {
      _stopTimer();
    } else {
      _ensureTimerRunning();
    }

    state = state.copyWith(
      board: newBoard,
      moveHistory: _createMoveRecords(),
      moveCount: _history.length,
      isSolved: solved,
      elapsed: _stopwatch.elapsed,
      isTimerRunning: _stopwatch.isRunning,
      clearHintHighlight: hadHintHighlight,
    );

    if (solved) {
      unawaited(_dispatchSolved());
    }
  }

  /// Apply a move for Killer Queens puzzle, allowing invalid placements
  /// and detecting conflicts after 2 seconds
  void _applyKillerQueensMove(dynamic move, Object? currentBoard) {
    // Cancel any pending conflict check
    _conflictCheckTimer?.cancel();

    // Apply the move directly to the board without validation
    final core.KillerQueensBoard board = currentBoard as core.KillerQueensBoard;
    final core.KillerQueensMove kqMove = move as core.KillerQueensMove;

    final int index = board.indexFor(kqMove.row, kqMove.col);
    final List<int> updatedCells = List<int>.from(board.cells);
    updatedCells[index] = kqMove.value;

    final core.KillerQueensBoard newBoard = core.KillerQueensBoard(
      size: board.size,
      cells: updatedCells,
      fixed: board.fixed,
      cages: board.cages,
    );

    final _HistoryEntry entry = _HistoryEntry(
      move: move,
      previousState: currentBoard,
      resultingState: newBoard,
      timestamp: DateTime.now(),
    );
    _history.add(entry);

    final bool solved = _isSolved(newBoard);
    final bool hadHintHighlight = state.hintHighlight != null;
    if (hadHintHighlight) {
      _cancelHintTimer();
    }
    if (solved) {
      _stopTimer();
    } else {
      _ensureTimerRunning();
    }

    // Update state immediately (without showing conflicts yet)
    state = state.copyWith(
      board: newBoard,
      moveHistory: _createMoveRecords(),
      moveCount: _history.length,
      isSolved: solved,
      elapsed: _stopwatch.elapsed,
      isTimerRunning: _stopwatch.isRunning,
      clearConflicts: true, // Clear any existing conflicts
      clearHintHighlight: hadHintHighlight,
    );

    if (solved) {
      unawaited(_dispatchSolved());
      return;
    }

    // Schedule conflict detection after 2 seconds
    _conflictCheckTimer = Timer(const Duration(seconds: 2), () {
      _checkAndShowConflicts(newBoard);
    });
  }

  /// Check for conflicts in the Killer Queens board and update state
  void _checkAndShowConflicts(core.KillerQueensBoard board) {
    final Set<int> conflicts = _findKillerQueensConflicts(board);

    if (conflicts.isNotEmpty) {
      // Trigger haptic feedback
      unawaited(_triggerHapticFeedback());

      // Update state to show conflicts
      state = state.copyWith(
        conflictingCells: conflicts,
        isShowingConflicts: true,
      );

      // Clear conflicts after animation (brief duration for vibration effect)
      Timer(const Duration(milliseconds: 600), () {
        if (state.isShowingConflicts) {
          state = state.copyWith(isShowingConflicts: false);
        }
      });
    }
  }

  /// Find all cells that have conflicting queens
  Set<int> _findKillerQueensConflicts(core.KillerQueensBoard board) {
    final Set<int> conflicts = <int>{};
    final int size = board.size;

    // Find all queen positions
    final List<int> queenIndices = <int>[];
    for (int i = 0; i < board.cells.length; i++) {
      if (board.cells[i] == 1) {
        queenIndices.add(i);
      }
    }

    // Check for conflicts between queens
    for (int i = 0; i < queenIndices.length; i++) {
      final int idx1 = queenIndices[i];
      final int row1 = idx1 ~/ size;
      final int col1 = idx1 % size;
      final int cage1 = board.cageByCell[idx1];

      for (int j = i + 1; j < queenIndices.length; j++) {
        final int idx2 = queenIndices[j];
        final int row2 = idx2 ~/ size;
        final int col2 = idx2 % size;
        final int cage2 = board.cageByCell[idx2];

        bool hasConflict = false;

        // Check same row
        if (row1 == row2) {
          hasConflict = true;
        }

        // Check same column
        if (col1 == col2) {
          hasConflict = true;
        }

        // Check same cage
        if (cage1 == cage2) {
          hasConflict = true;
        }

        // Check diagonally adjacent (including diagonals)
        final int rowDiff = (row1 - row2).abs();
        final int colDiff = (col1 - col2).abs();
        if (rowDiff <= 1 && colDiff <= 1 && (rowDiff > 0 || colDiff > 0)) {
          hasConflict = true;
        }

        if (hasConflict) {
          conflicts.add(idx1);
          conflicts.add(idx2);
        }
      }
    }

    return conflicts;
  }

  /// Trigger haptic feedback for conflict detection
  Future<void> _triggerHapticFeedback() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      // Haptic feedback not supported on this device
    }
  }

  /// Undo the most recent move if available.
  void undo() {
    if (_history.isEmpty) {
      return;
    }

    _history.removeLast();
    final Object? board = _history.isEmpty
        ? _session.puzzle.state
        : _history.last.resultingState;

    final bool solved = _isSolved(board);
    final bool hadHintHighlight = state.hintHighlight != null;
    if (hadHintHighlight) {
      _cancelHintTimer();
    }

    // Cancel any pending conflict checks
    _conflictCheckTimer?.cancel();

    if (solved) {
      _stopTimer();
    } else {
      if (_solvedEmitted) {
        _solvedEmitted = false;
      }
      _ensureTimerRunning();
    }

    state = state.copyWith(
      board: board,
      moveHistory: _createMoveRecords(),
      moveCount: _history.length,
      isSolved: solved,
      elapsed: _stopwatch.elapsed,
      isTimerRunning: _stopwatch.isRunning,
      clearHintHighlight: hadHintHighlight,
      clearConflicts: true,
    );
  }

  /// Restart the puzzle from the initial state.
  void restart() {
    _stopTimer();
    _stopwatch.reset();
    _history.clear();

    final Object? initialBoard = _session.puzzle.state;
    final bool solved = _isSolved(initialBoard);
    _solvedEmitted = solved;
    final bool hadHintHighlight = state.hintHighlight != null;
    if (hadHintHighlight) {
      _cancelHintTimer();
    }

    state = state.copyWith(
      board: initialBoard,
      elapsed: Duration.zero,
      isSolved: solved,
      isTimerRunning: false,
      moveHistory: const <PuzzleMoveRecord>[],
      moveCount: 0,
      clearHintHighlight: hadHintHighlight,
    );

    if (!solved) {
      _startTimer();
    }
  }

  /// Whether there is a move that can be undone.
  bool get canUndo => state.canUndo;

  /// Request a gameplay hint from the active engine.
  void requestHint() {
    if (!state.supportsHints) {
      return;
    }

    final Object? board = state.board;
    if (board == null) {
      return;
    }

    final int iteration = _hintRequestCount;
    final core.PuzzleHint? hint = _session.engine.requestHint(
      currentState: board,
      request: core.PuzzleHintRequest(
        seed64: _session.puzzle.meta.seed64,
        iteration: iteration,
        moveCount: state.moveCount,
        metadata: <String, Object?>{
          'puzzleType': _session.puzzleType.key,
          'difficulty': _session.difficulty,
          'mode': _session.mode.name,
        },
      ),
    );
    _hintRequestCount = iteration + 1;

    if (hint == null || hint.isEmpty) {
      return;
    }

    _cancelHintTimer();
    state = state.copyWith(hintHighlight: hint);
    _hintClearTimer = Timer(_hintHighlightDuration, _handleHintTimeout);
  }

  /// Clear any active hint highlight immediately.
  void clearHintHighlight() {
    if (state.hintHighlight == null) {
      return;
    }
    _cancelHintTimer();
    state = state.copyWith(clearHintHighlight: true);
  }

  void _startTimer() {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
    }
    _ticker ??= Timer.periodic(_tickInterval, (_) => _updateElapsed());
    _updateElapsed();
  }

  void _ensureTimerRunning() {
    if (state.isSolved) {
      return;
    }
    if (!_stopwatch.isRunning) {
      _startTimer();
    } else if (_ticker == null) {
      _ticker = Timer.periodic(_tickInterval, (_) => _updateElapsed());
    }
    _updateElapsed();
  }

  void _stopTimer() {
    if (_ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
    }
    _updateElapsed();
  }

  void _disposeTimer() {
    _ticker?.cancel();
    _ticker = null;
    _conflictCheckTimer?.cancel();
    _conflictCheckTimer = null;
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
    }
  }

  void _disposeHintHighlight() {
    _cancelHintTimer();
  }

  void _updateElapsed() {
    state = state.copyWith(
      elapsed: _stopwatch.elapsed,
      isTimerRunning: _stopwatch.isRunning,
    );
  }

  void _handleHintTimeout() {
    _hintClearTimer = null;
    if (state.hintHighlight != null) {
      state = state.copyWith(clearHintHighlight: true);
    }
  }

  void _cancelHintTimer() {
    if (_hintClearTimer != null) {
      _hintClearTimer!.cancel();
      _hintClearTimer = null;
    }
  }

  bool _isSolved(Object? board) {
    if (board == null) {
      return false;
    }
    try {
      final core.PuzzleValidator<dynamic>? validator = _validator;
      if (validator != null) {
        return validator.isSolved(board);
      }
    } catch (_) {
      // If validator throws due to type mismatch we fall back to engine check.
    }
    return _session.engine.isSolved(board);
  }

  Future<void> _dispatchSolved() async {
    if (_solvedEmitted) {
      return;
    }
    _solvedEmitted = true;
    _stopTimer();

    final PuzzleCompletionController controller = ref.read(
      puzzleCompletionControllerProvider,
    );
    final PuzzleCompletionStatus completionStatus = await controller
        .recordCompletion(
          puzzleType: _session.puzzleType,
          difficulty: _session.difficulty,
          completionTime: state.elapsed,
          mode: _session.mode,
          size: _session.puzzle.meta.size.id,
          seed: _session.puzzle.meta.seedStr,
          moveCount: state.moveCount,
          hintsUsed: 0,
          dailyDateKeyUtc: _session.mode == PuzzleMode.daily
              ? DailyUtcDate.todayKey()
              : null,
        );

    final void Function(PuzzleSolvedEvent event)? callback = _session.onSolved;
    if (callback != null) {
      callback(
        PuzzleSolvedEvent(
          puzzle: _session.puzzle,
          board: state.board,
          elapsed: state.elapsed,
          moveCount: state.moveCount,
          moveHistory: state.moveHistory,
          completionStatus: completionStatus,
        ),
      );
    }
  }

  List<PuzzleMoveRecord> _createMoveRecords() {
    final List<PuzzleMoveRecord> records = <PuzzleMoveRecord>[];
    for (int i = 0; i < _history.length; i++) {
      records.add(_history[i].toRecord(i + 1));
    }
    return records;
  }

  core.PuzzleValidator<dynamic>? _deriveValidator(
    core.PuzzleEngine<dynamic, dynamic> engine,
  ) {
    if (engine is core.PipelinePuzzleEngine<dynamic, dynamic>) {
      return engine.validator;
    }
    return null;
  }
}

@immutable
class PuzzlePlayState {
  static const ListEquality<PuzzleMoveRecord> _historyEquality =
      ListEquality<PuzzleMoveRecord>();

  const PuzzlePlayState._({
    required this.puzzle,
    required this.board,
    required this.elapsed,
    required this.isSolved,
    required this.isTimerRunning,
    required this.moveHistory,
    required this.moveCount,
    required this.supportsHints,
    required this.isShowingConflicts,
    this.hintHighlight,
    this.conflictingCells,
  });

  factory PuzzlePlayState({
    required core.GeneratedPuzzle<dynamic> puzzle,
    required Object? board,
    required Duration elapsed,
    required bool isSolved,
    required bool isTimerRunning,
    required List<PuzzleMoveRecord> moveHistory,
    required int moveCount,
    required bool supportsHints,
    core.PuzzleHint? hintHighlight,
    Set<int>? conflictingCells,
    bool? isShowingConflicts,
  }) {
    return PuzzlePlayState._(
      puzzle: puzzle,
      board: board,
      elapsed: elapsed,
      isSolved: isSolved,
      isTimerRunning: isTimerRunning,
      moveHistory: UnmodifiableListView<PuzzleMoveRecord>(moveHistory),
      moveCount: moveCount,
      supportsHints: supportsHints,
      hintHighlight: hintHighlight,
      conflictingCells: conflictingCells,
      isShowingConflicts: isShowingConflicts ?? false,
    );
  }

  final core.GeneratedPuzzle<dynamic> puzzle;
  final Object? board;
  final Duration elapsed;
  final bool isSolved;
  final bool isTimerRunning;
  final UnmodifiableListView<PuzzleMoveRecord> moveHistory;
  final int moveCount;
  final bool supportsHints;
  final core.PuzzleHint? hintHighlight;
  final Set<int>? conflictingCells;
  final bool isShowingConflicts;

  bool get canUndo => moveHistory.isNotEmpty;
  bool get hasHintHighlight => hintHighlight != null;

  PuzzlePlayState copyWith({
    core.GeneratedPuzzle<dynamic>? puzzle,
    Object? board,
    Duration? elapsed,
    bool? isSolved,
    bool? isTimerRunning,
    List<PuzzleMoveRecord>? moveHistory,
    int? moveCount,
    bool? supportsHints,
    core.PuzzleHint? hintHighlight,
    bool clearHintHighlight = false,
    Set<int>? conflictingCells,
    bool? isShowingConflicts,
    bool clearConflicts = false,
  }) {
    return PuzzlePlayState(
      puzzle: puzzle ?? this.puzzle,
      board: board ?? this.board,
      elapsed: elapsed ?? this.elapsed,
      isSolved: isSolved ?? this.isSolved,
      isTimerRunning: isTimerRunning ?? this.isTimerRunning,
      moveHistory: moveHistory ?? this.moveHistory,
      moveCount: moveCount ?? this.moveCount,
      supportsHints: supportsHints ?? this.supportsHints,
      hintHighlight: clearHintHighlight
          ? null
          : hintHighlight ?? this.hintHighlight,
      conflictingCells: clearConflicts
          ? null
          : conflictingCells ?? this.conflictingCells,
      isShowingConflicts: clearConflicts
          ? false
          : isShowingConflicts ?? this.isShowingConflicts,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PuzzlePlayState &&
          runtimeType == other.runtimeType &&
          puzzle == other.puzzle &&
          board == other.board &&
          elapsed == other.elapsed &&
          isSolved == other.isSolved &&
          isTimerRunning == other.isTimerRunning &&
          moveCount == other.moveCount &&
          supportsHints == other.supportsHints &&
          hintHighlight == other.hintHighlight &&
          isShowingConflicts == other.isShowingConflicts &&
          const SetEquality<int>().equals(
            conflictingCells,
            other.conflictingCells,
          ) &&
          _historyEquality.equals(moveHistory, other.moveHistory);

  @override
  int get hashCode => Object.hash(
    puzzle,
    board,
    elapsed,
    isSolved,
    isTimerRunning,
    moveCount,
    supportsHints,
    hintHighlight,
    _historyEquality.hash(moveHistory),
  );
}

@immutable
class PuzzleMoveRecord {
  const PuzzleMoveRecord({
    required this.index,
    required this.move,
    required this.timestamp,
  });

  final int index;
  final Object? move;
  final DateTime timestamp;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PuzzleMoveRecord &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          move == other.move &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(index, move, timestamp);
}

@immutable
class PuzzleSolvedEvent {
  PuzzleSolvedEvent({
    required this.puzzle,
    required this.board,
    required this.elapsed,
    required this.moveCount,
    required List<PuzzleMoveRecord> moveHistory,
    this.completionStatus,
  }) : moveHistory = UnmodifiableListView<PuzzleMoveRecord>(moveHistory);

  final core.GeneratedPuzzle<dynamic> puzzle;
  final Object? board;
  final Duration elapsed;
  final int moveCount;
  final UnmodifiableListView<PuzzleMoveRecord> moveHistory;
  final PuzzleCompletionStatus? completionStatus;
}

@immutable
class PuzzlePlaySession {
  const PuzzlePlaySession({
    required this.engine,
    required this.puzzle,
    required this.puzzleType,
    required this.mode,
    required this.difficulty,
    this.validator,
    this.onSolved,
  });

  final core.PuzzleEngine<dynamic, dynamic> engine;
  final core.GeneratedPuzzle<dynamic> puzzle;
  final PuzzleType puzzleType;
  final PuzzleMode mode;
  final String difficulty;
  final core.PuzzleValidator<dynamic>? validator;
  final void Function(PuzzleSolvedEvent event)? onSolved;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PuzzlePlaySession &&
          runtimeType == other.runtimeType &&
          puzzle == other.puzzle &&
          identical(engine, other.engine) &&
          puzzleType == other.puzzleType &&
          mode == other.mode &&
          difficulty == other.difficulty &&
          validator == other.validator &&
          onSolved == other.onSolved;

  @override
  int get hashCode => Object.hash(
    puzzle,
    identityHashCode(engine),
    puzzleType,
    mode,
    difficulty,
    validator,
    onSolved,
  );
}

class _HistoryEntry {
  _HistoryEntry({
    required this.move,
    required this.previousState,
    required this.resultingState,
    required this.timestamp,
  });

  final Object? move;
  final Object? previousState;
  final Object? resultingState;
  final DateTime timestamp;

  PuzzleMoveRecord toRecord(int index) =>
      PuzzleMoveRecord(index: index, move: move, timestamp: timestamp);
}
