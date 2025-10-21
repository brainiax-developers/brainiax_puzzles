import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

import '../../shared/models/models.dart';
import '../../shared/providers/puzzle_local_store_providers.dart';

const Duration _tickInterval = Duration(milliseconds: 200);
const Duration _hintHighlightDuration = Duration(seconds: 3);

/// Provider for the puzzle play view model.
final puzzlePlayViewModelProvider =
    AutoDisposeNotifierProviderFamily<PuzzlePlayViewModel, PuzzlePlayState,
        PuzzlePlaySession>(PuzzlePlayViewModel.new);

/// View model responsible for managing puzzle play state including timer,
/// move history, undo, restart, and solve detection.
class PuzzlePlayViewModel extends AutoDisposeNotifier<PuzzlePlayState> {
  PuzzlePlayViewModel();

  final Stopwatch _stopwatch = Stopwatch();
  final List<_HistoryEntry> _history = <_HistoryEntry>[];

  late PuzzlePlaySession _session;
  core.PuzzleValidator<dynamic>? _validator;
  Timer? _ticker;
  bool _solvedEmitted = false;
  Timer? _hintClearTimer;
  int _hintRequestCount = 0;

  @override
  PuzzlePlayState build(PuzzlePlaySession session) {
    _session = session;
    _validator = session.validator ?? _deriveValidator(session.engine);
    _history.clear();
    _ticker?.cancel();
    _ticker = null;
    _stopwatch
      ..stop()
      ..reset();
    _cancelHintTimer();
    _hintRequestCount = 0;

    final Object? initialBoard = session.puzzle.state;
    final bool initiallySolved = _isSolved(initialBoard);
    _solvedEmitted = initiallySolved;

    state = PuzzlePlayState(
      puzzle: session.puzzle,
      board: initialBoard,
      elapsed: Duration.zero,
      isSolved: initiallySolved,
      isTimerRunning: false,
      moveHistory: const <PuzzleMoveRecord>[],
      moveCount: 0,
      supportsHints: session.engine.capabilities.supportsHints,
      hintHighlight: null,
    );

    if (!initiallySolved) {
      _startTimer();
    }

    ref.onDispose(_disposeTimer);
    ref.onDispose(_disposeHintHighlight);

    return state;
  }

  /// Apply a move to the puzzle. Throws [StateError] if the move is invalid or
  /// if the puzzle has already been solved.
  void applyMove(dynamic move) {
    if (state.isSolved) {
      throw StateError('Cannot apply moves when the puzzle is solved.');
    }

    final Object? currentBoard = state.board;
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

  /// Undo the most recent move if available.
  void undo() {
    if (_history.isEmpty) {
      return;
    }

    _history.removeLast();
    final Object? board =
        _history.isEmpty ? _session.puzzle.state : _history.last.resultingState;

    final bool solved = _isSolved(board);
    final bool hadHintHighlight = state.hintHighlight != null;
    if (hadHintHighlight) {
      _cancelHintTimer();
    }
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
    state = state.copyWith(
      hintHighlight: hint,
    );
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

    final PuzzleCompletionController controller =
        ref.read(puzzleCompletionControllerProvider);
    final PuzzleCompletionStatus completionStatus =
        await controller.recordCompletion(
      puzzleType: _session.puzzleType,
      difficulty: _session.difficulty,
      completionTime: state.elapsed,
      mode: _session.mode,
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
      core.PuzzleEngine<dynamic, dynamic> engine) {
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
    this.hintHighlight,
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
  const PuzzleSolvedEvent({
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

  PuzzleMoveRecord toRecord(int index) => PuzzleMoveRecord(
        index: index,
        move: move,
        timestamp: timestamp,
      );
}
