import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
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
import '../../shared/services/seed_service.dart';
import '../daily/daily_providers.dart';

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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  Timer? _timer;
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
  bool _completionHandling = false;
  PuzzleCompletionStatus? _completionStatus;
  bool _dailyBlocked = false;
  String? _dailyBlockedMessage;
  // Guard to ensure we only register Riverpod listeners once
  bool _listenersRegistered = false;
  // Guard to ensure we only restore persisted session stats once per puzzle.
  bool _statsLoaded = false;
  bool _timerStarted = false;
  late final PuzzleProgressController _progressController;

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
    _progressController = ref.read(puzzleProgressControllerProvider);
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();

    // If no puzzle instance was passed and there's no active game state,
    // auto-start a new random game for Random mode so the canvas is populated.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final currentState = ref.read(gameStateProvider);
        final engineAvailable =
            ref.read(engineProvider(widget.puzzleType.key)) != null;
        final String engineId = widget.puzzleType.key;
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final progress = PuzzleProgressService(prefs);

        if (widget.mode == PuzzleMode.daily) {
          final store = await ref.read(puzzleLocalStoreProvider.future);
          final String todayKey = DailyUtcDate.todayKey();
          final bool completedToday = await store.isDailyCompleted(
            widget.puzzleType,
            todayKey,
          );
          if (completedToday) {
            if (!mounted) return;
            setState(() {
              _dailyBlocked = true;
              _dailyBlockedMessage =
                  '${widget.puzzleType.displayName} is complete for today.';
              _isPlaying = false;
              _isPaused = true;
              _statsLoaded = true;
            });
            return;
          }

          final activeRun = await progress.loadActiveRun(widget.puzzleType);
          final activePuzzle = progress.load(widget.puzzleType);
          if (activeRun != null &&
              activePuzzle != null &&
              activeRun.mode == PuzzleMode.daily &&
              activeRun.dailyDateKeyUtc == todayKey &&
              !activeRun.isSolved &&
              engineAvailable) {
            await ref
                .read(gameStateProvider.notifier)
                .startWithGeneratedPuzzle(
                  engineId: engineId,
                  seed: activeRun.seed,
                  difficulty: activeRun.difficulty,
                  size: activeRun.size,
                  puzzle: activePuzzle,
                );
            _logPuzzleInfoIfNeeded(ref.read(gameStateProvider));
            await _loadSessionStatsIfNeeded();
            return;
          }
        }

        // If a generated puzzle instance was passed via navigation extras, use it.
        // Replace any existing game state if the seed differs, so Random Play
        // always shows the newly generated puzzle.
        if (widget.puzzleInstance != null && engineAvailable) {
          try {
            final core.GeneratedPuzzle generated =
                widget.puzzleInstance as core.GeneratedPuzzle;
            final String newSeed = generated.meta.seedStr;
            final String difficulty = generated.meta.difficulty.level;
            final String size = generated.meta.size.id;
            final bool replacing = currentState != null;
            await ref
                .read(gameStateProvider.notifier)
                .startWithGeneratedPuzzle(
                  engineId: widget.puzzleType.key,
                  seed: newSeed,
                  difficulty: difficulty,
                  size: size,
                  puzzle: generated,
                );
            if (kDebugMode) {
              // ignore: avoid_print
              print(
                'PlayScreen: applied navigation puzzle seed=$newSeed '
                'replacingExisting=$replacing',
              );
            }
            // Log once after we've set up the game state
            _logPuzzleInfoIfNeeded(ref.read(gameStateProvider));
            // Restore any persisted session stats for this puzzle instance
            // (timer, moves, hints) when resuming via Continue Game.
            unawaited(_loadSessionStatsIfNeeded());
            return;
          } catch (e) {
            // If casting or initialization fails, fall back to generation below
          }
        }

        if (widget.mode == PuzzleMode.daily &&
            widget.puzzleInstance == null &&
            engineAvailable) {
          try {
            final String expectedSeed = _expectedDailySeed(engineId);
            final bool hasCurrentDaily =
                currentState != null &&
                currentState.engineId == engineId &&
                currentState.seed == expectedSeed;

            if (!hasCurrentDaily) {
              ref
                  .read(gameStateProvider.notifier)
                  .clearIfMismatched(engineId: engineId, seed: expectedSeed);
              final generated = await ref.read(
                dailyPuzzleProvider(engineId).future,
              );
              await ref
                  .read(gameStateProvider.notifier)
                  .startWithGeneratedPuzzle(
                    engineId: engineId,
                    seed: generated.meta.seedStr,
                    difficulty: generated.meta.difficulty.level,
                    size: generated.meta.size.id,
                    puzzle: generated,
                  );
              _logPuzzleInfoIfNeeded(ref.read(gameStateProvider));
              await _saveActiveRunForCurrentState();
              unawaited(_loadSessionStatsIfNeeded());
              return;
            }
          } catch (_) {
            // If daily generation fails, allow the screen to render an empty state.
          }
        }

        if (widget.mode == PuzzleMode.random &&
            widget.puzzleInstance == null &&
            engineAvailable &&
            (currentState == null || currentState.engineId != engineId)) {
          // Build a deterministic-ish random seed string and sensible defaults
          final seed =
              'random:$engineId:${DateTime.now().millisecondsSinceEpoch}';
          const difficulty = 'medium';
          final size = _defaultSizeForPuzzleType(widget.puzzleType);

          // Fire-and-forget; startNewGame will populate the gameStateProvider
          await _clearPersistedProgress();
          await ref
              .read(gameStateProvider.notifier)
              .startNewGame(
                engineId: widget.puzzleType.key,
                seed: seed,
                difficulty: difficulty,
                size: size,
              );
          // Save initial in-progress state
          await _saveActiveRunForCurrentState();
        }
      } catch (e) {
        // Ignore startup errors - they'll be surfaced elsewhere if needed
      }

      if (!mounted) return;

      // Log once after any generation attempt so we can diagnose which engine/puzzle was used
      _logPuzzleInfoIfNeeded(ref.read(gameStateProvider));
      // Restore any persisted timer/move/hint stats for this puzzle instance.
      unawaited(_loadSessionStatsIfNeeded());
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
    final core.GeneratedPuzzle? current =
        widget.puzzleInstance is core.GeneratedPuzzle
        ? widget.puzzleInstance as core.GeneratedPuzzle
        : gameState?.puzzle;

    if (identical(_lastLoggedPuzzle, current)) return;
    _lastLoggedPuzzle = current;

    if (!kDebugMode) return;
    final String seed = current?.meta.seedStr ?? 'none';
    final String source = widget.puzzleInstance is core.GeneratedPuzzle
        ? 'navigation'
        : gameState?.puzzle != null
        ? 'provider'
        : 'none';
    // ignore: avoid_print
    print(
      'PlayScreen: source=$source type=${widget.puzzleType.key} '
      'mode=${widget.mode.key} seed=$seed '
      'state=${gameState?.runtimeType} puzzle=${gameState?.puzzle.runtimeType}',
    );
  }

  Future<void> _loadSessionStatsIfNeeded() async {
    if (_statsLoaded) return;
    final GameState? state = ref.read(gameStateProvider);
    if (state == null) return;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final progress = PuzzleProgressService(prefs);
      final run = await progress.loadActiveRun(widget.puzzleType);
      final bool matchesCurrent =
          run != null &&
          run.seed == state.puzzle.meta.seedStr &&
          run.puzzleType == widget.puzzleType;

      if (!mounted) return;
      setState(() {
        if (matchesCurrent) {
          _elapsedTime = Duration(milliseconds: run.elapsedMs);
          _movesCount = run.moveCount;
          _hintsUsed = run.hintsUsed;
        }
        _statsLoaded = true;
      });
      if (!matchesCurrent) {
        await _saveActiveRunForCurrentState();
      }
      _startTimerIfReady();
    } catch (_) {
      // Ignore persistence errors; gameplay can continue without restored stats.
      if (!mounted) return;
      setState(() {
        _statsLoaded = true;
      });
      _startTimerIfReady();
    }
  }

  void _startTimerIfReady() {
    if (_timerStarted || _dailyBlocked || !_statsLoaded) return;
    if (!_matchesRouteState(ref.read(gameStateProvider))) return;
    _timerStarted = true;
    _startTimer();
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

  String _expectedDailySeed(String engineId) {
    return ref.read(dailySeedGeneratorProvider).generate(engineId).seedStr;
  }

  bool _currentEngineSupportsHints() {
    return ref
            .read(engineProvider(widget.puzzleType.key))
            ?.capabilities
            .supportsHints ??
        false;
  }

  bool _matchesRoutePuzzleType(core.GeneratedPuzzle<dynamic> puzzle) {
    final Object board = puzzle.state;
    switch (widget.puzzleType) {
      case PuzzleType.sudokuClassic:
        return board is core.SudokuBoard;
      case PuzzleType.nonogramMono:
        return board is core.NonogramBoard;
      case PuzzleType.kakuroClassic:
        return board is core.KakuroBoard;
      case PuzzleType.slitherlinkLoop:
        return board is core.SlitherlinkBoard;
      case PuzzleType.mathdokuClassic:
        return board is core.MathdokuBoard;
      case PuzzleType.killerQueens:
        return board is core.KillerQueensBoard;
      case PuzzleType.takuzuBinary:
        return board is core.TakuzuBoard;
    }
  }

  bool _matchesRouteState(GameState? gameState) {
    if (gameState == null || gameState.engineId != widget.puzzleType.key) {
      return false;
    }
    if (widget.mode == PuzzleMode.daily) {
      return gameState.seed == _expectedDailySeed(widget.puzzleType.key);
    }
    return true;
  }

  Future<void> _clearPersistedProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progress = PuzzleProgressService(prefs);
      await progress.clear(widget.puzzleType);
    } catch (_) {
    } finally {
      ref.read(puzzleProgressControllerProvider).refresh();
    }
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
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
    _timer?.cancel();
    _isPlaying = true;
    _isPaused = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_isPlaying || _isPaused) return;
      setState(() {
        _elapsedTime += const Duration(seconds: 1);
      });
      // Persist timer every second to ensure Android back and in-app back
      // have identical behavior (both accurate to the last second)
      _persistTimerOnly();
    });
  }

  // Pause/resume handled implicitly by navigation/state; explicit toggle removed.

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _isPaused = true;
      // Persist latest stats whenever the app is backgrounded or detached so
      // that Android system back / app switches still preserve timer & moves.
      unawaited(_persistSessionStats());
    } else if (state == AppLifecycleState.resumed) {
      _isPaused = false;
    }
  }

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
    if (!_currentEngineSupportsHints()) {
      return;
    }
    final board = gameState.puzzle.state;

    if (board is core.SudokuBoard) {
      () async {
        try {
          // Prefer engine-provided hints (which now expose a concrete digit),
          // falling back to local singles-based logic if necessary.
          final core.PuzzleHint? engineHint = await ref
              .read(gameStateProvider.notifier)
              .requestHint(
                request: core.PuzzleHintRequest(
                  iteration: _hintsUsed,
                  moveCount: _movesCount,
                ),
              );

          ({int row, int col, int digit})? hint;
          if (engineHint != null && !engineHint.isEmpty) {
            for (final core.PuzzleHintCell cell in engineHint.cells) {
              final Object? digitMeta = cell.metadata['digit'];
              if (digitMeta is int && digitMeta > 0 && digitMeta <= 9) {
                hint = (row: cell.row, col: cell.column, digit: digitMeta);
                break;
              }
            }
          }

          hint ??= _computeSudokuHint(board);
          if (hint == null) {
            _showSnackBar('No hint available for this board yet.');
            return;
          }
          final resolvedHint = hint;

          final core.SudokuMove move = core.SudokuMove(
            row: resolvedHint.row,
            col: resolvedHint.col,
            digit: resolvedHint.digit,
          );
          final bool changed = await _applyMoveAndPersist(
            move,
            handleCompletion: false,
          );
          if (!changed) {
            _showSnackBar('No hint available for this board yet.');
            return;
          }
          if (!mounted) return;
          setState(() {
            _sudokuHintFilled.add(
              resolvedHint.row * core.SudokuBoard.side + resolvedHint.col,
            );
          });
          await _incrementHintCountPersistent();
          // Ensure completion is surfaced even if the listener misses a frame.
          final GameState? latest = ref.read(gameStateProvider);
          if (latest != null && latest.isSolved && !_shownSolvedDialog) {
            unawaited(_handleCompletion(latest));
          }
        } catch (_) {
          // If anything goes wrong, fall back to a no-op with a gentle message.
          if (mounted) {
            _showSnackBar('No hint available for this board yet.');
          }
        }
      }();
      return;
    }

    if (board is core.NonogramBoard) {
      () async {
        try {
          final core.PuzzleHint? engineHint = await ref
              .read(gameStateProvider.notifier)
              .requestHint(
                request: core.PuzzleHintRequest(
                  iteration: _hintsUsed,
                  moveCount: _movesCount,
                ),
              );

          if (engineHint == null || engineHint.isEmpty) {
            _showSnackBar('No hint available for this board yet.');
            return;
          }

          if (engineHint.cells.isEmpty) {
            _showSnackBar('No hint available for this board yet.');
            return;
          }

          final core.PuzzleHintCell cell = engineHint.cells.first;
          final Object? rawValue = cell.metadata['value'];
          int? value;
          if (rawValue is int && (rawValue == 0 || rawValue == 1)) {
            value = rawValue;
          }

          if (value == null) {
            _showSnackBar('No hint available for this board yet.');
            return;
          }

          final core.NonogramMove move = core.NonogramMove(
            row: cell.row,
            col: cell.column,
            value: value,
          );

          final bool changed = await _applyMoveAndPersist(
            move,
            handleCompletion: false,
          );
          if (!changed) {
            _showSnackBar('No hint available for this board yet.');
            return;
          }
          if (!mounted) return;
          await _incrementHintCountPersistent();
          // Ensure completion is surfaced even if the listener misses a frame.
          final GameState? latest = ref.read(gameStateProvider);
          if (latest != null && latest.isSolved && !_shownSolvedDialog) {
            unawaited(_handleCompletion(latest));
          }
        } catch (_) {
          if (mounted) {
            _showSnackBar('No hint available for this board yet.');
          }
        }
      }();
      return;
    }

    // Non-Sudoku: request engine-provided hint and flash highlight
    () async {
      try {
        final hint = await ref
            .read(gameStateProvider.notifier)
            .requestHint(
              request: core.PuzzleHintRequest(
                iteration: _hintsUsed,
                moveCount: _movesCount,
              ),
            );
        if (hint == null || hint.isEmpty) {
          _showSnackBar('No hint available for this board yet.');
          return;
        }

        // If the engine supplies a concrete digit/value and we know how to apply it,
        // auto-fill the cell instead of only highlighting.
        if (board is core.KakuroBoard && hint.cells.isNotEmpty) {
          final core.PuzzleHintCell cell = hint.cells.first;
          final Object? raw = cell.metadata['digit'] ?? cell.metadata['value'];
          final int? digit = raw is int && raw >= 1 && raw <= 9 ? raw : null;
          if (digit != null) {
            final core.KakuroMove move = core.KakuroMove(
              row: cell.row,
              col: cell.column,
              digit: digit,
            );
            final bool changed = await _applyMoveAndPersist(
              move,
              handleCompletion: false,
            );
            if (!changed) {
              _showSnackBar('No hint available for this board yet.');
              return;
            }
            if (!mounted) return;
            await _incrementHintCountPersistent();
            // Ensure completion is surfaced even if the listener misses a frame.
            final GameState? latest = ref.read(gameStateProvider);
            if (latest != null && latest.isSolved && !_shownSolvedDialog) {
              unawaited(_handleCompletion(latest));
            }
            return;
          }
        }

        if (board is core.MathdokuBoard && hint.cells.isNotEmpty) {
          final core.PuzzleHintCell cell = hint.cells.first;
          final Object? raw = cell.metadata['value'] ?? cell.metadata['digit'];
          final int? value = raw is int && raw >= 1 && raw <= board.size
              ? raw
              : null;
          if (value != null) {
            final core.MathdokuMove move = core.MathdokuMove(
              row: cell.row,
              col: cell.column,
              value: value,
            );
            final bool changed = await _applyMoveAndPersist(
              move,
              handleCompletion: false,
            );
            if (!changed) {
              _showSnackBar('No hint available for this board yet.');
              return;
            }
            if (!mounted) return;
            await _incrementHintCountPersistent();
            // Ensure completion is surfaced even if the listener misses a frame.
            final GameState? latest = ref.read(gameStateProvider);
            if (latest != null && latest.isSolved && !_shownSolvedDialog) {
              unawaited(_handleCompletion(latest));
            }
            return;
          }
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
    await _persistSessionStats();
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
        if (cells.length == 1) {
          return (row: row, col: cells.first, digit: digit);
        }
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
        if (cells.length == 1) {
          return (row: cells.first, col: col, digit: digit);
        }
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

  bool _boxHasDigit(
    core.SudokuBoard board,
    int startRow,
    int startCol,
    int digit,
  ) {
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
      setState(() {
        _movesCount++;
      });
      unawaited(_saveActiveRunForCurrentState());
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
          content: const Text(
            'This will reset the board to its initial state and clear your moves.',
          ),
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
        _isPlaying = true;
        _hasRecordedCompletion = false;
        _completionStatus = null;
        _selectedSudokuCell = null;
        _statsLoaded = true;
        _hintPositions = [];
        _hintAnimationValue = 0.0;
        _sudokuHintFilled.clear();
        _shownSolvedDialog = false;
      });
      _timerStarted = false;
      unawaited(_saveActiveRunForCurrentState());
      _startTimer();
    });
  }

  Future<void> _showHowToPlayDialog() async {
    final registry = PuzzleRegistry()..initialize();
    final metadata = registry.getMetadata(widget.puzzleType);
    final String description =
        metadata?.description ?? 'Solve the puzzle using its standard rules.';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('How to Play'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.puzzleType.displayName,
                style: Theme.of(dialogContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(description),
              const SizedBox(height: 12),
              const Text('Full tutorial coming soon.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startNewGameAfterCompletion() async {
    final GameState? current = ref.read(gameStateProvider);
    final String difficulty = (current?.difficulty.isNotEmpty ?? false)
        ? current!.difficulty
        : (widget.difficulty ?? 'medium');
    final String size = (current?.size.isNotEmpty ?? false)
        ? current!.size
        : _defaultSizeForPuzzleType(widget.puzzleType);
    final String seed = SeedService().generateRandomSeed(widget.puzzleType.key);

    try {
      await _clearPersistedProgress();
      await ref
          .read(gameStateProvider.notifier)
          .startNewGame(
            engineId: widget.puzzleType.key,
            seed: seed,
            difficulty: difficulty,
            size: size,
          );

      // Persist the freshly generated puzzle for resume support.
      final puzzle = ref.read(gameStateProvider)?.puzzle;
      if (puzzle != null) {
        final prefs = await SharedPreferences.getInstance();
        final progress = PuzzleProgressService(prefs);
        await progress.saveRunForPuzzle(
          puzzleType: widget.puzzleType,
          mode: widget.mode,
          puzzle: puzzle,
          elapsed: Duration.zero,
          moveCount: 0,
          hintsUsed: 0,
          dailyDateKeyUtc: _dailyDateKeyForCurrentMode(),
        );
      }

      if (!mounted) return;
      setState(() {
        _elapsedTime = Duration.zero;
        _hintsUsed = 0;
        _movesCount = 0;
        _solveStatus = 'In Progress';
        _isPaused = false;
        _isPlaying = true;
        _hasRecordedCompletion = false;
        _completionStatus = null;
        _selectedSudokuCell = null;
        _statsLoaded = true;
        _hintPositions = [];
        _hintAnimationValue = 0.0;
        _sudokuHintFilled.clear();
        _shownSolvedDialog = false;
      });
      _timerStarted = false;
      _startTimer();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Failed to start new game: $error\n$stackTrace');
      }
      if (mounted) {
        _showSnackBar('Unable to start a new game right now');
      }
    }
  }

  Future<void> _showCompletionDialog(GameState next) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final String timeText = _formatTime(_elapsedTime);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.celebration, color: colors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Congratulations!',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You solved ${widget.puzzleType.displayName}.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface.withOpacity(0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Time $timeText • ${_movesCount} moves • ${next.difficulty}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withOpacity(0.65),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _completionStatsText(next, timeText),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withOpacity(0.65),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: widget.mode == PuzzleMode.daily
                          ? OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                context.go('/daily');
                              },
                              icon: const Icon(Icons.today),
                              label: const Text('Back to Daily'),
                            )
                          : OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                unawaited(_startNewGameAfterCompletion());
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('New Random'),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          if (mounted) {
                            context.go('/puzzles');
                          }
                        },
                        icon: const Icon(Icons.grid_view),
                        label: const Text('Puzzles menu'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Navigation actions (New/Back) removed from UI per UX request.

  String _currentDifficultyLabel(GameState? state) {
    final String difficulty = state?.difficulty.isNotEmpty == true
        ? state!.difficulty
        : widget.difficulty ?? '';
    if (difficulty.isEmpty) {
      return 'Unknown difficulty';
    }
    return difficulty[0].toUpperCase() + difficulty.substring(1);
  }

  String _completionStatsText(GameState state, String timeText) {
    final String modeLabel = widget.mode == PuzzleMode.daily
        ? 'Daily Challenge'
        : 'Random Play';
    return <String>[
      widget.puzzleType.displayName,
      modeLabel,
      _currentDifficultyLabel(state),
      'Time $timeText',
      '${_movesCount} moves',
      if (_hintsUsed > 0) '$_hintsUsed hints',
    ].join(' - ');
  }

  Future<void> _recordCompletion(GameState gameState, Duration elapsed) async {
    try {
      final controller = ref.read(puzzleCompletionControllerProvider);
      final status = await controller.recordCompletion(
        puzzleType: widget.puzzleType,
        difficulty: gameState.difficulty,
        completionTime: elapsed,
        mode: widget.mode,
        size: gameState.size,
        seed: gameState.seed,
        moveCount: _movesCount,
        hintsUsed: _hintsUsed,
        dailyDateKeyUtc: _dailyDateKeyForCurrentMode(),
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
    if (_completionHandling) {
      return;
    }
    _completionHandling = true;
    _triggerHapticFeedback(HapticFeedbackType.heavy);
    if (mounted) {
      setState(() {
        _solveStatus = 'Solved';
        _isPlaying = false;
      });
    }
    final Duration elapsed = _elapsedTime;
    if (!_hasRecordedCompletion) {
      _hasRecordedCompletion = true;
      await _recordCompletion(next, elapsed);
    }

    // Clear in-progress persistence after completion recording has been
    // attempted so resume state is not lost before durable stats are written.
    try {
      final prefs = await SharedPreferences.getInstance();
      final progress = PuzzleProgressService(prefs);
      await progress.updateStats(
        widget.puzzleType,
        elapsed: _elapsedTime,
        moveCount: _movesCount,
        hintsUsed: _hintsUsed,
        isSolved: true,
      );
      await progress.clear(widget.puzzleType);
    } catch (_) {
    } finally {
      ref.read(puzzleProgressControllerProvider).refresh();
    }

    // Show completion popup once
    if (!_shownSolvedDialog && mounted) {
      _shownSolvedDialog = true;
      await _showCompletionDialog(next);
    }
    _completionHandling = false;
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

  void _toggleNote(
    core.SudokuBoard board, {
    required int row,
    required int col,
    required int digit,
  }) {
    final int index = row * core.SudokuBoard.side + col;
    final gameState = ref.read(gameStateProvider);
    if (gameState == null) return;

    final Set<int> currentNotes = gameState.notes[index] ?? const <int>{};
    final bool isAdding = !currentNotes.contains(digit);

    final notifier = ref.read(gameStateProvider.notifier);
    notifier.recordNoteAction(index, digit, isAdding);
  }

  Future<bool> _applyMoveAndPersist(
    dynamic move, {
    bool handleCompletion = true,
  }) async {
    final notifier = ref.read(gameStateProvider.notifier);
    final Object? previousBoard = ref.read(gameStateProvider)?.puzzle.state;
    final bool changed = await notifier.makeMove(move);
    if (!changed) {
      return false;
    }
    final Object? nextBoard = ref.read(gameStateProvider)?.puzzle.state;

    if (move is core.SudokuMove && move.digit > 0) {
      notifier.cleanupSudokuNotesForPlacement(
        row: move.row,
        col: move.col,
        digit: move.digit,
      );
    }

    if (!mounted) {
      return true;
    }
    if (_shouldCountMove(move, previousBoard, nextBoard)) {
      setState(() {
        _movesCount++;
      });
    }

    await _saveActiveRunForCurrentState();

    final gameState = ref.read(gameStateProvider);
    final board = gameState?.puzzle.state;
    if (board is core.SudokuBoard) {
      final bool filled = board.emptyCount == 0;
      final bool solved = gameState?.isSolved ?? false;
      if (filled && !solved) {
        _onError('Incorrect solution');
      }
    }

    if (handleCompletion) {
      final GameState? latest = ref.read(gameStateProvider);
      if (latest != null && latest.isSolved && !_shownSolvedDialog) {
        unawaited(_handleCompletion(latest));
      }
    }

    return true;
  }

  bool _shouldCountMove(
    dynamic move,
    Object? previousBoard,
    Object? nextBoard,
  ) {
    if (move is core.NonogramMove &&
        previousBoard is core.NonogramBoard &&
        nextBoard is core.NonogramBoard) {
      final int index = previousBoard.indexOf(move.row, move.col);
      final int? previous = previousBoard.cells[index];
      final int? next = nextBoard.cells[index];
      return previous == 1 || next == 1;
    }

    if (move is core.SlitherlinkMove &&
        previousBoard is core.SlitherlinkBoard &&
        nextBoard is core.SlitherlinkBoard) {
      final topology = previousBoard.topology;
      final int index = move.horizontal
          ? topology.horizontalEdgeIndex(move.row, move.col)
          : topology.verticalEdgeIndex(move.row, move.col);
      final int previous = previousBoard.edges[index];
      final int next = nextBoard.edges[index];
      return previous == core.SlitherlinkBoard.edgeOn ||
          next == core.SlitherlinkBoard.edgeOn;
    }

    return true;
  }

  // Sudoku interaction handlers
  void _onCellSelected(Offset position) {
    _triggerHapticFeedback(HapticFeedbackType.light);
    setState(() {
      _selectedSudokuCell = position;
    });
  }

  void _onMove(dynamic move) async {
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
    try {
      await _applyMoveAndPersist(move);
    } catch (error) {
      final String message = error.toString().startsWith('Exception: ')
          ? error.toString().substring('Exception: '.length)
          : error.toString();
      _onError(message);
    }
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

    final core.SudokuMove move = core.SudokuMove(
      row: row,
      col: col,
      digit: digit,
    );
    _onMove(move);
  }

  bool _wouldCauseUnitConflict(
    core.SudokuBoard board,
    int row,
    int col,
    int digit,
  ) {
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

    final core.KakuroMove move = core.KakuroMove(
      row: row,
      col: col,
      digit: digit,
    );
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

  void _toggleKakuroNote(
    core.KakuroBoard board, {
    required int row,
    required int col,
    required int digit,
  }) {
    final int index = row * board.width + col;
    final gameState = ref.read(gameStateProvider);
    if (gameState == null) return;

    final Set<int> currentNotes = gameState.notes[index] ?? const <int>{};
    final bool isAdding = !currentNotes.contains(digit);

    final notifier = ref.read(gameStateProvider.notifier);
    notifier.recordNoteAction(index, digit, isAdding);
  }

  // Mathdoku: place digits in selected cell. If Note mode is on, toggle notes.
  void _onMathdokuDigitPressed(int digit) {
    final gameState = ref.read(gameStateProvider);
    if (gameState == null || gameState.puzzle.state is! core.MathdokuBoard) {
      return;
    }
    final Offset? selection = _selectedSudokuCell; // reuse selection storage
    if (selection == null) {
      _showSnackBar('Select a cell to place $digit');
      return;
    }
    final int row = selection.dy.toInt();
    final int col = selection.dx.toInt();

    if (_isNoteMode) {
      _toggleMathdokuNote(row: row, col: col, digit: digit);
      return;
    }

    final core.MathdokuMove move = core.MathdokuMove(
      row: row,
      col: col,
      value: digit,
    );
    _onMove(move);
  }

  void _onMathdokuClearPressed() {
    final gameState = ref.read(gameStateProvider);
    if (gameState == null || gameState.puzzle.state is! core.MathdokuBoard) {
      return;
    }
    final Offset? selection = _selectedSudokuCell;
    if (selection == null) {
      _showSnackBar('Select a cell to clear');
      return;
    }
    final int row = selection.dy.toInt();
    final int col = selection.dx.toInt();

    if (_isNoteMode) {
      final core.MathdokuBoard board =
          gameState.puzzle.state as core.MathdokuBoard;
      final notifier = ref.read(gameStateProvider.notifier);
      notifier.clearNotesForCell(row * board.size + col);
      return;
    }

    final core.MathdokuMove move = core.MathdokuMove(
      row: row,
      col: col,
      value: 0,
    );
    _onMove(move);
  }

  void _toggleMathdokuNote({
    required int row,
    required int col,
    required int digit,
  }) {
    final gameState = ref.read(gameStateProvider);
    if (gameState == null || gameState.puzzle.state is! core.MathdokuBoard) {
      return;
    }

    final core.MathdokuBoard board =
        gameState.puzzle.state as core.MathdokuBoard;
    final int index = row * board.size + col;

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
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    // Persist latest timer/move/hint stats for this puzzle instance so
    // "Continue Game" can restore them on re-entry.
    unawaited(_persistSessionStats());
    _progressController.refresh();
    _pulseController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  Future<void> _persistSessionStats() async {
    try {
      final GameState? state = ref.read(gameStateProvider);
      if (state == null) return;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final progress = PuzzleProgressService(prefs);
      await progress.saveRunForPuzzle(
        puzzleType: widget.puzzleType,
        mode: widget.mode,
        puzzle: state.puzzle,
        elapsed: _elapsedTime,
        moveCount: _movesCount,
        hintsUsed: _hintsUsed,
        isSolved: state.isSolved,
        dailyDateKeyUtc: _dailyDateKeyForCurrentMode(),
      );
    } catch (_) {
      // Ignore persistence errors; stats are a UX enhancement.
    }
  }

  void _persistTimerOnly() {
    // Fire-and-forget timer persistence for periodic saves
    () async {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final progress = PuzzleProgressService(prefs);
        await progress.updateStats(
          widget.puzzleType,
          elapsed: _elapsedTime,
          moveCount: _movesCount,
          hintsUsed: _hintsUsed,
        );
      } catch (_) {}
    }();
  }

  Future<void> _saveActiveRunForCurrentState() async {
    final GameState? state = ref.read(gameStateProvider);
    if (state == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final progress = PuzzleProgressService(prefs);
      await progress.saveRunForPuzzle(
        puzzleType: widget.puzzleType,
        mode: widget.mode,
        puzzle: state.puzzle,
        elapsed: _elapsedTime,
        moveCount: _movesCount,
        hintsUsed: _hintsUsed,
        isSolved: state.isSolved,
        dailyDateKeyUtc: _dailyDateKeyForCurrentMode(),
      );
    } catch (_) {}
  }

  String? _dailyDateKeyForCurrentMode() {
    return widget.mode == PuzzleMode.daily ? DailyUtcDate.todayKey() : null;
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
          print(
            'PlayScreen.gameState changed: prev.isSolved=${prev?.isSolved} next.isSolved=${next?.isSolved}',
          );
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
            Expanded(child: _buildCanvasArea(theme, colorScheme)),

            // Footer
            _buildFooter(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    final GameState? gameState = ref.watch(gameStateProvider);
    final bool hintsSupported = _currentEngineSupportsHints();
    final String difficultyLabel = _currentDifficultyLabel(gameState);
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
          // Top row: Back button (left) and centered timer
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: colorScheme.onSurface,
                tooltip: 'Back',
                onPressed: () async {
                  // Persist latest session stats before leaving so that
                  // "Continue Game" can restore timer and move count.
                  await _persistSessionStats();
                  if (!mounted) return;
                  Navigator.of(context).maybePop();
                },
              ),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
                ),
              ),
              IconButton(
                icon: const Icon(Icons.help_outline),
                color: colorScheme.onSurface,
                tooltip: 'How to Play',
                onPressed: _showHowToPlayDialog,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Puzzle name and difficulty centered
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.puzzleType.displayName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (difficultyLabel.isNotEmpty)
                Text(
                  difficultyLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
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
                  onTap: hintsSupported ? _useHint : null,
                  color: colorScheme.secondary,
                  theme: theme,
                  hintCount: _hintsUsed,
                  tooltip: hintsSupported
                      ? 'Get a hint'
                      : 'Hints are not available for this puzzle yet',
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
    required VoidCallback? onTap,
    required Color color,
    required ThemeData theme,
    int? hintCount,
    String? tooltip,
  }) {
    final bool enabled = onTap != null;
    final Color effectiveColor = enabled ? color : theme.disabledColor;
    return Tooltip(
      message: tooltip ?? label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: effectiveColor.withOpacity(enabled ? 0.1 : 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: effectiveColor.withOpacity(enabled ? 0.3 : 0.18),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, color: effectiveColor, size: 22),
                    if (hintCount != null)
                      Positioned(
                        bottom: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: effectiveColor.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            hintCount.toString(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: effectiveColor.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: effectiveColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasArea(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.all(8),
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
    if (_dailyBlocked) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: colorScheme.primary,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                _dailyBlockedMessage ?? 'Daily puzzle complete for today.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/daily'),
                child: const Text('Back to Daily'),
              ),
            ],
          ),
        ),
      );
    }

    // Get game state from provider
    final gameState = ref.watch(gameStateProvider);
    final bool routeStateMatch = _matchesRouteState(gameState);
    final AsyncValue<core.GeneratedPuzzle<dynamic>>? dailyPuzzleAsync =
        widget.mode == PuzzleMode.daily
        ? ref.watch(dailyPuzzleProvider(widget.puzzleType.key))
        : null;

    // Note: debug logging is performed once in initState/didUpdateWidget via
    // _logPuzzleInfoIfNeeded to avoid spamming logs during rebuilds.

    // Prefer the explicit puzzleInstance passed to the screen; if absent,
    // fall back to the game state provider's puzzle (if any).
    // Prefer the live game state's puzzle so UI reflects moves; fall back
    // to a navigation-provided instance only if state hasn't initialized yet.
    final core.GeneratedPuzzle? navigationPuzzle =
        widget.puzzleInstance is core.GeneratedPuzzle &&
            _matchesRoutePuzzleType(
              widget.puzzleInstance as core.GeneratedPuzzle<dynamic>,
            )
        ? widget.puzzleInstance as core.GeneratedPuzzle<dynamic>
        : null;

    final core.GeneratedPuzzle? generatedPuzzle = routeStateMatch
        ? gameState!.puzzle
        : (widget.mode == PuzzleMode.daily ? null : navigationPuzzle);

    // If we still don't have a puzzle, show a loading indicator while
    // a generator/provider populates it.
    if (generatedPuzzle == null) {
      if (dailyPuzzleAsync != null && dailyPuzzleAsync.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 28),
              const SizedBox(height: 10),
              Text(
                'Failed to load daily puzzle',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
        );
      }
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
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.8),
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
                notes: Map.unmodifiable(
                  gameState?.notes ?? const <int, Set<int>>{},
                ),
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
      return Column(
        children: [
          // Puzzle renderer
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: MathdokuRendererWidget(
                puzzle: puzzle,
                gameState: gameState,
                onCellSelected: _onCellSelected,
                onMove: _onMove,
                onError: _onError,
                hintCells: _hintPositions,
                hintAnimationValue: _hintAnimationValue,
                notes: Map.unmodifiable(
                  gameState?.notes ?? const <int, Set<int>>{},
                ),
              ),
            ),
          ),

          // Number pad (single row with 1..9), with note toggle and clear
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SudokuNumberPad(
              onDigitPressed: _onMathdokuDigitPressed,
              onClearPressed: _onMathdokuClearPressed,
              onNotePressed: _onNotePressed,
              isNoteMode: _isNoteMode,
            ),
          ),
        ],
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
          conflictingCells: gameState?.conflictingCells,
          isShowingConflicts: gameState?.isShowingConflicts ?? false,
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

  Widget _buildSudokuGame(
    ThemeData theme,
    ColorScheme colorScheme,
    core.GeneratedPuzzle puzzle,
    GameState? gameState,
  ) {
    return PerformanceMonitor(
      enabled: false, // Enable in debug mode if needed
      child: Column(
        children: [
          // Puzzle renderer
          Expanded(
            flex: 3,
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
    final Map<int, Set<int>> noteSnapshot =
        gameState?.notes ?? const <int, Set<int>>{};
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
      padding: const EdgeInsets.all(8),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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

          const SizedBox(height: 8),

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
          Icon(icon, size: 14, color: colorScheme.onSurface.withOpacity(0.7)),
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
    return [
      bestLabel,
      'Daily streak ${status.dailyStreak}',
      if (status.isDailyCompleted) 'Daily complete',
    ].join(' - ');
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

enum HapticFeedbackType { light, medium, heavy, selection }
