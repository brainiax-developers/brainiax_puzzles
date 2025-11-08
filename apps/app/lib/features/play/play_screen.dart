import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/providers/game_state_provider.dart';
import '../../shared/providers/engine_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/providers/haptics_provider.dart';
import '../../shared/services/puzzle_registry.dart';
import '../../shared/providers/puzzle_local_store_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/services/puzzle_progress_service.dart';

/// Screen for playing a specific puzzle type in a specific mode.
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({
    super.key,
    required this.puzzleType,
    required this.mode,
    this.puzzleInstance,
    this.difficulty,
  });

  final PuzzleType puzzleType;
  final PuzzleMode mode;
  final dynamic puzzleInstance;
  final String? difficulty;

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen>
    with TickerProviderStateMixin {
  late AnimationController _timerController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _hintController;
  double _hintAnimationValue = 0.0;
  List<Offset> _hintPositions = [];

  Duration _elapsedTime = Duration.zero;
  bool _isPlaying = true;
  bool _isPaused = false;
  String _solveStatus = 'In Progress';
  int _hintsUsed = 0;
  int _movesCount = 0;
  bool _hasRecordedCompletion = false;
  PuzzleCompletionStatus? _completionStatus;
  // Guard to ensure we only register Riverpod listeners once
  bool _listenersRegistered = false;

  // Remember the last logged puzzle so we don't spam logs on every rebuild
  core.GeneratedPuzzle? _lastLoggedPuzzle;
  Offset? _selectedSudokuCell;
  bool _isNoteMode = false;
  bool _isCrossMode = false;
  final Set<int> _sudokuHintFilled = <int>{};
  bool _shownSolvedDialog = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startTimer();

    // If no puzzle instance was passed and there's no active game state,
    // auto-start a new random game for Random mode so the canvas is populated.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final currentState = ref.read(gameStateProvider);
        final engineAvailable = ref.read(engineProvider(widget.puzzleType.key)) != null;

        // If a generated puzzle instance was passed via navigation extras, use it.
        // Replace any existing game state if the seed differs, so Random Play
        // always shows the newly generated puzzle.
        if (widget.puzzleInstance != null && engineAvailable) {
          try {
            final core.GeneratedPuzzle generated = widget.puzzleInstance as core.GeneratedPuzzle;
            final String newSeed = generated.meta.seedStr;
            final String? existingSeed = currentState?.puzzle.meta.seedStr;
            if (currentState == null || existingSeed != newSeed) {
              final String difficulty = generated.meta.difficulty.level;
              final String size = generated.meta.size.id;
              await ref.read(gameStateProvider.notifier).startWithGeneratedPuzzle(
                engineId: widget.puzzleType.key,
                seed: newSeed,
                difficulty: difficulty,
                size: size,
                puzzle: generated,
              );
              // Persist in-progress puzzle
              try {
                final prefs = await SharedPreferences.getInstance();
                final progress = PuzzleProgressService(prefs);
                await progress.save(widget.puzzleType, generated);
              } catch (_) {}
              // Log once after we've set up the game state
              _logPuzzleInfoIfNeeded(ref.read(gameStateProvider));
              return;
            }
          } catch (e) {
            // If casting or initialization fails, fall back to generation below
          }
        }

        if (widget.mode == PuzzleMode.random && widget.puzzleInstance == null && currentState == null && engineAvailable) {
          // Build a deterministic-ish random seed string and sensible defaults
          final seed = 'random:${widget.puzzleType.key}:${DateTime.now().millisecondsSinceEpoch}';
          const difficulty = 'medium';
          final size = _defaultSizeForPuzzleType(widget.puzzleType);

          // Fire-and-forget; startNewGame will populate the gameStateProvider
          await ref.read(gameStateProvider.notifier).startNewGame(
            engineId: widget.puzzleType.key,
            seed: seed,
            difficulty: difficulty,
            size: size,
          );
          // Save initial in-progress state
          try {
            final current = ref.read(gameStateProvider)?.puzzle;
            if (current != null) {
              final prefs = await SharedPreferences.getInstance();
              final progress = PuzzleProgressService(prefs);
              await progress.save(widget.puzzleType, current);
            }
          } catch (_) {}
        }
      } catch (e) {
        // Ignore startup errors - they'll be surfaced elsewhere if needed
      }

      // Log once after any generation attempt so we can diagnose which engine/puzzle was used
      _logPuzzleInfoIfNeeded(ref.read(gameStateProvider));
    });
  }

  @override
  void didUpdateWidget(covariant PlayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the navigation provided a different puzzle instance, log once to help debugging
    if (!identical(oldWidget.puzzleInstance, widget.puzzleInstance)) {
      _logPuzzleInfoIfNeeded(ref.read(gameStateProvider));
    }
  }

  void _logPuzzleInfoIfNeeded(GameState? gameState) {
    final core.GeneratedPuzzle? current = widget.puzzleInstance is core.GeneratedPuzzle
        ? widget.puzzleInstance as core.GeneratedPuzzle
        : gameState?.puzzle;

    if (identical(_lastLoggedPuzzle, current)) return;
    _lastLoggedPuzzle = current;

    if (!kDebugMode) return;
    // ignore: avoid_print
    print('PlayScreen: widget.puzzleInstance runtimeType = ${widget.puzzleInstance?.runtimeType}');
    // ignore: avoid_print
    print('PlayScreen: gameState runtimeType = ${gameState?.runtimeType}');
    // ignore: avoid_print
    print('PlayScreen: gameState?.puzzle runtimeType = ${gameState?.puzzle.runtimeType}');
  }

  // Provide default size strings for different puzzle types used when
  // launching a random puzzle without explicit size parameters.
  String _defaultSizeForPuzzleType(PuzzleType type) {
    final registry = PuzzleRegistry();
    registry.initialize();
    final meta = registry.getMetadata(type);
    if (meta != null && meta.supportedSizes.isNotEmpty) {
      return meta.supportedSizes.first;
    }
    // Fallbacks aligned with PuzzleGenerationController
    switch (type) {
      case PuzzleType.sudokuClassic:
        return '9x9';
      case PuzzleType.nonogramMono:
        return '10x10';
      case PuzzleType.kakuroClassic:
        return '8x8';
      case PuzzleType.slitherlinkLoop:
        return '7x7';
      case PuzzleType.mathdokuClassic:
        return '6x6';
      case PuzzleType.killerQueens:
        return '8x8';
      case PuzzleType.takuzuBinary:
        return '8x8';
    }
  }

  void _initializeAnimations() {
    _timerController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _timerController.addListener(_updateTimer);
    _hintController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _hintController.addListener(() {
      setState(() {
        _hintAnimationValue = _hintController.value;
      });
    });
  }

  void _startTimer() {
    if (_isPlaying && !_isPaused) {
      _timerController.repeat();
    }
  }

  void _updateTimer() {
    if (mounted) {
      setState(() {
        _elapsedTime = Duration(
          seconds: _timerController.value.round(),
        );
      });
      // Also listen specifically to the isSolved flag in case other changes
      // to GameState prevent the above listener from firing reliably in some
      // environments. This listener receives only the boolean and will call
      // the same completion handler.
      ref.listen<bool?>(
        gameStateProvider.select((s) => s?.isSolved),
        (prevSolved, nextSolved) async {
          if (kDebugMode) {
            // ignore: avoid_print
            print('PlayScreen.isSolved changed: prev=$prevSolved next=$nextSolved');
          }
          final bool was = prevSolved ?? false;
          final bool isNow = nextSolved ?? false;
          if (!was && isNow) {
            final GameState? gs = ref.read(gameStateProvider);
            if (gs != null) {
              unawaited(_handleCompletion(gs));
            }
          }
        },
      );
    }
  }

  // Pause/resume handled implicitly by navigation/state; explicit toggle removed.

  void _triggerHapticFeedback(HapticFeedbackType type) {
    // Guard haptics by user preference. Default to enabled while loading.
    final enabled = ref.read(hapticsEnabledProvider);
    if (!enabled) return;

    if (Platform.isAndroid || Platform.isIOS) {
      switch (type) {
        case HapticFeedbackType.light:
          HapticFeedback.lightImpact();
          break;
        case HapticFeedbackType.medium:
          HapticFeedback.mediumImpact();
          break;
        case HapticFeedbackType.heavy:
          HapticFeedback.heavyImpact();
          break;
        case HapticFeedbackType.selection:
          HapticFeedback.selectionClick();
          break;
      }
    }
  }

  void _useHint() {
    _triggerHapticFeedback(HapticFeedbackType.medium);

    final gameState = ref.read(gameStateProvider);
    if (gameState == null) return;
    final board = gameState.puzzle.state;

    if (board is core.SudokuBoard) {
      final hint = _computeSudokuHint(board);
      if (hint == null) {
        _showSnackBar('No hint available');
        return;
      }
      final move = core.SudokuMove(row: hint.row, col: hint.col, digit: hint.digit);
      ref.read(gameStateProvider.notifier).makeMove(move).then((_) async {
        setState(() {
          _sudokuHintFilled.add(hint.row * core.SudokuBoard.side + hint.col);
          _movesCount++;
        });
        await _incrementHintCountPersistent();
      }).catchError((_) {});
      return;
    }

    // Non-Sudoku: request engine-provided hint and flash highlight
    () async {
      try {
        final hint = await ref.read(gameStateProvider.notifier).requestHint(
          request: core.PuzzleHintRequest(
            iteration: _hintsUsed,
            moveCount: _movesCount,
          ),
        );
        if (hint == null || hint.isEmpty) {
          _showSnackBar('No hint available');
          return;
        }
        setState(() {
          _hintPositions = hint.cells
              .map((c) => Offset(c.column.toDouble(), c.row.toDouble()))
              .toList();
        });
        await _hintController.forward(from: 0.0);
        await _hintController.reverse();
        await Future.delayed(const Duration(milliseconds: 200));
        setState(() {
          _hintPositions = [];
          _hintAnimationValue = 0.0;
        });
        await _incrementHintCountPersistent();
      } catch (_) {}
    }();
  }

  Future<void> _incrementHintCountPersistent() async {
    setState(() {
      _hintsUsed++;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'hints_used:${widget.puzzleType.key}:${ref.read(gameStateProvider)?.puzzle.meta.seedStr}';
      final current = prefs.getInt(key) ?? 0;
      await prefs.setInt(key, current + 1);
    } catch (_) {}
  }

  ({int row, int col, int digit})? _computeSudokuHint(core.SudokuBoard board) {
    // Naked singles: candidates per cell
    for (int row = 0; row < core.SudokuBoard.side; row++) {
      for (int col = 0; col < core.SudokuBoard.side; col++) {
        if (board.cellAt(row, col) != 0) continue;
        final candidates = _sudokuCandidates(board, row, col);
        if (candidates.length == 1) {
          return (row: row, col: col, digit: candidates.first);
        }
      }
    }
    // Hidden singles in rows
    for (int row = 0; row < core.SudokuBoard.side; row++) {
      for (int digit = 1; digit <= 9; digit++) {
        if (_rowHasDigit(board, row, digit)) continue;
        final cells = <int>[];
        for (int col = 0; col < core.SudokuBoard.side; col++) {
          if (board.cellAt(row, col) != 0) continue;
          if (!_wouldCauseUnitConflict(board, row, col, digit)) {
            cells.add(col);
          }
        }
        if (cells.length == 1) return (row: row, col: cells.first, digit: digit);
      }
    }
    // Hidden singles in columns
    for (int col = 0; col < core.SudokuBoard.side; col++) {
      for (int digit = 1; digit <= 9; digit++) {
        if (_colHasDigit(board, col, digit)) continue;
        final cells = <int>[];
        for (int row = 0; row < core.SudokuBoard.side; row++) {
          if (board.cellAt(row, col) != 0) continue;
          if (!_wouldCauseUnitConflict(board, row, col, digit)) {
            cells.add(row);
          }
        }
        if (cells.length == 1) return (row: cells.first, col: col, digit: digit);
      }
    }
    // Hidden singles in boxes
    for (int br = 0; br < 3; br++) {
      for (int bc = 0; bc < 3; bc++) {
        final int startRow = br * 3;
        final int startCol = bc * 3;
        for (int digit = 1; digit <= 9; digit++) {
          if (_boxHasDigit(board, startRow, startCol, digit)) continue;
          int count = 0;
          int? tr;
          int? tc;
          for (int r = startRow; r < startRow + 3; r++) {
            for (int c = startCol; c < startCol + 3; c++) {
              if (board.cellAt(r, c) != 0) continue;
              if (!_wouldCauseUnitConflict(board, r, c, digit)) {
                count++;
                tr = r;
                tc = c;
              }
            }
          }
          if (count == 1 && tr != null && tc != null) {
            return (row: tr, col: tc, digit: digit);
          }
        }
      }
    }
    return null;
  }

  Set<int> _sudokuCandidates(core.SudokuBoard board, int row, int col) {
    final used = <int>{};
    for (final idx in core.SudokuBoard.rowIndices(row)) {
      final v = board.cells[idx];
      if (v != 0) used.add(v);
    }
    for (final idx in core.SudokuBoard.columnIndices(col)) {
      final v = board.cells[idx];
      if (v != 0) used.add(v);
    }
    for (final idx in core.SudokuBoard.boxIndices(row, col)) {
      final int r = idx ~/ core.SudokuBoard.side;
      final int c = idx % core.SudokuBoard.side;
      final v = board.cellAt(r, c);
      if (v != 0) used.add(v);
    }
    final candidates = <int>{};
    for (int d = 1; d <= 9; d++) {
      if (!used.contains(d)) candidates.add(d);
    }
    return candidates;
  }

  bool _rowHasDigit(core.SudokuBoard board, int row, int digit) {
    for (int c = 0; c < core.SudokuBoard.side; c++) {
      if (board.cellAt(row, c) == digit) return true;
    }
    return false;
  }

  bool _colHasDigit(core.SudokuBoard board, int col, int digit) {
    for (int r = 0; r < core.SudokuBoard.side; r++) {
      if (board.cellAt(r, col) == digit) return true;
    }
    return false;
  }

  bool _boxHasDigit(core.SudokuBoard board, int startRow, int startCol, int digit) {
    for (int r = startRow; r < startRow + 3; r++) {
      for (int c = startCol; c < startCol + 3; c++) {
        if (board.cellAt(r, c) == digit) return true;
      }
    }
    return false;
  }

  void _undoMove() {
    _triggerHapticFeedback(HapticFeedbackType.light);
    final notifier = ref.read(gameStateProvider.notifier);
    if (notifier.canUndo) {
      notifier.undo();
      // Reflect current move count based on history index
      final actions = notifier.actionHistory;
      final currentIndex = notifier.currentActionIndex;
      final moveCount = actions.sublist(0, currentIndex + 1).where((action) => action is GameMoveAction).length;
      setState(() {
        _movesCount = moveCount;
      });
    } else {
      _showSnackBar('Nothing to undo');
    }
  }

  void _restartPuzzle() {
    _triggerHapticFeedback(HapticFeedbackType.medium);
    showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return AlertDialog(
          title: const Text('Restart puzzle?'),
          content: const Text('This will reset the board to its initial state and clear your moves.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restart'),
            ),
          ],
        );
      },
    ).then((confirmed) {
      if (confirmed != true) return;

      // Reset provider state
      final notifier = ref.read(gameStateProvider.notifier);
      notifier.resetToInitial();

      // Reset local UI state
      setState(() {
        _elapsedTime = Duration.zero;
        _hintsUsed = 0;
        _movesCount = 0;
        _solveStatus = 'In Progress';
        _isPaused = false;
        _hasRecordedCompletion = false;
        _completionStatus = null;
        _selectedSudokuCell = null;
      });
      _timerController.reset();
      _startTimer();
    });
  }

  // Navigation actions (New/Back) removed from UI per UX request.

  Future<void> _recordCompletion(GameState gameState, Duration elapsed) async {
    try {
      final controller = ref.read(puzzleCompletionControllerProvider);
      final status = await controller.recordCompletion(
        puzzleType: widget.puzzleType,
        difficulty: gameState.difficulty,
        completionTime: elapsed,
        mode: widget.mode,
      );

      if (!mounted) return;
      setState(() {
        _completionStatus = status;
      });
    } catch (error) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Failed to record completion: $error');
      }
    }
  }

  /// Centralized completion handler so multiple listeners can invoke the
  /// same follow-up (persist clearing, recording completion, dialog).
  Future<void> _handleCompletion(GameState next) async {
    _triggerHapticFeedback(HapticFeedbackType.heavy);
    final Duration elapsed = DateTime.now().difference(next.startTime);
    if (mounted) {
      setState(() {
        _solveStatus = 'Solved';
        _elapsedTime = elapsed;
      });
    }
    // Clear in-progress persistence on completion
    try {
      final prefs = await SharedPreferences.getInstance();
      final progress = PuzzleProgressService(prefs);
      await progress.clear(widget.puzzleType);
    } catch (_) {}
    if (!_hasRecordedCompletion) {
      _hasRecordedCompletion = true;
      unawaited(_recordCompletion(next, elapsed));
    }

    // Show completion popup once
    if (!_shownSolvedDialog && mounted) {
      _shownSolvedDialog = true;
      // ignore: use_build_context_synchronously
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Congratulations!'),
          content: const Text('Puzzle completed successfully.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleNote(core.SudokuBoard board, {required int row, required int col, required int digit}) {
    final int index = row * core.SudokuBoard.side + col;
    final gameState = ref.read(gameStateProvider);
    if (gameState == null) return;

    final Set<int> currentNotes = gameState.notes[index] ?? const <int>{};
    final bool isAdding = !currentNotes.contains(digit);

    final notifier = ref.read(gameStateProvider.notifier);
    notifier.recordNoteAction(index, digit, isAdding);
  }

  // Sudoku interaction handlers
  void _onCellSelected(Offset position) {
    _triggerHapticFeedback(HapticFeedbackType.light);
    setState(() {
      _selectedSudokuCell = position;
    });
  }

  void _onMove(dynamic move) {
    _triggerHapticFeedback(HapticFeedbackType.light);
    if (_isNoteMode && move is core.SudokuMove && move.digit != 0) {
      final gameState = ref.read(gameStateProvider);
      final board = gameState?.puzzle.state;
      if (board is core.SudokuBoard) {
        if (board.isFixed(move.row, move.col)) {
          _onError('Cannot change a fixed clue');
        } else {
          _toggleNote(board, row: move.row, col: move.col, digit: move.digit);
        }
        return;
      }
    }
    final notifier = ref.read(gameStateProvider.notifier);
    notifier.makeMove(move).then((_) async {
      if (!mounted) {
        return;
      }
      setState(() {
        _movesCount++;
      });

      // Persist in-progress after each successful move
      try {
        final current = ref.read(gameStateProvider)?.puzzle;
        if (current != null) {
          final prefs = await SharedPreferences.getInstance();
          final progress = PuzzleProgressService(prefs);
          await progress.save(widget.puzzleType, current);
        }
      } catch (_) {}

      // Detect filled-but-incorrect board for Sudoku and show feedback
      final gameState = ref.read(gameStateProvider);
      final board = gameState?.puzzle.state;
      if (board is core.SudokuBoard) {
        final bool filled = board.emptyCount == 0;
        final bool solved = gameState?.isSolved ?? false;
        if (filled && !solved) {
          _onError('Incorrect solution');
        }
      }
    }).catchError((Object error) {
      final String message = error.toString().startsWith('Exception: ')
          ? error.toString().substring('Exception: '.length)
          : error.toString();
      _onError(message);
    });
  }

  void _onError(String error) {
    _triggerHapticFeedback(HapticFeedbackType.heavy);
    _showSnackBar(error, backgroundColor: Theme.of(context).colorScheme.error);
  }

  void _onDigitPressed(int digit) {
    _triggerHapticFeedback(HapticFeedbackType.light);
    final gameState = ref.read(gameStateProvider);
    if (gameState == null || gameState.puzzle.state is! core.SudokuBoard) {
      return;
    }
    final Offset? selection = _selectedSudokuCell;
    if (selection == null) {
      _showSnackBar('Select a cell to place $digit');
      return;
    }
    final int row = selection.dy.toInt();
    final int col = selection.dx.toInt();
    final core.SudokuBoard board = gameState.puzzle.state as core.SudokuBoard;
    if (board.isFixed(row, col)) {
      _onError('Cannot change a fixed clue');
      return;
    }

    if (_isNoteMode) {
      _toggleNote(board, row: row, col: col, digit: digit);
      return;
    }

    // Pre-check duplicate digit in the same unit (row/col/box). If the
    // same digit already exists in row/column/box, trigger haptic feedback
    // and do not apply the move. For other incorrect numbers, allow the
    // move to be applied (the engine or validator may accept/reject it).
    if (_wouldCauseUnitConflict(board, row, col, digit)) {
      // Give subtle haptic feedback for unit-duplication attempts.
      _triggerHapticFeedback(HapticFeedbackType.medium);
      return;
    }

    final core.SudokuMove move = core.SudokuMove(row: row, col: col, digit: digit);
    _onMove(move);
  }

  bool _wouldCauseUnitConflict(core.SudokuBoard board, int row, int col, int digit) {
    if (digit == 0) return false;
    final int targetIndex = row * core.SudokuBoard.side + col;
    // Check row
    for (final idx in core.SudokuBoard.rowIndices(row)) {
      if (idx == targetIndex) continue;
      if (board.cells[idx] == digit) return true;
    }
    // Check column
    for (final idx in core.SudokuBoard.columnIndices(col)) {
      if (idx == targetIndex) continue;
      if (board.cells[idx] == digit) return true;
    }
    // Check box
    for (final idx in core.SudokuBoard.boxIndices(row, col)) {
      // boxIndices may include the target cell; skip it
      if (idx == targetIndex) continue;
      final int r = idx ~/ core.SudokuBoard.side;
      final int c = idx % core.SudokuBoard.side;
      if (board.cellAt(r, c) == digit) return true;
    }
    return false;
  }

  void _onClearPressed() {
    _triggerHapticFeedback(HapticFeedbackType.light);
    final gameState = ref.read(gameStateProvider);
    if (gameState == null || gameState.puzzle.state is! core.SudokuBoard) {
      return;
    }
    final Offset? selection = _selectedSudokuCell;
    if (selection == null) {
      _showSnackBar('Select a cell to clear');
      return;
    }
    final int row = selection.dy.toInt();
    final int col = selection.dx.toInt();
    final core.SudokuBoard board = gameState.puzzle.state as core.SudokuBoard;
    if (board.isFixed(row, col)) {
      _onError('Cannot change a fixed clue');
      return;
    }
    if (_isNoteMode) {
      final notifier = ref.read(gameStateProvider.notifier);
      notifier.clearNotesForCell(row * core.SudokuBoard.side + col);
      return;
    }

    final core.SudokuMove move = core.SudokuMove(row: row, col: col, digit: 0);
    _onMove(move);
  }

  void _onNotePressed() {
    _triggerHapticFeedback(HapticFeedbackType.light);
    setState(() {
      _isNoteMode = !_isNoteMode;
    });
  }

  // Kakuro: place digits in selected playable cell. If Note mode is on, toggle a local notes map.
  void _onKakuroDigitPressed(int digit) {
    final gameState = ref.read(gameStateProvider);
    if (gameState == null || gameState.puzzle.state is! core.KakuroBoard) {
      return;
    }
    final Offset? selection = _selectedSudokuCell; // reuse selection storage
    if (selection == null) {
      _showSnackBar('Select a cell to place $digit');
      return;
    }
    final int row = selection.dy.toInt();
    final int col = selection.dx.toInt();
    final core.KakuroBoard board = gameState.puzzle.state as core.KakuroBoard;
    if (!board.isPlayable(row, col)) {
      _onError('Select a playable cell');
      return;
    }

    if (_isNoteMode) {
      _toggleKakuroNote(board, row: row, col: col, digit: digit);
      return;
    }

    // Validate the move: no repeats in sum groups, sum not exceeded
    // Check across entry
    final acrossIdx = board.acrossEntryForCell[row * board.width + col];
    if (acrossIdx != -1) {
      final entry = board.entries[acrossIdx];
      final cells = entry.cells;
      // Check for repeats (excluding current cell)
      for (final cellIndex in cells) {
        final cellRow = cellIndex ~/ board.width;
        final cellCol = cellIndex % board.width;
        if (cellRow == row && cellCol == col) continue;
        if (board.valueAt(cellRow, cellCol) == digit) {
          _onError('Digit $digit already used in this across sum');
          return;
        }
      }
      // Check sum
      int currentSum = 0;
      for (final cellIndex in cells) {
        final cellRow = cellIndex ~/ board.width;
        final cellCol = cellIndex % board.width;
        final val = board.valueAt(cellRow, cellCol);
        if (val != 0) {
          currentSum += val;
        }
      }
      final oldVal = board.valueAt(row, col);
      if (oldVal != 0) {
        currentSum -= oldVal; // subtract old value if overwriting
      }
      if (currentSum + digit > entry.sum) {
        _onError('Sum would exceed ${entry.sum}');
        return;
      }
    }

    // Check down entry
    final downIdx = board.downEntryForCell[row * board.width + col];
    if (downIdx != -1) {
      final entry = board.entries[downIdx];
      final cells = entry.cells;
      // Check for repeats (excluding current cell)
      for (final cellIndex in cells) {
        final cellRow = cellIndex ~/ board.width;
        final cellCol = cellIndex % board.width;
        if (cellRow == row && cellCol == col) continue;
        if (board.valueAt(cellRow, cellCol) == digit) {
          _onError('Digit $digit already used in this down sum');
          return;
        }
      }
      // Check sum
      int currentSum = 0;
      for (final cellIndex in cells) {
        final cellRow = cellIndex ~/ board.width;
        final cellCol = cellIndex % board.width;
        final val = board.valueAt(cellRow, cellCol);
        if (val != 0) {
          currentSum += val;
        }
      }
      final oldVal = board.valueAt(row, col);
      if (oldVal != 0) {
        currentSum -= oldVal; // subtract old value if overwriting
      }
      if (currentSum + digit > entry.sum) {
        _onError('Sum would exceed ${entry.sum}');
        return;
      }
    }

    final core.KakuroMove move = core.KakuroMove(row: row, col: col, digit: digit);
    _onMove(move);
  }

  void _onKakuroClearPressed() {
    final gameState = ref.read(gameStateProvider);
    if (gameState == null || gameState.puzzle.state is! core.KakuroBoard) {
      return;
    }
    final Offset? selection = _selectedSudokuCell;
    if (selection == null) {
      _showSnackBar('Select a cell to clear');
      return;
    }
    final int row = selection.dy.toInt();
    final int col = selection.dx.toInt();
    final core.KakuroBoard board = gameState.puzzle.state as core.KakuroBoard;
    if (!board.isPlayable(row, col)) {
      _onError('Select a playable cell');
      return;
    }
    final core.KakuroMove move = core.KakuroMove(row: row, col: col, digit: 0);
    _onMove(move);
  }

  void _toggleKakuroNote(core.KakuroBoard board, {required int row, required int col, required int digit}) {
    final int index = row * board.width + col;
    final gameState = ref.read(gameStateProvider);
    if (gameState == null) return;

    final Set<int> currentNotes = gameState.notes[index] ?? const <int>{};
    final bool isAdding = !currentNotes.contains(digit);

    final notifier = ref.read(gameStateProvider.notifier);
    notifier.recordNoteAction(index, digit, isAdding);
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timerController.dispose();
    _pulseController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Apply puzzle-specific theme for this screen so accents match the puzzle
    final baseTheme = Theme.of(context);
    final theme = AppThemeData.forPuzzleType(widget.puzzleType, baseTheme);
    final colorScheme = theme.colorScheme;

    // Register Riverpod listeners here (only once) — ref.listen must be used
    // from the build method of a ConsumerWidget/ConsumerStatefulWidget.
    if (!_listenersRegistered) {
      _listenersRegistered = true;
      ref.listen<GameState?>(gameStateProvider, (prev, next) async {
        if (kDebugMode) {
          // Debug log to help diagnose why completion may not be detected.
          // This will print the previous and next isSolved values when the
          // gameStateProvider changes.
          // ignore: avoid_print
          print('PlayScreen.gameState changed: prev.isSolved=${prev?.isSolved} next.isSolved=${next?.isSolved}');
        }
        if (next != null) {
          final String? previousSeed = prev?.puzzle.meta.seedStr;
          final String currentSeed = next.puzzle.meta.seedStr;
          if (previousSeed != currentSeed && mounted) {
            setState(() {
              _selectedSudokuCell = null;
            });
          }
        }
        final bool wasSolved = prev?.isSolved ?? false;
        final bool isSolved = next?.isSolved ?? false;
        if (!wasSolved && isSolved && next != null) {
          // Delegate to centralized handler
          unawaited(_handleCompletion(next));
        }
      });
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(theme, colorScheme),

            // Canvas Area
            Expanded(
              child: _buildCanvasArea(theme, colorScheme),
            ),

            // Footer
            _buildFooter(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Top row: Timer and puzzle info
          Row(
            children: [
              // Timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(_elapsedTime),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Puzzle name and difficulty
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.puzzleType.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.difficulty != null)
                    Text(
                      widget.difficulty!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Action buttons row
          Row(
            children: [
              // Hint button
              Expanded(
                child: _buildActionButton(
                  icon: Icons.lightbulb_outline,
                  label: 'Hint',
                  onTap: _useHint,
                  color: colorScheme.secondary,
                  theme: theme,
                ),
              ),

              const SizedBox(width: 12),

              // Undo button
              Expanded(
                child: _buildActionButton(
                  icon: Icons.undo,
                  label: 'Undo',
                  onTap: _undoMove,
                  color: colorScheme.tertiary,
                  theme: theme,
                ),
              ),

              const SizedBox(width: 12),

              // Restart button
              Expanded(
                child: _buildActionButton(
                  icon: Icons.refresh,
                  label: 'Restart',
                  onTap: _restartPuzzle,
                  color: colorScheme.error,
                  theme: theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required ThemeData theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasArea(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: _buildPuzzleContent(theme, colorScheme),
    );
  }

  Widget _buildPuzzleContent(ThemeData theme, ColorScheme colorScheme) {
    // Get game state from provider
    final gameState = ref.watch(gameStateProvider);

    // Note: debug logging is performed once in initState/didUpdateWidget via
    // _logPuzzleInfoIfNeeded to avoid spamming logs during rebuilds.

    // Prefer the explicit puzzleInstance passed to the screen; if absent,
    // fall back to the game state provider's puzzle (if any).
  // Prefer the live game state's puzzle so UI reflects moves; fall back
  // to a navigation-provided instance only if state hasn't initialized yet.
  final core.GeneratedPuzzle? generatedPuzzle =
    gameState?.puzzle ??
    (widget.puzzleInstance is core.GeneratedPuzzle
      ? widget.puzzleInstance as core.GeneratedPuzzle
      : null);

    // If we still don't have a puzzle, show a loading indicator while
    // a generator/provider populates it.
    if (generatedPuzzle == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Generating puzzle...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    // We have a puzzle instance; render it using the appropriate renderer
    final core.GeneratedPuzzle puzzle = generatedPuzzle;
    // Sudoku
    if (puzzle.state is core.SudokuBoard) {
      return _buildSudokuGame(theme, colorScheme, puzzle, gameState);
    }

    // Nonogram
    if (puzzle.state is core.NonogramBoard) {
      return Column(
        children: [
          // Cross-mode toggle for nonogram (adds/removes crosses instead of toggling filled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Cross mode',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _isCrossMode,
                  onChanged: (v) => setState(() => _isCrossMode = v),
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: NonogramRendererWidget(
                puzzle: puzzle,
                gameState: gameState,
                onCellSelected: _onCellSelected,
                onMove: _onMove,
                onError: _onError,
                hintCells: _hintPositions,
                hintAnimationValue: _hintAnimationValue,
                crossMode: _isCrossMode,
              ),
            ),
          ),
        ],
      );
    }

    // Kakuro
    if (puzzle.state is core.KakuroBoard) {
      return Column(
        children: [
          // Puzzle renderer
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: KakuroRendererWidget(
                puzzle: puzzle,
                gameState: gameState,
                onCellSelected: _onCellSelected,
                onMove: _onMove,
                onError: _onError,
                hintCells: _hintPositions,
                hintAnimationValue: _hintAnimationValue,
                notes: Map.unmodifiable(gameState?.notes ?? const <int, Set<int>>{}),
              ),
            ),
          ),

          // Number pad (single row with 1..9), with note toggle and clear
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SudokuNumberPad(
              onDigitPressed: _onKakuroDigitPressed,
              onClearPressed: _onKakuroClearPressed,
              onNotePressed: _onNotePressed,
              isNoteMode: _isNoteMode,
            ),
          ),
        ],
      );
    }

    // Slitherlink
    if (puzzle.state is core.SlitherlinkBoard) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SlitherlinkRendererWidget(
          puzzle: puzzle,
          gameState: gameState,
          onMove: _onMove,
          onError: _onError,
          hintCells: _hintPositions,
          hintAnimationValue: _hintAnimationValue,
        ),
      );
    }

    // Mathdoku
    if (puzzle.state is core.MathdokuBoard) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: MathdokuRendererWidget(
          puzzle: puzzle,
          gameState: gameState,
          onCellSelected: _onCellSelected,
          onMove: _onMove,
          onError: _onError,
          hintCells: _hintPositions,
          hintAnimationValue: _hintAnimationValue,
        ),
      );
    }

    // Killer Queens
    if (puzzle.state is core.KillerQueensBoard) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: KillerQueensRendererWidget(
          puzzle: puzzle,
          gameState: gameState,
          onCellSelected: _onCellSelected,
          onMove: _onMove,
          onError: _onError,
          hintCells: _hintPositions,
          hintAnimationValue: _hintAnimationValue,
        ),
      );
    }

    // Takuzu
    if (puzzle.state is core.TakuzuBoard) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: TakuzuRendererWidget(
          puzzle: puzzle,
          gameState: gameState,
          onCellSelected: _onCellSelected,
          onMove: _onMove,
          onError: _onError,
          hintCells: _hintPositions,
          hintAnimationValue: _hintAnimationValue,
        ),
      );
    }

    // Fallback to placeholder
    return _buildPlaceholder(theme, colorScheme);
  }

  Widget _buildSudokuGame(ThemeData theme, ColorScheme colorScheme, core.GeneratedPuzzle puzzle, GameState? gameState) {
    return PerformanceMonitor(
      enabled: false, // Enable in debug mode if needed
      child: Column(
        children: [
          // Puzzle renderer
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSudokuGrid(puzzle),
            ),
          ),

          // Number pad (kept smaller)
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SudokuNumberPad(
                  onDigitPressed: _onDigitPressed,
                  onClearPressed: _onClearPressed,
                  onNotePressed: _onNotePressed,
                  isNoteMode: _isNoteMode,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSudokuGrid(core.GeneratedPuzzle puzzle) {
    final gameState = ref.watch(gameStateProvider);
    final Map<int, Set<int>> noteSnapshot = gameState?.notes ?? const <int, Set<int>>{};
    return SudokuRendererWidget(
      puzzle: puzzle,
      gameState: gameState,
      onCellSelected: _onCellSelected,
      onMove: _onMove,
      onError: _onError,
      hintCells: _hintPositions,
      hintAnimationValue: _hintAnimationValue,
      notes: Map.unmodifiable(noteSnapshot),
      hintFilledCells: Set<int>.unmodifiable(_sudokuHintFilled),
    );
  }

  Widget _buildPlaceholder(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.extension,
                    size: 40,
                    color: colorScheme.primary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Puzzle Canvas',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Game logic will be implemented here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          if (widget.puzzleInstance is core.GeneratedPuzzle) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Puzzle Instance Info',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Seed: ${widget.puzzleInstance.meta.seedStr}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    'Engine: ${widget.puzzleInstance.meta.engineVersion}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Solve status and stats
          Row(
            children: [
              // Solve status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(colorScheme).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getStatusColor(colorScheme).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getStatusColor(colorScheme),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _solveStatus,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _getStatusColor(colorScheme),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Stats
              Row(
                children: [
                  _buildStatChip(
                    icon: Icons.touch_app,
                    value: _movesCount.toString(),
                    theme: theme,
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_completionStatus != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _buildCompletionSummary(theme),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],

          // Navigation buttons removed per UX request (New & Back hidden)
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String value,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Navigation button builder removed — New/Back buttons are hidden per UX request.

  String _buildCompletionSummary(ThemeData theme) {
    final status = _completionStatus;
    if (status == null) {
      return '';
    }

    final Duration bestTime = status.bestTime ?? _elapsedTime;
    final String bestLabel = bestTime > Duration.zero
        ? 'Best ${_formatTime(bestTime)}'
        : 'Best --:--';
    final String dailyLabel = status.isDailyCompleted ? 'Daily ✓' : 'Daily ✗';
    return [
      bestLabel,
      'Streak ${status.puzzleStreak}',
      'Global ${status.globalStreak}',
      dailyLabel,
    ].join(' • ');
  }

  Color _getStatusColor(ColorScheme colorScheme) {
    switch (_solveStatus) {
      case 'In Progress':
        return colorScheme.primary;
      case 'Solved':
        return colorScheme.tertiary;
      case 'Failed':
        return colorScheme.error;
      default:
        return colorScheme.onSurface;
    }
  }
}

enum HapticFeedbackType {
  light,
  medium,
  heavy,
  selection,
}
