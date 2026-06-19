import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/models.dart';
import '../../shared/providers/puzzle_local_store_providers.dart';
import '../../shared/services/puzzle_registry.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/puzzle_card.dart';
import '../../shared/widgets/shimmer_widget.dart';
import 'puzzle_detail_sheet.dart';
import 'puzzle_launch_actions.dart';

class SelectScreen extends ConsumerStatefulWidget {
  const SelectScreen({super.key});

  @override
  ConsumerState<SelectScreen> createState() => _SelectScreenState();
}

class _SelectScreenState extends ConsumerState<SelectScreen> {
  final PuzzleRegistry _registry = PuzzleRegistry();
  bool _isLoading = true;
  List<PuzzleMetadata> _metadata = const <PuzzleMetadata>[];
  PuzzleLibraryFilter _filter = PuzzleLibraryFilter.all;

  @override
  void initState() {
    super.initState();
    _loadPuzzles();
  }

  void _loadPuzzles() {
    _registry.initialize();
    setState(() {
      _metadata = _registry.getAllPuzzleMetadata()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<PuzzleType>> favouriteTypesAsync = ref.watch(
      favouritePuzzleTypesProvider,
    );
    final Set<PuzzleType> favouriteTypes = favouriteTypesAsync.asData?.value
            .toSet() ??
        const <PuzzleType>{};
    final List<PuzzleMetadata> filtered = _applyFilter(
      _metadata,
      favouriteTypes,
      _filter,
    );
    final bool showWordFilter = _metadata.any(
      (metadata) => metadata.category == PuzzleCategory.word,
    );

    if (_isLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          PuzzleCardShimmer(),
          SizedBox(height: 16),
          PuzzleCardShimmer(),
          SizedBox(height: 16),
          PuzzleCardShimmer(),
        ],
      );
    }

    if (_metadata.isEmpty) {
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Puzzle Library',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a puzzle type, then pick Daily Challenge or Random Play.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: 'All',
              selected: _filter == PuzzleLibraryFilter.all,
              onTap: () => setState(() => _filter = PuzzleLibraryFilter.all),
            ),
            _FilterChip(
              label: 'Numbers',
              selected: _filter == PuzzleLibraryFilter.numbers,
              onTap: () =>
                  setState(() => _filter = PuzzleLibraryFilter.numbers),
            ),
            _FilterChip(
              label: 'Visual',
              selected: _filter == PuzzleLibraryFilter.visual,
              onTap: () => setState(() => _filter = PuzzleLibraryFilter.visual),
            ),
            if (showWordFilter)
              _FilterChip(
                label: 'Word',
                selected: _filter == PuzzleLibraryFilter.word,
                onTap: () => setState(() => _filter = PuzzleLibraryFilter.word),
              ),
            _FilterChip(
              label: 'Favourites',
              selected: _filter == PuzzleLibraryFilter.favourites,
              onTap: () =>
                  setState(() => _filter = PuzzleLibraryFilter.favourites),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _filter == PuzzleLibraryFilter.favourites
                    ? 'Star a puzzle to build your favourites list.'
                    : 'No puzzles match this filter yet.',
              ),
            ),
          )
        else
          ...filtered.map(
            (metadata) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _PuzzleLibraryCardItem(metadata: metadata),
            ),
          ),
      ],
    );
  }
}

class _PuzzleLibraryCardItem extends ConsumerWidget {
  const _PuzzleLibraryCardItem({required this.metadata});

  final PuzzleMetadata metadata;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isFavourite = ref.watch(
          isFavouritePuzzleTypeProvider(metadata.type),
        ).asData?.value ??
        false;
    final ActivePuzzleRun? activeRun = ref.watch(
      activeRunForPuzzleTypeProvider(metadata.type),
    ).asData?.value;

    return PuzzleCard(
      metadata: metadata,
      isFavourite: isFavourite,
      isInProgress: activeRun != null,
      onTap: () => showPuzzleDetailSheet(context: context, metadata: metadata),
      onToggleFavourite: () => ref
          .read(favouritePuzzleControllerProvider)
          .toggle(metadata.type),
      onResume: activeRun == null
          ? null
          : () => resumePuzzleRun(
                context: context,
                ref: ref,
                puzzleType: metadata.type,
              ),
    );
  }
}

enum PuzzleLibraryFilter { all, numbers, visual, word, favourites }

List<PuzzleMetadata> _applyFilter(
  List<PuzzleMetadata> metadata,
  Set<PuzzleType> favouriteTypes,
  PuzzleLibraryFilter filter,
) {
  return metadata.where((item) {
    switch (filter) {
      case PuzzleLibraryFilter.all:
        return true;
      case PuzzleLibraryFilter.numbers:
        return _isNumbersPuzzle(item.type);
      case PuzzleLibraryFilter.visual:
        return _isVisualPuzzle(item.type);
      case PuzzleLibraryFilter.word:
        return item.category == PuzzleCategory.word;
      case PuzzleLibraryFilter.favourites:
        return favouriteTypes.contains(item.type);
    }
  }).toList();
}

bool _isNumbersPuzzle(PuzzleType type) {
  switch (type) {
    case PuzzleType.sudokuClassic:
    case PuzzleType.kakuroClassic:
    case PuzzleType.mathdokuClassic:
    case PuzzleType.takuzuBinary:
      return true;
    case PuzzleType.nonogramMono:
    case PuzzleType.slitherlinkLoop:
    case PuzzleType.killerQueens:
      return false;
  }
}

bool _isVisualPuzzle(PuzzleType type) {
  switch (type) {
    case PuzzleType.nonogramMono:
    case PuzzleType.slitherlinkLoop:
    case PuzzleType.killerQueens:
      return true;
    case PuzzleType.sudokuClassic:
    case PuzzleType.kakuroClassic:
    case PuzzleType.mathdokuClassic:
    case PuzzleType.takuzuBinary:
      return false;
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
