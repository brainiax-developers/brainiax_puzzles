import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/puzzle_generation_controller.dart';

/// Modal for generating puzzles with progress indication and cancel/retry functionality.
class PuzzleGenerationModal extends ConsumerStatefulWidget {
  const PuzzleGenerationModal({
    super.key,
    required this.puzzleType,
    required this.difficulty,
    required this.onPuzzleGenerated,
    required this.onCancel,
  });

  final PuzzleType puzzleType;
  final String difficulty;
  final Function(dynamic puzzleInstance) onPuzzleGenerated;
  final VoidCallback onCancel;

  @override
  ConsumerState<PuzzleGenerationModal> createState() => _PuzzleGenerationModalState();
}

class _PuzzleGenerationModalState extends ConsumerState<PuzzleGenerationModal>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  bool _isGenerating = true;
  bool _hasError = false;
  String? _errorMessage;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
    
    // Start puzzle generation after first frame to avoid provider mutation during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _generatePuzzle();
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _generatePuzzle() async {
    try {
      setState(() {
        _isGenerating = true;
        _hasError = false;
        _errorMessage = null;
      });

      // Use the real puzzle generation controller
      final controller = ref.read(puzzleGenerationControllerProvider.notifier);
      final puzzleInstance = await controller.generate(
        puzzleType: widget.puzzleType,
        difficulty: widget.difficulty,
      );

      if (mounted) {
        widget.onPuzzleGenerated(puzzleInstance);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _retryGeneration() {
    setState(() {
      _retryCount++;
    });
    Future.microtask(_generatePuzzle);
  }

  void _handleCancel() {
    _progressController.stop();
    _pulseController.stop();
    
    // Cancel the generation in the controller
    final controller = ref.read(puzzleGenerationControllerProvider.notifier);
    controller.cancelGeneration();
    
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return WillPopScope(
      onWillPop: () async {
        // Allow back navigation without blocking
        _handleCancel();
        return true;
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.extension,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generating ${widget.puzzleType.displayName}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Difficulty: ${widget.difficulty}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isGenerating)
                    IconButton(
                      onPressed: _handleCancel,
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                    ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Content based on state
              if (_isGenerating) _buildGeneratingContent(theme, colorScheme),
              if (_hasError) _buildErrorContent(theme, colorScheme),
              
              const SizedBox(height: 24),
              
                // Action buttons
                _buildActionButtons(theme, colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneratingContent(ThemeData theme, ColorScheme colorScheme) {
    return Column(
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
        
        // Progress indicator
        SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            backgroundColor: colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Status text
        Text(
          'Creating your puzzle...',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        
        if (_retryCount > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Retry attempt ${_retryCount + 1}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorContent(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: colorScheme.error.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.error_outline,
            size: 40,
            color: colorScheme.error,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Text(
          'Generation Failed',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          _errorMessage ?? 'An unexpected error occurred',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
        
        if (_retryCount >= _maxRetries) ...[
          const SizedBox(height: 8),
          Text(
            'Maximum retry attempts reached',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        // Cancel button
        Expanded(
          child: OutlinedButton(
            onPressed: _handleCancel,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Cancel'),
          ),
        ),
        
        if (_hasError) ...[
          const SizedBox(width: 12),
          // Retry button
          Expanded(
            child: ElevatedButton(
              onPressed: _retryCount < _maxRetries ? _retryGeneration : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: Text(_retryCount < _maxRetries ? 'Retry' : 'Max Retries'),
            ),
          ),
        ],
      ],
    );
  }
}
