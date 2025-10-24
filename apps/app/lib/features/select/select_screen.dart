import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/models.dart';
import '../../shared/services/puzzle_registry.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/services/puzzle_preload_service.dart';

/// Screen for selecting a puzzle type and mode.
class SelectScreen extends ConsumerStatefulWidget {
  const SelectScreen({super.key});

  @override
  ConsumerState<SelectScreen> createState() => _SelectScreenState();
}

class _SelectScreenState extends ConsumerState<SelectScreen> {
  final PuzzleRegistry _registry = PuzzleRegistry();
  bool _isLoading = true;
  Map<PuzzleCategory, List<PuzzleMetadata>> _puzzlesByCategory = {};

  @override
  void initState() {
    super.initState();
    _loadPuzzles();
  }

  Future<void> _loadPuzzles() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate loading time for better UX
    await Future.delayed(const Duration(milliseconds: 800));

    // Initialize the registry (this will use the engines already registered in main.dart)
    _registry.initialize();
    final puzzlesByCategory = _registry.getPuzzlesByCategory();

    setState(() {
      _puzzlesByCategory = puzzlesByCategory;
      _isLoading = false;
    });
  }

  void _navigateToPuzzle(PuzzleType puzzleType, PuzzleMode mode) {
    context.push('/play/${puzzleType.key}/${mode.key}');
  }

  void _onDifficultySelected(PuzzleType puzzleType, String difficulty) {
    // Store the difficulty selection for this puzzle type
    // This will be used for persistence and default selection
  }

  void _onRandomPlay(PuzzleType puzzleType, String difficulty) {
    // First try to use preloaded puzzle if available
    try {
      final preload = ref.read(puzzlePreloadProvider);
      final cached = preload.getCached(puzzleType, difficulty);
      if (cached != null) {
        // Navigate immediately with the cached puzzle to avoid waiting for generation
        context.push('/play/${puzzleType.key}/random', extra: cached);
        return;
      }
    } catch (e) {
      // If preload service isn't available or something goes wrong, fall back to modal
    }

    // Fallback: show generation modal as before
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => PuzzleGenerationModal(
        puzzleType: puzzleType,
        difficulty: difficulty,
        onPuzzleGenerated: (puzzleInstance) {
          // Close the modal
          Navigator.of(context).pop();

          // Navigate to play screen with the generated puzzle
          // TODO: Pass the puzzle instance to the play screen
          context.push('/play/${puzzleType.key}/random', extra: puzzleInstance);
        },
        onCancel: () {
          // Close the modal
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Puzzle'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_puzzlesByCategory.isEmpty) {
      return _buildEmptyState();
    }

    return _buildPuzzleList();
  }

  Widget _buildLoadingState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Loading header
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 24,
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 16,
                width: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Loading puzzle cards
        ...List.generate(4, (index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: const PuzzleCardShimmer(),
        )),
      ],
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.extension_outlined,
              size: 64,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Puzzles Available',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No puzzle engines are currently registered. Please check your configuration.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPuzzles,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPuzzleList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _puzzlesByCategory.length,
      itemBuilder: (context, index) {
        final category = _puzzlesByCategory.keys.elementAt(index);
        final puzzles = _puzzlesByCategory[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryHeader(
              category: category,
              puzzleCount: puzzles.length,
            ),
            const SizedBox(height: 8),
            ...puzzles.map((metadata) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Theme(
                // Apply a light per-puzzle accent to the card area so colors match the puzzle
                data: AppThemeData.forPuzzleType(metadata.type, Theme.of(context)),
                child: PuzzleCard(
                  metadata: metadata,
                  onDailyChallenge: () => _navigateToPuzzle(
                    metadata.type,
                    PuzzleMode.daily,
                  ),
                  onDifficultySelected: (difficulty) => _onDifficultySelected(
                    metadata.type,
                    difficulty,
                  ),
                  onRandomPlay: _onRandomPlay,
                ),
              ),
            )),
            if (index < _puzzlesByCategory.length - 1) const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
