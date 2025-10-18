import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_core/puzzle_core.dart';
import '../providers/game_state_provider.dart';

/// Base class for puzzle renderers providing common functionality.
/// 
/// This abstract class defines the interface and common utilities for
/// rendering different types of puzzles with consistent interaction patterns.
abstract class PuzzleRenderer<T extends PuzzleRendererWidget> extends State<T> with TickerProviderStateMixin {
  /// The current puzzle state being rendered.
  GeneratedPuzzle? get puzzle => widget.puzzle;
  
  /// The current game state containing puzzle and metadata.
  GameState? get gameState => widget.gameState;
  
  /// Whether the puzzle is currently being interacted with.
  bool get isInteracting => _isInteracting;
  bool _isInteracting = false;
  
  /// The currently selected cell position.
  Offset? get selectedPosition => _selectedPosition;
  Offset? _selectedPosition;
  
  /// The current focus position for keyboard navigation.
  Offset? get focusPosition => _focusPosition;
  Offset? _focusPosition;
  
  /// Error positions to highlight.
  Set<Offset> get errorPositions => Set.unmodifiable(_errorPositions);
  final Set<Offset> _errorPositions = {};
  
  /// Animation controller for smooth transitions.
  late AnimationController _animationController;
  
  /// Animation for selection highlights.
  late Animation<double> _selectionAnimation;
  
  /// Animation for error feedback.
  late Animation<double> _errorAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _selectionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _errorAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Handle tap events on the puzzle grid.
  void onTap(Offset position) {
    final gridPosition = _hitTest(position);
    if (gridPosition != null) {
      setState(() {
        _selectedPosition = gridPosition;
        _focusPosition = gridPosition;
        _isInteracting = true;
      });
      _animationController.forward();
      
      // Notify parent of selection
      widget.onCellSelected?.call(gridPosition);
    }
  }

  /// Handle drag events for multi-cell selection.
  void onPanStart(DragStartDetails details) {
    final gridPosition = _hitTest(details.localPosition);
    if (gridPosition != null) {
      setState(() {
        _selectedPosition = gridPosition;
        _isInteracting = true;
      });
      _animationController.forward();
    }
  }

  void onPanUpdate(DragUpdateDetails details) {
    final gridPosition = _hitTest(details.localPosition);
    if (gridPosition != null && gridPosition != _selectedPosition) {
      setState(() {
        _selectedPosition = gridPosition;
      });
    }
  }

  void onPanEnd(DragEndDetails details) {
    setState(() {
      _isInteracting = false;
    });
    _animationController.reverse();
  }

  /// Handle keyboard navigation.
  void onKeyEvent(KeyEvent event) {
    if (_focusPosition == null) return;
    
    Offset? newPosition;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      newPosition = _moveFocus(_focusPosition!, const Offset(0, -1));
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      newPosition = _moveFocus(_focusPosition!, const Offset(0, 1));
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      newPosition = _moveFocus(_focusPosition!, const Offset(-1, 0));
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      newPosition = _moveFocus(_focusPosition!, const Offset(1, 0));
    } else {
      return;
    }
    
    if (newPosition != null) {
      setState(() {
        _focusPosition = newPosition;
        _selectedPosition = newPosition;
      });
    }
  }

  /// Move focus in the specified direction.
  Offset? _moveFocus(Offset current, Offset direction) {
    // This should be implemented by subclasses based on their grid structure
    return null;
  }

  /// Perform hit testing to convert screen coordinates to grid coordinates.
  Offset? _hitTest(Offset position) {
    // This should be implemented by subclasses
    return null;
  }

  /// Clear the current selection.
  void clearSelection() {
    setState(() {
      _selectedPosition = null;
      _focusPosition = null;
      _isInteracting = false;
    });
    _animationController.reverse();
  }

  /// Set error positions to highlight.
  void setErrorPositions(Set<Offset> positions) {
    setState(() {
      _errorPositions.clear();
      _errorPositions.addAll(positions);
    });
    _animationController.forward();
  }

  /// Clear all error positions.
  void clearErrors() {
    setState(() {
      _errorPositions.clear();
    });
  }

  /// Get the current selection animation value.
  double get selectionAnimationValue => _selectionAnimation.value;
  
  /// Get the current error animation value.
  double get errorAnimationValue => _errorAnimation.value;

  /// Build the puzzle content - to be implemented by subclasses.
  Widget buildPuzzleContent(BuildContext context, Size size);
  
  /// Build the grid background - to be implemented by subclasses.
  Widget buildGridBackground(BuildContext context, Size size);
  
  /// Build cell content at the given position - to be implemented by subclasses.
  Widget buildCellContent(BuildContext context, Offset position, Size cellSize);
  
  /// Build selection highlight - to be implemented by subclasses.
  Widget buildSelectionHighlight(BuildContext context, Offset position, Size cellSize);
  
  /// Build error highlight - to be implemented by subclasses.
  Widget buildErrorHighlight(BuildContext context, Offset position, Size cellSize);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        
        return GestureDetector(
          onTapDown: (details) => onTap(details.localPosition),
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              onKeyEvent(event);
              return KeyEventResult.handled;
            },
            child: Stack(
              children: [
                // Grid background
                buildGridBackground(context, size),
                
                // Puzzle content
                buildPuzzleContent(context, size),
                
                // Selection highlights
                if (_selectedPosition != null)
                  buildSelectionHighlight(context, _selectedPosition!, _getCellSize(size)),
                
                // Error highlights
                for (final position in _errorPositions)
                  buildErrorHighlight(context, position, _getCellSize(size)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Get the size of individual cells - to be implemented by subclasses.
  Size _getCellSize(Size totalSize) {
    // This should be implemented by subclasses
    return Size.zero;
  }
}

/// Base widget for puzzle renderers.
abstract class PuzzleRendererWidget extends StatefulWidget {
  const PuzzleRendererWidget({
    super.key,
    required this.puzzle,
    this.gameState,
    this.onCellSelected,
    this.onMove,
    this.onError,
  });

  final GeneratedPuzzle? puzzle;
  final GameState? gameState;
  final ValueChanged<Offset>? onCellSelected;
  final ValueChanged<dynamic>? onMove;
  final ValueChanged<String>? onError;
}
