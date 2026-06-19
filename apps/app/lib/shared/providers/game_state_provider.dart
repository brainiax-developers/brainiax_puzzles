import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart';
import '../services/generation_isolate.dart';
import '../models/puzzle_input_moves.dart';
import 'engine_provider.dart';

/// Provider for current game state.
final gameStateProvider = NotifierProvider<GameStateNotifier, GameState?>(() {
  return GameStateNotifier();
});

/// Game state notifier that handles puzzle state, moves, and undo/redo.
class GameStateNotifier extends Notifier<GameState?> {
  final List<GameAction> _actionHistory = [];
  int _currentActionIndex = -1;
  GeneratedPuzzle? _initialPuzzle;
  Map<int, Set<int>> _initialNotes = const <int, Set<int>>{};

  @override
  GameState? build() => null;

  /// Start a new game with the specified engine and parameters.
  Future<void> startNewGame({
    required String engineId,
    required String seed,
    required String difficulty,
    required String size,
  }) async {
    final engine = ref.read(engineProvider(engineId));
    if (engine == null) {
      throw Exception('Engine not found: $engineId');
    }
    final Stopwatch stopwatch = Stopwatch()..start();

    // Parse parameters
    final difficultyScore = _parseDifficulty(difficulty);
    final sizeOpt = engineId == 'killer_queens'
        ? killerQueensAppSizeForDifficulty(difficulty)
        : _parseSize(size);
    final seed64 = Seed.fromString(seed);

    // Generate puzzle on a background isolate to keep UI responsive.
    final Duration timeout = puzzleGenerationTimeoutFor(
      engineId: engineId,
      difficulty: difficulty,
    );
    final puzzle = await ref
        .read(puzzleGenerationWorkerProvider)
        .generate(
          PuzzleGenerationRequest(
            engineId: engineId,
            seedStr: seed,
            seed64: seed64,
            size: sizeOpt,
            difficulty: difficultyScore,
          ),
          timeout: timeout,
        );
    stopwatch.stop();

    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[GameState][NewGame] engine=$engineId seed=$seed '
        'difficulty=$difficulty size=$size elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
    }

    // Create game state
    final gameState = GameState(
      engineId: engineId,
      seed: seed,
      difficulty: difficulty,
      size: sizeOpt.id,
      puzzle: puzzle,
      isSolved: false,
      startTime: DateTime.now(),
    );

    // Reset action history
    _actionHistory.clear();
    _currentActionIndex = -1;
    _initialPuzzle = puzzle;
    _initialNotes = const <int, Set<int>>{};

    state = gameState;
  }

  /// Initialize the game state from an existing generated puzzle instance.
  ///
  /// This avoids re-generating the puzzle on-device and preserves the provided
  /// puzzle as the initial puzzle for undo/redo reconstruction.
  Future<void> startWithGeneratedPuzzle({
    required String engineId,
    required String seed,
    required String difficulty,
    required String size,
    required GeneratedPuzzle puzzle,
    Map<int, Set<int>> notes = const <int, Set<int>>{},
  }) async {
    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[GameState][RestoreOrReplace] engine=$engineId seed=$seed '
        'difficulty=$difficulty size=$size',
      );
    }
    // Reset action history
    _actionHistory.clear();
    _currentActionIndex = -1;
    _initialPuzzle = puzzle;
    _initialNotes = _copyNotes(notes);

    final gameState = GameState(
      engineId: engineId,
      seed: seed,
      difficulty: difficulty,
      size: size,
      puzzle: puzzle,
      isSolved: false,
      startTime: DateTime.now(),
      notes: _copyNotes(notes),
    );

    state = gameState;
  }

  /// Make a move in the current game.
  ///
  /// Returns true only when the move changed the board state. Rejected moves
  /// throw, and accepted no-op moves return false so UI stats stay honest.
  Future<bool> makeMove(dynamic move) async {
    if (state == null) return false;

    final engine = ref.read(engineProvider(state!.engineId));
    if (engine == null) return false;

    // Special handling for Killer Queens: allow invalid moves, check conflicts later
    if (state!.engineId == 'killer_queens') {
      return _makeKillerQueensMove(move, engine);
    }

    if (move is NonogramBatchMove) {
      return _makeNonogramBatchMove(move, engine);
    }

    // Validate move
    final result = engine.validateMove(
      currentState: state!.puzzle.state,
      move: move,
    );

    if (!result.isValid) {
      throw Exception('Invalid move: ${result.errorMessage}');
    }
    if (result.newState == null) {
      return false;
    }

    final Object newState = result.newState!;
    if (newState == state!.puzzle.state) {
      return false;
    }

    // Create move record
    final gameMoveAction = GameMoveAction(
      move: move,
      timestamp: DateTime.now(),
      actionIndex: _currentActionIndex + 1,
    );

    // Add to history (remove any actions after current index)
    if (_currentActionIndex < _actionHistory.length - 1) {
      _actionHistory.removeRange(
        _currentActionIndex + 1,
        _actionHistory.length,
      );
    }
    _actionHistory.add(gameMoveAction);
    _currentActionIndex = _actionHistory.length - 1;

    // Update state
    final newPuzzle = GeneratedPuzzle(
      state: newState,
      meta: state!.puzzle.meta,
      telemetry: state!.puzzle.telemetry,
    );

    final isSolved = engine.isSolved(newState);

    state = state!.copyWith(
      puzzle: newPuzzle,
      isSolved: isSolved,
      lastMoveTime: DateTime.now(),
    );
    return true;
  }

  Timer? _conflictCheckTimer;

  /// Handle Killer Queens moves (allow invalid moves, check conflicts after delay)
  Future<bool> _makeKillerQueensMove(dynamic move, PuzzleEngine engine) async {
    if (state == null) return false;

    final currentBoard = state!.puzzle.state as KillerQueensBoard;
    final KillerQueensBoard? updatedBoard = _applyKillerQueensMoveToBoard(
      currentBoard,
      move as KillerQueensMove,
    );
    if (updatedBoard == null || updatedBoard == currentBoard) {
      return false;
    }

    // Create move record
    final gameMoveAction = GameMoveAction(
      move: move,
      timestamp: DateTime.now(),
      actionIndex: _currentActionIndex + 1,
    );

    // Add to history
    if (_currentActionIndex < _actionHistory.length - 1) {
      _actionHistory.removeRange(
        _currentActionIndex + 1,
        _actionHistory.length,
      );
    }
    _actionHistory.add(gameMoveAction);
    _currentActionIndex = _actionHistory.length - 1;

    // Update state (clear any previous conflicts)
    final newPuzzle = GeneratedPuzzle(
      state: updatedBoard,
      meta: state!.puzzle.meta,
      telemetry: state!.puzzle.telemetry,
    );

    final isSolved = engine.isSolved(updatedBoard);

    state = state!.copyWith(
      puzzle: newPuzzle,
      isSolved: isSolved,
      lastMoveTime: DateTime.now(),
      conflictingCells: null,
      isShowingConflicts: false,
    );

    // Cancel any existing timer
    _conflictCheckTimer?.cancel();

    // Schedule conflict check after 2 seconds
    _conflictCheckTimer = Timer(const Duration(seconds: 2), () {
      _checkAndShowKillerQueensConflicts();
    });
    return true;
  }

  KillerQueensBoard? _applyKillerQueensMoveToBoard(
    KillerQueensBoard board,
    KillerQueensMove move,
  ) {
    if (move.row < 0 ||
        move.row >= board.size ||
        move.col < 0 ||
        move.col >= board.size) {
      throw RangeError('Cell out of range');
    }
    if (move.value < 0 || move.value > 2) {
      throw ArgumentError('Value must be 0, 1, or 2');
    }

    final int index = board.indexFor(move.row, move.col);
    if (board.fixed[index]) {
      return null;
    }

    final List<int> updatedCells = List<int>.from(board.cells);
    bool changed = false;

    void setCellIfChanged(int cellIndex, int value) {
      if (updatedCells[cellIndex] == value) {
        return;
      }
      updatedCells[cellIndex] = value;
      changed = true;
    }

    if (move.value == 1) {
      setCellIfChanged(index, 1);

      void crossIfAllowed(int row, int col) {
        if (row < 0 || row >= board.size || col < 0 || col >= board.size) {
          return;
        }
        final int cellIndex = board.indexFor(row, col);
        if (cellIndex == index ||
            board.fixed[cellIndex] ||
            updatedCells[cellIndex] == 1) {
          return;
        }
        setCellIfChanged(cellIndex, 2);
      }

      for (int col = 0; col < board.size; col++) {
        crossIfAllowed(move.row, col);
      }
      for (int row = 0; row < board.size; row++) {
        crossIfAllowed(row, move.col);
      }
      for (final int dr in const <int>[-1, 1]) {
        for (final int dc in const <int>[-1, 1]) {
          crossIfAllowed(move.row + dr, move.col + dc);
        }
      }
    } else if (move.value == 2) {
      if (updatedCells[index] == 1) {
        return null;
      }
      setCellIfChanged(index, 2);
    } else {
      setCellIfChanged(index, 0);
    }

    if (!changed) {
      return null;
    }

    return KillerQueensBoard(
      size: board.size,
      cells: updatedCells,
      fixed: board.fixed,
      cages: board.cages,
    );
  }

  Future<bool> _makeNonogramBatchMove(
    NonogramBatchMove move,
    PuzzleEngine engine,
  ) async {
    if (state == null || move.isEmpty) return false;
    if (state!.puzzle.state is! NonogramBoard) return false;

    NonogramBoard workingBoard = state!.puzzle.state as NonogramBoard;
    bool changed = false;

    for (final NonogramMove cellMove in move.moves) {
      final result = engine.validateMove(
        currentState: workingBoard,
        move: cellMove,
      );
      if (!result.isValid) {
        throw Exception('Invalid move: ${result.errorMessage}');
      }
      if (result.newState == null || result.newState == workingBoard) {
        continue;
      }
      workingBoard = result.newState as NonogramBoard;
      changed = true;
    }

    if (!changed) {
      return false;
    }

    final gameMoveAction = GameMoveAction(
      move: move,
      timestamp: DateTime.now(),
      actionIndex: _currentActionIndex + 1,
    );

    if (_currentActionIndex < _actionHistory.length - 1) {
      _actionHistory.removeRange(
        _currentActionIndex + 1,
        _actionHistory.length,
      );
    }
    _actionHistory.add(gameMoveAction);
    _currentActionIndex = _actionHistory.length - 1;

    final newPuzzle = GeneratedPuzzle(
      state: workingBoard,
      meta: state!.puzzle.meta,
      telemetry: state!.puzzle.telemetry,
    );

    final isSolved = engine.isSolved(workingBoard);

    state = state!.copyWith(
      puzzle: newPuzzle,
      isSolved: isSolved,
      lastMoveTime: DateTime.now(),
    );
    return true;
  }

  /// Check for Killer Queens conflicts and trigger haptic feedback
  void _checkAndShowKillerQueensConflicts() {
    if (state == null || state!.engineId != 'killer_queens') return;

    final conflicts = _findKillerQueensConflicts();

    if (conflicts.isNotEmpty) {
      // Trigger haptic feedback
      _triggerHapticFeedback();

      // Update state with conflicts
      state = state!.copyWith(
        conflictingCells: conflicts,
        isShowingConflicts: true,
      );
    }
  }

  /// Find all conflicting queens in Killer Queens puzzle
  Set<int> _findKillerQueensConflicts() {
    if (state == null || state!.puzzle.state is! KillerQueensBoard) {
      return {};
    }

    final board = state!.puzzle.state as KillerQueensBoard;
    final conflicts = <int>{};

    // Find all queen positions
    final queens = <int>[];
    for (int i = 0; i < board.cells.length; i++) {
      if (board.cells[i] == 1) {
        queens.add(i);
      }
    }

    // Check each queen against all others
    for (int i = 0; i < queens.length; i++) {
      final pos1 = queens[i];
      final row1 = pos1 ~/ board.size;
      final col1 = pos1 % board.size;
      final cage1 = board.cageByCell[pos1];

      for (int j = i + 1; j < queens.length; j++) {
        final pos2 = queens[j];
        final row2 = pos2 ~/ board.size;
        final col2 = pos2 % board.size;
        final cage2 = board.cageByCell[pos2];

        // Check if they conflict
        if (row1 == row2 || // Same row
            col1 == col2 || // Same column
            cage1 == cage2 || // Same cage
            (row2 - row1).abs() == (col2 - col1).abs() && // Diagonal
                (row2 - row1).abs() == 1) {
          // Adjacent diagonal
          conflicts.add(pos1);
          conflicts.add(pos2);
        }
      }
    }

    return conflicts;
  }

  /// Trigger haptic feedback
  void _triggerHapticFeedback() {
    try {
      // Using medium impact for conflict feedback
      // Note: This will be imported from Flutter services
      HapticFeedback.mediumImpact();
    } catch (_) {
      // Ignore if haptic feedback is not available
    }
  }

  /// Undo the last action.
  void undo() {
    if (state == null || _currentActionIndex < 0) return;

    _currentActionIndex--;
    _reconstructState();

    // Cancel conflict timer and clear conflicts on undo
    _conflictCheckTimer?.cancel();
    if (state != null && state!.engineId == 'killer_queens') {
      state = state!.copyWith(
        conflictingCells: null,
        isShowingConflicts: false,
      );
    }
  }

  /// Redo the next action.
  void redo() {
    if (state == null || _currentActionIndex >= _actionHistory.length - 1) {
      return;
    }

    _currentActionIndex++;
    _reconstructState();
  }

  /// Check if undo is possible.
  bool get canUndo => state != null && _currentActionIndex >= 0;

  /// Check if redo is possible.
  bool get canRedo =>
      state != null && _currentActionIndex < _actionHistory.length - 1;

  /// Get current action index.
  int get currentActionIndex => _currentActionIndex;

  /// Backward-compatible alias for older tests and callers.
  int get currentMoveIndex => currentActionIndex;

  /// Get action history.
  List<GameAction> get actionHistory => List.unmodifiable(_actionHistory);

  /// Backward-compatible alias for older tests and callers.
  List<GameAction> get moveHistory => actionHistory;

  /// Record a note action (adding/removing a note from a cell).
  void recordNoteAction(int cellIndex, int digit, bool isAdding) {
    if (state == null) return;

    final noteAction = NoteAction(
      timestamp: DateTime.now(),
      actionIndex: _currentActionIndex + 1,
      cellIndex: cellIndex,
      digit: digit,
      isAdding: isAdding,
    );

    // Add to history (remove any actions after current index)
    if (_currentActionIndex < _actionHistory.length - 1) {
      _actionHistory.removeRange(
        _currentActionIndex + 1,
        _actionHistory.length,
      );
    }
    _actionHistory.add(noteAction);
    _currentActionIndex = _actionHistory.length - 1;

    // Update game state with new notes
    final newNotes = Map<int, Set<int>>.from(state!.notes);
    final Set<int> notes = Set<int>.from(newNotes[cellIndex] ?? const <int>{});
    if (isAdding) {
      notes.add(digit);
    } else {
      notes.remove(digit);
    }
    if (notes.isEmpty) {
      newNotes.remove(cellIndex);
    } else {
      newNotes[cellIndex] = notes;
    }

    state = state!.copyWith(notes: newNotes);
  }

  /// Clear all notes for a cell.
  void clearNotesForCell(int cellIndex, {bool recordHistory = true}) {
    if (state == null) return;

    final currentNotes = state!.notes[cellIndex];
    if (currentNotes == null || currentNotes.isEmpty) return;

    if (recordHistory) {
      // Create note actions for removing each note
      for (final digit in currentNotes) {
        final noteAction = NoteAction(
          timestamp: DateTime.now(),
          actionIndex: _currentActionIndex + 1,
          cellIndex: cellIndex,
          digit: digit,
          isAdding: false,
        );

        // Add to history (remove any actions after current index)
        if (_currentActionIndex < _actionHistory.length - 1) {
          _actionHistory.removeRange(
            _currentActionIndex + 1,
            _actionHistory.length,
          );
        }
        _actionHistory.add(noteAction);
        _currentActionIndex = _actionHistory.length - 1;
      }
    }

    // Update game state
    final newNotes = Map<int, Set<int>>.from(state!.notes);
    newNotes.remove(cellIndex);
    state = state!.copyWith(notes: newNotes);
  }

  void restoreNotes(Map<int, Set<int>> notes) {
    if (state == null) return;
    final Map<int, Set<int>> copied = _copyNotes(notes);
    if (_actionHistory.isEmpty) {
      _initialNotes = copied;
    }
    state = state!.copyWith(notes: copied);
  }

  Map<int, Set<int>> _copyNotes(Map<int, Set<int>> notes) {
    final Map<int, Set<int>> copied = <int, Set<int>>{};
    notes.forEach((int index, Set<int> digits) {
      if (digits.isNotEmpty) {
        copied[index] = Set<int>.from(digits);
      }
    });
    return copied;
  }

  /// Clean up Sudoku pencil marks after a real digit is placed.
  void cleanupSudokuNotesForPlacement({
    required int row,
    required int col,
    required int digit,
  }) {
    if (state == null || digit <= 0) return;
    if (state!.puzzle.state is! SudokuBoard || state!.notes.isEmpty) return;

    final int placedIndex = row * SudokuBoard.side + col;
    final Set<int> peers = SudokuBoard.peersOfIndex(placedIndex).toSet();
    final Map<int, Set<int>> newNotes = <int, Set<int>>{};

    state!.notes.forEach((int index, Set<int> notes) {
      if (index == placedIndex) {
        return;
      }
      final Set<int> updated = Set<int>.from(notes);
      if (peers.contains(index)) {
        updated.remove(digit);
      }
      if (updated.isNotEmpty) {
        newNotes[index] = updated;
      }
    });

    state = state!.copyWith(notes: newNotes);
  }

  /// Reconstruct state from action history.
  void _reconstructState() {
    if (state == null) return;

    final engine = ref.read(engineProvider(state!.engineId));
    if (engine == null) return;
    final basePuzzle = _initialPuzzle ?? state!.puzzle;

    var currentPuzzle = basePuzzle;
    var currentNotes = _copyNotes(_initialNotes);
    var isSolved = engine.isSolved(currentPuzzle.state);

    // Apply actions up to current index
    for (int i = 0; i <= _currentActionIndex; i++) {
      final action = _actionHistory[i];

      if (action is GameMoveAction) {
        Object? newState;
        if (state!.engineId == 'killer_queens' &&
            currentPuzzle.state is KillerQueensBoard &&
            action.move is KillerQueensMove) {
          newState = _applyKillerQueensMoveToBoard(
            currentPuzzle.state as KillerQueensBoard,
            action.move as KillerQueensMove,
          );
        } else if (action.move is NonogramBatchMove &&
            currentPuzzle.state is NonogramBoard) {
          var workingBoard = currentPuzzle.state as NonogramBoard;
          bool changed = false;
          for (final NonogramMove cellMove
              in (action.move as NonogramBatchMove).moves) {
            final result = engine.validateMove(
              currentState: workingBoard,
              move: cellMove,
            );
            if (result.isValid &&
                result.newState != null &&
                result.newState != workingBoard) {
              workingBoard = result.newState as NonogramBoard;
              changed = true;
            }
          }
          if (changed) {
            newState = workingBoard;
          }
        } else {
          final result = engine.validateMove(
            currentState: currentPuzzle.state,
            move: action.move,
          );
          if (result.isValid && result.newState != null) {
            newState = result.newState!;
          }
        }

        if (newState != null) {
          currentPuzzle = GeneratedPuzzle(
            state: newState,
            meta: currentPuzzle.meta,
            telemetry: currentPuzzle.telemetry,
          );
          isSolved = engine.isSolved(newState);

          // Clear notes for the cell that was filled
          if (action.move is Map<String, dynamic>) {
            final moveMap = action.move as Map<String, dynamic>;
            if (moveMap.containsKey('row') && moveMap.containsKey('col')) {
              final row = moveMap['row'] as int;
              final col = moveMap['col'] as int;
              // Calculate cell index based on puzzle type
              final cellIndex = _calculateCellIndex(
                currentPuzzle.state,
                row,
                col,
              );
              if (cellIndex != null) {
                currentNotes.remove(cellIndex);
              }
            }
          }
        }
      } else if (action is NoteAction) {
        // Apply note change
        final notes = Set<int>.from(
          currentNotes[action.cellIndex] ?? const <int>{},
        );
        if (action.isAdding) {
          notes.add(action.digit);
        } else {
          notes.remove(action.digit);
        }
        if (notes.isEmpty) {
          currentNotes.remove(action.cellIndex);
        } else {
          currentNotes[action.cellIndex] = notes;
        }
      }
    }

    state = state!.copyWith(
      puzzle: currentPuzzle,
      notes: currentNotes,
      isSolved: isSolved,
    );
  }

  /// Calculate cell index for a given row/col based on puzzle type.
  int? _calculateCellIndex(dynamic puzzleState, int row, int col) {
    if (puzzleState is SudokuBoard) {
      return (row * SudokuBoard.side + col).toInt();
    } else if (puzzleState is KakuroBoard) {
      return (row * puzzleState.width + col).toInt();
    }
    return null;
  }

  /// Reset the game to the initial generated puzzle, clearing all moves.
  void resetToInitial() {
    if (_initialPuzzle == null || state == null) return;

    final engine = ref.read(engineProvider(state!.engineId));
    if (engine == null) return;

    // Clear history and restore initial puzzle
    _actionHistory.clear();
    _currentActionIndex = -1;
    _initialNotes = const <int, Set<int>>{};

    final bool isSolved = engine.isSolved(_initialPuzzle!.state);

    state = state!.copyWith(
      puzzle: _initialPuzzle!,
      notes: const <int, Set<int>>{},
      isSolved: isSolved,
      startTime: DateTime.now(),
      lastMoveTime: null,
    );
  }

  /// Save game state to JSON.
  Map<String, dynamic> toJson() {
    if (state == null) return {};

    return {
      'gameState': state!.toJson(),
      'actionHistory': _actionHistory.map((action) => action.toJson()).toList(),
      'currentActionIndex': _currentActionIndex,
    };
  }

  /// Load game state from JSON.
  Future<void> loadFromJson(Map<String, dynamic> json) async {
    if (!json.containsKey('gameState')) return;

    final gameState = GameState.fromJson(json['gameState']);
    final actionHistory =
        (json['actionHistory'] as List?)
            ?.map((actionJson) => GameAction.fromJson(actionJson))
            .toList() ??
        [];
    final currentActionIndex = json['currentActionIndex'] as int? ?? -1;

    _actionHistory.clear();
    _actionHistory.addAll(actionHistory);
    _currentActionIndex = currentActionIndex;
    _initialPuzzle = gameState.puzzle;
    _initialNotes = _copyNotes(gameState.notes);

    state = gameState;
  }

  /// Parse difficulty string to DifficultyScore.
  DifficultyScore _parseDifficulty(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const DifficultyScore(value: 0.3, level: 'easy');
      case 'medium':
        return const DifficultyScore(value: 0.6, level: 'medium');
      case 'hard':
        return const DifficultyScore(value: 0.9, level: 'hard');
      case 'expert':
        return const DifficultyScore(value: 1.2, level: 'expert');
      default:
        return const DifficultyScore(value: 0.6, level: 'medium');
    }
  }

  /// Parse size string to SizeOpt.
  SizeOpt _parseSize(String size) {
    final parts = size.split('x');
    if (parts.length != 2) {
      throw ArgumentError('Invalid size format: $size');
    }
    final width = int.parse(parts[0]);
    final height = int.parse(parts[1]);

    return SizeOpt(id: size, description: size, width: width, height: height);
  }

  /// Request a gameplay hint from the engine for the current game state.
  ///
  /// Returns a [PuzzleHint] if the active engine supports hints and a hint
  /// could be produced, or `null` otherwise. This method is async to
  /// allow engines to perform any internal work (even though current
  /// implementations may be synchronous).
  Future<PuzzleHint?> requestHint({PuzzleHintRequest? request}) async {
    if (state == null) return null;

    final engine = ref.read(engineProvider(state!.engineId));
    if (engine == null) return null;

    // If engine advertises no hint capability, bail out early.
    if (!engine.capabilities.supportsHints) return null;

    try {
      final hint = engine.requestHint(
        currentState: state!.puzzle.state,
        request: request,
      );
      return hint;
    } catch (e) {
      // Swallow errors - hint is a best-effort feature.
      return null;
    }
  }

  /// Clears the active game when it does not match the requested route key.
  ///
  /// This is used by daily navigation to avoid rendering stale puzzles while
  /// a new daily puzzle is still loading.
  void clearIfMismatched({required String engineId, String? seed}) {
    final GameState? current = state;
    if (current == null) {
      return;
    }
    final bool mismatchedEngine = current.engineId != engineId;
    final bool mismatchedSeed = seed != null && current.seed != seed;
    if (!mismatchedEngine && !mismatchedSeed) {
      return;
    }
    _actionHistory.clear();
    _currentActionIndex = -1;
    _initialPuzzle = null;
    _initialNotes = const <int, Set<int>>{};
    state = null;
  }
}

/// Game state containing puzzle and game information.
class GameState {
  final String engineId;
  final String seed;
  final String difficulty;
  final String size;
  final GeneratedPuzzle puzzle;
  final bool isSolved;
  final DateTime startTime;
  final DateTime? lastMoveTime;
  final Map<int, Set<int>> notes;
  final Set<int>? conflictingCells;
  final bool isShowingConflicts;

  const GameState({
    required this.engineId,
    required this.seed,
    required this.difficulty,
    required this.size,
    required this.puzzle,
    required this.isSolved,
    required this.startTime,
    this.lastMoveTime,
    this.notes = const <int, Set<int>>{},
    this.conflictingCells,
    this.isShowingConflicts = false,
  });

  GameState copyWith({
    String? engineId,
    String? seed,
    String? difficulty,
    String? size,
    GeneratedPuzzle? puzzle,
    bool? isSolved,
    DateTime? startTime,
    DateTime? lastMoveTime,
    Map<int, Set<int>>? notes,
    Set<int>? conflictingCells,
    bool? isShowingConflicts,
  }) {
    return GameState(
      engineId: engineId ?? this.engineId,
      seed: seed ?? this.seed,
      difficulty: difficulty ?? this.difficulty,
      size: size ?? this.size,
      puzzle: puzzle ?? this.puzzle,
      isSolved: isSolved ?? this.isSolved,
      startTime: startTime ?? this.startTime,
      lastMoveTime: lastMoveTime ?? this.lastMoveTime,
      notes: notes ?? this.notes,
      conflictingCells: conflictingCells ?? this.conflictingCells,
      isShowingConflicts: isShowingConflicts ?? this.isShowingConflicts,
    );
  }

  Map<String, dynamic> toJson() => {
    'engineId': engineId,
    'seed': seed,
    'difficulty': difficulty,
    'size': size,
    'puzzle': puzzle.toJson(),
    'isSolved': isSolved,
    'startTime': startTime.toIso8601String(),
    'lastMoveTime': lastMoveTime?.toIso8601String(),
    'notes': notes.map(
      (key, value) => MapEntry(key.toString(), value.toList()),
    ),
  };

  factory GameState.fromJson(Map<String, dynamic> json) {
    // Note: This is a simplified version. In practice, you'd need
    // to properly deserialize the puzzle based on the engine type
    throw UnimplementedError('GameState.fromJson needs proper implementation');
  }
}

/// Abstract base class for all game actions (moves and note changes).
abstract class GameAction {
  final DateTime timestamp;
  final int actionIndex;

  const GameAction({required this.timestamp, required this.actionIndex});

  Map<String, dynamic> toJson();
  factory GameAction.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'move':
        return GameMoveAction.fromJson(json);
      case 'note':
        return NoteAction.fromJson(json);
      default:
        throw UnsupportedError('Unknown action type: $type');
    }
  }
}

/// Action representing a move (filling a cell).
class GameMoveAction extends GameAction {
  final dynamic move;

  const GameMoveAction({
    required super.timestamp,
    required super.actionIndex,
    required this.move,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'move',
    'timestamp': timestamp.toIso8601String(),
    'actionIndex': actionIndex,
    'move': _moveToJson(move),
  };

  factory GameMoveAction.fromJson(Map<String, dynamic> json) {
    return GameMoveAction(
      timestamp: DateTime.parse(json['timestamp']),
      actionIndex: json['actionIndex'] as int,
      move: json['move'], // Simplified - would need proper deserialization
    );
  }

  /// Convert move to JSON (simplified).
  Map<String, dynamic> _moveToJson(dynamic move) {
    if (move is Map<String, dynamic>) {
      return move;
    }
    // Try to call toJson if the move has it
    try {
      return (move as dynamic).toJson() as Map<String, dynamic>;
    } catch (e) {
      return {'type': move.runtimeType.toString()};
    }
  }
}

/// Action representing a note change (adding/removing a note from a cell).
class NoteAction extends GameAction {
  final int cellIndex;
  final int digit;
  final bool isAdding; // true for adding note, false for removing

  const NoteAction({
    required super.timestamp,
    required super.actionIndex,
    required this.cellIndex,
    required this.digit,
    required this.isAdding,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'note',
    'timestamp': timestamp.toIso8601String(),
    'actionIndex': actionIndex,
    'cellIndex': cellIndex,
    'digit': digit,
    'isAdding': isAdding,
  };

  factory NoteAction.fromJson(Map<String, dynamic> json) {
    return NoteAction(
      timestamp: DateTime.parse(json['timestamp']),
      actionIndex: json['actionIndex'] as int,
      cellIndex: json['cellIndex'] as int,
      digit: json['digit'] as int,
      isAdding: json['isAdding'] as bool,
    );
  }
}
