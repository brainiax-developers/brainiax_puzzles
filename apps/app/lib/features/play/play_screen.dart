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
  final Map<int, Set<int>> _sudokuNotes = <int, Set<int>>{};

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
      case PuzzleType.futoshikiClassic:
        return '6x6';
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
    // Increment local counter and request a hint from the ViewModel
    setState(() {
      _hintsUsed++;
    });
    _triggerHapticFeedback(HapticFeedbackType.medium);

    // Fire-and-forget: request hint from game state notifier and animate overlay
    () async {
      try {
        final hint = await ref.read(gameStateProvider.notifier).requestHint(
          request: core.PuzzleHintRequest(
            iteration: _hintsUsed,
            moveCount: _movesCount,
          ),
        );

        if (hint == null || hint.isEmpty) {
          // no hint available
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hint available')),
          );
          return;
        }

        final positions = hint.cells.map((c) => Offset(c.column.toDouble(), c.row.toDouble())).toList();

        setState(() {
          _hintPositions = positions;
        });

        // Animate the hint flashing and then clear
        await _hintController.forward(from: 0.0);
        await _hintController.reverse();

        // Keep visible briefly then clear
        await Future.delayed(const Duration(milliseconds: 200));
        setState(() {
          _hintPositions = [];
          _hintAnimationValue = 0.0;
        });
      } catch (e) {
        // ignore
      }
    }();
  }

  void _undoMove() {
    _triggerHapticFeedback(HapticFeedbackType.light);
    final notifier = ref.read(gameStateProvider.notifier);
    if (notifier.canUndo) {
      notifier.undo();
      // Reflect current move count based on history index
      setState(() {
        _movesCount = notifier.currentMoveIndex + 1;
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
        _sudokuNotes.clear();
        _selectedSudokuCell = null;
      });
      _timerController.reset();
      _startTimer();
    });
  }

  void _generateNewPuzzle() {
    _triggerHapticFeedback(HapticFeedbackType.heavy);
    // TODO: Navigate to puzzle generation or generate new puzzle
  }

  void _goBack() {
    _triggerHapticFeedback(HapticFeedbackType.light);
    Navigator.of(context).pop();
  }

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
    setState(() {
      final Set<int> notes = Set<int>.from(_sudokuNotes[index] ?? const <int>{});
      if (notes.contains(digit)) {
        notes.remove(digit);
      } else {
        notes.add(digit);
      }
      if (notes.isEmpty) {
        _sudokuNotes.remove(index);
      } else {
        _sudokuNotes[index] = notes;
      }
    });
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
        if (move is core.SudokuMove && move.digit != 0) {
          _sudokuNotes.remove(move.row * core.SudokuBoard.side + move.col);
        }
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

    final core.SudokuMove move = core.SudokuMove(row: row, col: col, digit: digit);
    _onMove(move);
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
      setState(() {
        _sudokuNotes.remove(row * core.SudokuBoard.side + col);
      });
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
        if (next != null) {
          final String? previousSeed = prev?.puzzle.meta.seedStr;
          final String currentSeed = next.puzzle.meta.seedStr;
          if (previousSeed != currentSeed && mounted) {
            setState(() {
              _sudokuNotes.clear();
              _selectedSudokuCell = null;
            });
          }
        }
        final bool wasSolved = prev?.isSolved ?? false;
        final bool isSolved = next?.isSolved ?? false;
        if (!wasSolved && isSolved && next != null) {
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
      return Padding(
        padding: const EdgeInsets.all(16),
        child: NonogramRendererWidget(
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

    // Kakuro
    if (puzzle.state is core.KakuroBoard) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: KakuroRendererWidget(
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

    // Futoshiki
    if (puzzle.state is core.FutoshikiBoard) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: FutoshikiRendererWidget(
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
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSudokuGrid(puzzle),
            ),
          ),

          // Number pad
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
    final Map<int, Set<int>> noteSnapshot = _sudokuNotes.map(
      (int key, Set<int> value) => MapEntry(key, Set<int>.unmodifiable(value)),
    );
    return SudokuRendererWidget(
      puzzle: puzzle,
      gameState: ref.watch(gameStateProvider),
      onCellSelected: _onCellSelected,
      onMove: _onMove,
      onError: _onError,
      hintCells: _hintPositions,
      hintAnimationValue: _hintAnimationValue,
      notes: Map.unmodifiable(noteSnapshot),
    );
  }

  Widget _buildPlaceholder(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated puzzle icon
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
                    icon: Icons.lightbulb_outline,
                    value: _hintsUsed.toString(),
                    theme: theme,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 8),
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

          // Navigation buttons
          Row(
            children: [
              // New puzzle button
              Expanded(
                child: _buildNavigationButton(
                  icon: Icons.add_circle_outline,
                  label: 'New',
                  onTap: _generateNewPuzzle,
                  color: colorScheme.primary,
                  theme: theme,
                ),
              ),

              const SizedBox(width: 12),

              // Back button
              Expanded(
                child: _buildNavigationButton(
                  icon: Icons.arrow_back,
                  label: 'Back',
                  onTap: _goBack,
                  color: colorScheme.onSurface,
                  theme: theme,
                  isOutlined: true,
                ),
              ),
            ],
          ),
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

  Widget _buildNavigationButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required ThemeData theme,
    bool isOutlined = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isOutlined ? Colors.transparent : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: isOutlined ? 1 : 0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
