import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/models.dart';
import '../../shared/services/puzzle_registry.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/theme/app_theme.dart';

import '../../shared/services/kakuro_on_demand_service.dart';

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
    if (puzzleType == PuzzleType.kakuroClassic) {
      () async {
        bool dialogOpen = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _KakuroLoadingDialog(),
        ).then((_) => dialogOpen = false);
        try {
          final service = ref.read(kakuroOnDemandProvider);
          final metadata = _registry.getMetadata(PuzzleType.kakuroClassic);
          final sizeStr = metadata?.supportedSizes.isNotEmpty == true
              ? metadata!.supportedSizes.first
              : '9x9';
          final parts = sizeStr.split('x');
          final width = int.tryParse(parts.first) ?? 9;
          final height = int.tryParse(parts.length > 1 ? parts.last : '') ?? 9;
          final generated = await service.nextPuzzle(
            difficulty: difficulty,
            width: width,
            height: height,
          );
          if (dialogOpen && mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            dialogOpen = false;
          }
          if (!mounted) return;
          context.push('/play/${puzzleType.key}/random', extra: generated);
        } catch (_) {
          if (dialogOpen && mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            dialogOpen = false;
          }
          if (!mounted) return;
          _showLegacyModal(puzzleType, difficulty);
        }
      }();
      return;
    }

    // Non-Kakuro: keep existing modal generation UX
    _showLegacyModal(puzzleType, difficulty);
  }

  void _showLegacyModal(PuzzleType puzzleType, String difficulty) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PuzzleGenerationModal(
        puzzleType: puzzleType,
        difficulty: difficulty,
        onPuzzleGenerated: (puzzleInstance) {
          Navigator.of(context).pop();
          context.push('/play/${puzzleType.key}/random', extra: puzzleInstance);
        },
        onCancel: () {
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
        ...List.generate(
          4,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: const PuzzleCardShimmer(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return AppEmptyState(
      icon: Icons.extension_outlined,
      title: 'No Puzzles Available',
      message:
          'No puzzle engines are currently registered. Please check your configuration.',
      action: ElevatedButton.icon(
        onPressed: _loadPuzzles,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
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
            CategoryHeader(category: category, puzzleCount: puzzles.length),
            const SizedBox(height: 8),
            ...puzzles.map(
              (metadata) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Theme(
                  // Apply a light per-puzzle accent to the card area so colors match the puzzle
                  data: AppThemeData.forPuzzleType(
                    metadata.type,
                    Theme.of(context),
                  ),
                  child: PuzzleCard(
                    metadata: metadata,
                    onDailyChallenge: () =>
                        _navigateToPuzzle(metadata.type, PuzzleMode.daily),
                    onDifficultySelected: (difficulty) =>
                        _onDifficultySelected(metadata.type, difficulty),
                    onRandomPlay: _onRandomPlay,
                  ),
                ),
              ),
            ),
            if (index < _puzzlesByCategory.length - 1)
              const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _KakuroLoadingDialog extends StatelessWidget {
  const _KakuroLoadingDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            const SizedBox(height: 16),
            Text('Generating Kakuro…', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
